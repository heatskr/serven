path = require('path')
inflection = require('inflection')

class Router
  constructor: (config) ->
    @stack = []
    @_prev = '/'
    @_path = '/'
    @_namespace = ''

  @load: (callback) ->
    (config) ->
      router = new Router(config)
      callback.apply(router)
      router

  namespace: (pattern, cb) ->
    @_prev = @_path
    @_path = path.join(@_path, pattern)
    cb.apply(this)
    @_path = @_prev

  root:               (verb, opt) -> @exec('get',    '/',     verb, opt)
  get:       (pattern, verb, opt) -> @exec('get',    pattern, verb, opt)
  put:       (pattern, verb, opt) -> @exec('put',    pattern, verb, opt)
  post:      (pattern, verb, opt) -> @exec('post',   pattern, verb, opt)
  delete:    (pattern, verb, opt) -> @exec('delete', pattern, verb, opt)

  resources: (pattern, opt = {}) ->
    opt.model = inflection.classify(pattern)
    opt.controller ?= pattern
    opt.context ?= pattern
    pattern = inflection.dasherize(pattern)
    @get    "#{pattern}",          "#{pattern}#search" , opt
    @get    "#{pattern}/new",      "#{pattern}#new"    , opt
    @post   "#{pattern}",          "#{pattern}#create" , opt
    @get    "#{pattern}/:id",      "#{pattern}#read"   , opt
    @get    "#{pattern}/:id/edit", "#{pattern}#edit"   , opt
    @put    "#{pattern}/:id",      "#{pattern}#update" , opt
    @delete "#{pattern}/:id",      "#{pattern}#delete" , opt

  exec: (method, pattern, verb, opt = {}) ->
    index  = verb.indexOf('#')
    dir    = path.join(@_path, verb.substr(0, index))
    base   = path.basename(dir)
    rel    = path.dirname(dir)
    action = verb.substr(index + 1)
    model  = inflection.classify(dir)
    view   = inflection.dasherize(action)
    ctrl   = inflection.camelize(opt.controller || base)
    ns     = path.relative('/', rel)

    context = opt.context ? inflection.underscore(ctrl).split(/\//).join('_')
    context = [ns, context, action]
      .filter((v) => v).join(':').toLowerCase()

    route =
      id:         null
      method:     method
      pattern:    path.join(@_path, pattern)
      context:    context
      namespace:  ns
      verb:       verb
      model:      opt.model
      views:      path.relative('/', dir)
      view:       view
      controller: path.join(ns, ctrl)
      action:     action

    @stack.push(route)
    route.id = @stack.length
    Object.freeze(route)

module.exports = Router
