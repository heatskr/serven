CoffeeScript = require('coffeescript')
stylus = require('stylus')
pug = require('pug')

fs = require('fs')
url = require('url')
path = require('path')
uglify = require("uglify-js")

imports = new Map()

compare = (pathA, pathB) ->
  pathA = pathA.split(path.sep)
  pathB = pathB.split('/')
  if !pathA[pathA.length - 1]
    pathA.pop()
  if !pathB[0]
    pathB.shift()
  overlap = []
  while pathA[pathA.length - 1] == pathB[0]
    overlap.push pathA.pop()
    pathB.shift()
  overlap.join '/'

mkdir = (dirname) ->
  new Promise (resolve, reject) ->
    fs.mkdir dirname, {mode: 0o700, recursive: true}, (error) ->
      return reject(error) if error
      resolve()

writeFile = (filename, buffer) ->
  new Promise (resolve, reject) ->
    fs.writeFile filename, buffer, (error) ->
      return reject(error) if error
      resolve()

readFile = (filename) ->
  new Promise (resolve, reject) ->
    fs.readFile filename, (error, buffer) ->
      return reject(error) if error
      resolve(buffer)

stat = (filename) ->
  new Promise (resolve, reject) ->
    fs.stat filename, (error, stats) ->
      return reject(error) if error
      resolve(stats)

debug = console.log

class AssetMiddleware
  constructor: (@options) ->
  compile: (buffer, filename) -> throw new Error()
  filter: (url) -> throw new Error()
  getMimetype: ->
    throw new Error() getDirectory: -> throw new Error()

module.exports = (options) ->
  stack = [
    new AssetMiddlewarePug(options)
    new AssetMiddlewareCoffee(options)
    new AssetMiddlewareStylus(options)
  ]

  force = options.force
  src = options.src
  dest = options.dest

  (req, res, next) ->
    return next() unless req.method in ['GET', 'HEAD']

    pathname = url.parse(req.url).pathname

    middleware = null
    for entry in stack
      if entry.filter(pathname)
        middleware = entry
        break
    return next() unless middleware

    # check for dest-path overlap
    overlap = compare(dest, pathname).length
    if '/' == pathname.charAt(0)
      overlap++

    pathname = pathname.slice(overlap)
    dstPath = path.join(dest, pathname)
    ext = path.extname(pathname)
    pathname = pathname.replace(ext, middleware.getExtenion())
    srcPath = path.join(src, middleware.getDirectory(), pathname)

    compile = ->
      try
        debug('read %s', dstPath)
        buffer = await readFile(srcPath)
        results = await middleware.compile buffer,
          input: srcPath
          output: dstPath
          src: src
          dest: dest
        debug('render %s', srcPath)
        await mkdir(path.dirname(dstPath))
        await writeFile(dstPath, results.output)
        if results.map
          mapPath = dstPath + '.map'
          debug('map %s', mapPath)
          await writeFile(mapPath, results.map)
        next()
      catch err
        next(err)

    try
      srcStats = await stat(srcPath)
    catch error
      return next(if 'ENOENT' == error.code then null else error)

    try
      dstStats = await stat(dstPath)
      if srcStats.mtime > dstStats.mtime
        debug('modified %s', dstPath)
        return compile()
    catch err
      if 'ENOENT' == err.code
        debug('not found %s', dstPath)
        return compile()
      return next(err)

    # return compile() if force || !imports.get(srcPath)
    # debug('static %s', req.url)
    return next()


class AssetMiddlewarePug extends AssetMiddleware
  constructor: (options) ->
    super(options)

    options.pug ?= {}

    @opt = options.pug

    #The name of the file being compiled.
    # Used in exceptions, and required for relative include\s and extend\s.
    @opt.filename ?= 'Pug' # string

    #The root directory of all absolute inclusion.
    @opt.basedir ?= undefined # string

    # If the doctype is not specified as part of the template,
    # you can specify it here. It is sometimes useful to get
    # self-closing tags and remove mirroring of boolean attributes.
    # See doctype documentation for more information.
    @opt.doctype ?= undefined # string

    # Hash table of custom filters.
    @opt.filters ?= undefined # object

    # Use a self namespace to hold the locals. It will speed up the
    # compilation, but instead of writing variable you will  have to
    # write self.variable to access a property of the  locals object.
    @opt.self ?= false # boolean

    # If set to true, the tokens and function body are logged to stdout.
    @opt.debug ?= undefined # boolean

    # If set to true, the function source will be included in the
    # compiled template for better error messages (sometimes useful
    # in development). It is enabled by default, unless used with
    # Express in production mode.
    @opt.compileDebug ?= undefined # boolean

    # Add a list of global names to make accessible in templates.
    @opt.globals ?= undefined # Array<string>

    # If set to true, compiled functions are cached. filename must
    # be set as the cache key. Only applies to render functions.
    @opt.cache ?= false # boolean

    # Inline runtime functions instead of require-ing them from a
    # shared version. For compileClient functions, the default is
    # true (so that one does not have to include the runtime).
    # For all other compilation or rendering types, the default is false.
    @opt.inlineRuntimeFunctions ?= true # boolean

    # The name of the template function.
    # Only applies to compileClient functions.
    @opt.name ?= 'template' # string

  compile: (buffer, asset) ->
    new Promise (resolve, reject) ->
      js = pug.compileClient buffer.toString('UTF-8'),
        inlineRuntimeFunctions: true
        debug: false
        compileDebug: false
        name: 'template'
      # if @opt.minify
      min = uglify.minify(js)
      return reject(min.error) if min.error
      js = min.code
      resolve(output: js, map: null)

  filter: (url) -> /\.pug\.js$/.test(url)
  getExtenion: -> ''
  getMimetype: -> 'text/javascript; charset=UTF-8'
  getDirectory: -> 'templates'

