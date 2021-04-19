path = require('path')
ACL = require('./ACL')
Annotations = require('./Annotations')
{ NotFoundError } = require('./Exception')

module.exports = class Controller
  @view = (namespace) ->
    Annotations.assert(this).view = namespace

  @before_action = (callback, options = {}) ->
    a = Annotations.assert(this)
    a.before_action ?= []
    a = a.before_action
    only = options.only ? []
    if typeof only == 'string'
      only = [only]
    a.push([callback, only])

  init: null

  quit: null

  saveSession: ->
    new Promise (y, n) =>
      @_session.save (e, r) -> e && n(e) || y(r)

  render: (view, options) ->
    @_sent = true
    if typeof view == 'object'
      options = view
      view = null
    @_render = view
    if options
      for k,v of options
        this['_' + k] = v
    return

  dispatch: (req, res, next) ->
    action = @_action
    render = @_render
    @_render = null
    if @_before_action
      for g in @_before_action
        for [k,v] in g
          if v.length == 0 || v.includes(action)
            @_action = k
            await @_dispatch(req, res, next)
            break if @_sent
        break if @_sent
    if !@_sent
      @_render = render
      @_action = action
      @_dispatch(req, res, next)

  _dispatch: (req, res, next) ->
    try
      await @init.apply(this) if @init
      res.on 'close', => @quit() if @quit
    catch error
      if error instanceof NotFoundError
        res.status(404).end()
      else
        next(error)
      return
    if this[@_action]
      try
        await this[@_action].apply(this)

        if @_message
          req.app.logs.watchdog.write([
            @_log || 1 # logType
            Date.now() # createdAt
            @_session.user && @_session.user.id || 0 # who
            @_ip # ip
            @_message # message
            @_method + ' ' + @_path # context
          ].join(';;;') + '\n')

      catch error
        return next(error)
      res.set(k, v) for k,v of @_set
      return res.status(@_head).end() if @_head
      res.status(@_status) if @_status
      @_session['_message'] = @_message if @_message
      res.location(@_location) if @_location
      if @_redirect
        await @saveSession()
        res.redirect(@_status || 303, @_redirect)
        return
    res.set('Content-Type', @_type) if @_type
    return res.download(@_file) if @_file
    return res.json(@_json) if @_json
    return res.end(@_text) if @_text
    if @_render
      @_message = @_session['_message']
      @_session['_message'] = null
      res.render ((@_views && (@_views + '/') || '') + @_render), this
