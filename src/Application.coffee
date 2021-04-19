Express = require('express')
Config = require('./Config')
Model  = require('./Model')
Router = require('./Router')
Annotations = require('./Annotations')
Controller = require('./Controller')
ACL = require('./ACL')
os = require('os')

fs = require('fs')
fsp = require('fs/promises')

Mixin = (base, ...mixins) ->
  types = []
  base ?= Object
  i = mixins.length - 1
  while i > -1
    # base.__mixin__ = base
    base = mixins[i](base)
    types.push(base)
    i -= 1
  # base.__mixin__ = mixins
  base

notFound = (req, res, next) ->
  res.status(404)
  res.render('404', { req, res })

serverError = (error, req, res, next) ->
  res.status(500)
  if req.api
    return res.json(error: error.stack.split('\n'))
  res.render('500', { error, req, res } )

message = (msg) ->
  @request.session['_message'] = msg

register = (route) ->
  models = @locals.models
  model = route.model && models[route.model] || null
  base = @config.import('controllers', route.controller)

  if (a = Annotations.get(base))
    view = b if (b = a.view) != null

  ba = []
  c  = base
  while c.prototype instanceof Controller && c != Controller
    if (a = Annotations.get(c)) && a.before_action
      ba.push(a.before_action)
    c = c.__proto__
  ba = ba.sort(-> -1)

  { Log } = models

  # !!! closure
  controller = class extends Mixin(base, @helper)

    constructor: (req, res, next) ->
      super()

      @_method   = req.method
      @_path     = req.path
      @_headers  = req.headers
      @_query    = req.query
      @_body     = req.body
      @_files    = req.files
      @_cookie   = req.cookie
      @_params   = req.params
      @_session  = req.session

      @_ip = req.ip

      @_api = req.api

      @route = route
      @models = models
      @model = model

      @_views = view || route.views
      @_action = route.action
      @_render = route.view

      @_before_action = ba

  h = (req, res, next) =>
    req.api = /^application\/json/.test(req.get('Content-Type'))

    if req.session.user
      roles = req.session.user.roles
      allowed = @acl.can(roles, route.context)
    else
      allowed = @acl.can('guest', route.context)

    if !allowed
      if req.session.user
        req.app.logs.watchdog.write([
          LogType = 3
          createdAt = Date.now()
          who = req.session.user.id
          ip = req.ip
          message = "Forbidden"
          context = req.method + ' ' + req.path
        ].join(';;;') + '\n')

        res.status(403)
        res.api && res.json({}) || res.render('403',{req, res})
      else
        req.app.logs.watchdog.write([
          LogType = 3
          createdAt = Date.now()
          who = 0
          ip = req.ip
          message = "Unauthorized"
          context = req.method + ' ' + req.path
        ].join(';;;') + '\n')

        res.api && res.status(401).json({}) || res.redirect('/sign-in')
      return

    new controller(req,res,next).dispatch(req, res, next)

  f = null
  name = route.context.replace(/\W/g, '$')
  eval "f=function #{name}(r,s,t){h(r,s,t)}"
  f

class Application extends Express
  constructor: (bundle) ->
    super()

    @config = new Config(bundle)

    now = Date.now()

    @logs = {}
    @logs.access   = fs.createWriteStream(@config.join('logs', "access.log"),   { mode: 0o600, flags: 'a+' })
    @logs.error    = fs.createWriteStream(@config.join('logs', "error.log"),    { mode: 0o600, flags: 'a+' })
    @logs.profile  = fs.createWriteStream(@config.join('logs', "profile.log"),  { mode: 0o600, flags: 'a+' })
    @logs.watchdog = fs.createWriteStream(@config.join('logs', "watchdog.log"), { mode: 0o600, flags: 'a+' })

    @sequelize = Model.load(@config)

    @sequelize.options.logging = (msg, params) =>
      @logs.profile.write(msg + '\n')

    @config.import('config', 'middleware')(this)

    router = @config.require('routes')
    @acl = @config.require('acl')

    builtIn = require('./Helper')
    helpers = @config.importAll('helpers').sort -> -1
    locals = Object.assign(@locals, builtIn, ...helpers)
    @helper = (base) ->
      helper = class extends base
      for k,v of locals
        helper.prototype[k] = v
      helper

    @locals.models = @sequelize.models
    @locals.basedir = 'app/views'
    @locals.os =
      platform: os.platform()
      version: os.version()
      release: os.release()

    @use (req, res, next) ->
      if req.files
        re = /(\w+)\[(\w+)\]/
        req.files.forEach (file) ->
          if re.test file.fieldname
            matches = file.fieldname.match(re)
            o = matches[1]
            k = matches[2]
            req.body[o] ?= {}
            req.body[o][k] = file

          res.on 'close', ->
            fsp.rm(file.path).catch(->)
      next()

    for route in router.stack
      { method, pattern, context } = route
      handler = register.apply(this, [route])
      this[method] pattern, handler
      @acl.addPermission(context)

    @acl.save()

    @use notFound
    @use serverError

module.exports = Application