class AssetMiddlewareCoffee extends AssetMiddleware
  constructor: (options) ->
    super(options)

    options.coffee ?= {}
    @opt = options.coffee

    # if true, a source map will be generated; and instead of
    # returning a string, compile will return an object of the
    # form {js, v3SourceMap, sourceMap}.
    @opt.sourceMap ?= true

    # if true, output the source map as a base64-encoded
    # string in a comment at the bottom.
    @opt.inlineMap ?= false

    # the filename to use for the source map. It can
    # include a path (relative or absolute).
    # options.compile.filename ?= ''

    # if true, output without the top-level function safety wrapper.
    @opt.bare ?= false

    # if true, output the Generated by CoffeeScript header.
    @opt.header ?= false

    # if set, this must be an object with the options to pass to Babel.
    # See Transpilation.
    @opt.transpile ?= false

    # if true, return an abstract syntax tree of
    # the input CoffeeScript source code.
    @opt.ast ?= false

  compile: (buffer, asset) ->
    generatedFile = path.join(
      path.relative(path.dirname(asset.output), asset.dest),
      path.basename(asset.output)
    )

    filename = path.join(
      path.relative(
        path.dirname(asset.input),
        path.join(asset.src, @getDirectory())
      ),
      path.basename(asset.input)
    )

    new Promise (resolve, reject) =>
      try
        coffee = buffer.toString('UTF-8')

        results = CoffeeScript.compile coffee,
          sourceMap: @opt.sourceMap
          inlineMap: @opt.inlineMap
          bare:      @opt.bare
          header:    @opt.header
          filename: filename
          sourceRoot: '/'
          generatedFile: generatedFile,

        results = js: results if 'string' == typeof results
        js = results.js
        map = results.sourceMap

        ###
        @todo
        ###
        if @opt.minify
          min = uglify.minify(results.js)
          return reject(min.error) if min.error
          js = min.code

        if map
          map = results.v3SourceMap
          comment = "\n//\# sourceMappingURL=application.js.map"
          js += comment

        resolve(output: js, map: map)
      catch error
        reject(error)

  filter: (url) -> /\.js$/.test(url)
  getExtenion: -> '.coffee'
  getMimetype: -> 'text/javascript; charset=UTF-8'
  getDirectory: -> 'scripts'

class AssetMiddlewareStylus extends AssetMiddleware
  constructor: (options) ->
    super(options)
    options.stylus ?= {}
    opt = options.stylus
    opt.compress ?= true
    opt.firebug  ?= false
    opt.linenos  ?= false
    opt.sourcemap ?=
      comment: true
      inline: false
      sourceRoot: '/'
      basePath: path.relative('.', path.join(options.src, @getDirectory()))

  compile: (buffer, asset) ->
    new Promise (resolve, reject) =>
      buffer = buffer.toString('UTF-8')
      style = stylus(buffer)
        .set('filename',  asset.input)
        .set('compress',  @options.stylus.compress)
        .set('firebug',   @options.stylus.firebug)
        .set('linenos',   @options.stylus.linenos)
        .set('sourcemap', @options.stylus.sourcemap)
        style.render (error, css) ->
          return reject(error) if error
          style.sourcemap.sourcesContent = [buffer]
          resolve(output: css, map: JSON.stringify(style.sourcemap))

  filter: (url) -> /\.css$/.test(url)
  getExtenion: -> '.styl'
  getMimetype: -> 'text/css; charset=UTF-8'
  getDirectory: -> 'stylesheets'
