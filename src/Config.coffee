fs = require('fs')
fsp = require('fs/promises')
path = require('path')
dotenv = require('dotenv')

VERSION = "1.0.2"

class Config
  DIRECTORIES =
    app:         'app'
    models:      'app/models'
    views:       'app/views'
    layouts:     'app/views/layouts'
    controllers: 'app/controllers'
    helpers:     'app/helpers'
    assets:      'app/assets'
    images:      'app/assets/images'
    stylesheets: 'app/assets/stylesheets'
    scripts:     'app/assets/scripts'
    templates:   'app/assets/templates'
    config:      'config'
    data:        'data'
    migrations:  'data/migrate.d'
    seeds:       'data/seed.d'
    storage:     'data/storage'
    public:      'public'
    test:        'test'
    tmp:         'tmp'
    uploads:     'tmp/uploads'
    sessions:    'tmp/sessions'
    logs:        'tmp/logs'

  FILES =
    routes:      ['config/routes.coffee']
    database:    ['config/database.coffee']
    stylesheet:  ['app/assets/stylesheets/application.styl']
    script:      ['app/assets/scripts/application.coffee']
    controller:  ['app/controllers/Main.coffee']
    helpers:     ['app/helpers/Main.coffee']
    layout:      ['app/views/layout.pug']

  _imports = new Map()

  constructor: (root) ->
    @version = VERSION
    @env = process.env.NODE_ENV || 'development'
    @root = path.resolve(root)
    for k,v of DIRECTORIES
      Object.defineProperty this, k,
        value: path.join(@root, v)
        enumerable: true
    try
      dotenv.config(path: path.join(@root, '.env'))
    catch error
      console.error(error)

  files: (directory = '') ->
    FILES[this[directory]]

  require: (...file) ->
    filename = path.resolve(@join('config', ...file))
    loader = require(filename)
    if _imports.has(filename)
      return _imports.get(filename)
    cache = loader(this)
    _imports.set(filename, cache)
    cache

  import: (directory, ...file) ->
    require @join(directory, ...file)

  importAll: (directory) ->
    @readdir(directory).map (file) =>
      @import(directory, file)

  join: (directory, ...file) ->
    path.join this[directory], ...file

  readdir: (directory) ->
    dir = this[directory]
    [ ...getFiles(dir) ].map (file) ->
      path.relative(dir, file)

  getFiles = (dir) ->
    dirents = fs.readdirSync(dir, withFileTypes: true)
    for dirent in dirents
      res = path.join(dir, dirent.name)
      if dirent.isDirectory()
        files = [ ...getFiles(res) ]
        for file in files
          yield file
      else
        yield res

  getDirectories = (dir) ->
    dirents = fs.readdirSync(dir, withFileTypes: true)
    for dirent in dirents
      res = path.join(dir, dirent.name)
      if dirent.isDirectory()
        files = [ ...getDirectories(res) ]
        for file in files
          yield file
        yield res
    return

  relative: (directory, file) ->
    path.relative(path.dirname(file), this[directory])

  parse: (filename) ->
    path.parse(filename)

  mkdir: (directory, ...pathname) ->
    dirname = @join(directory, ...pathname)
    relative = path.relative(@root, dirname)
    if /^\.\./.test(relative)
      throw new Error("Invalid path \"#{relative}\"")
    fsp.mkdir(dirname, recursive: true).catch(->)

  rmdir: (directory, namespace) ->
    basedir = namespace
    while basedir != '.'
      await @_rmdirp(directory, basedir)
      basedir = path.dirname(basedir)
    return

  _rmdirp: (directory, namespace) ->
    dirname = @join(directory, namespace)
    if @relative(directory, dirname) != ''
      return

    dirs = [ ...getDirectories(dirname) ]
    for dir in dirs
      await fsp.rmdir(dir).catch(->)

    await fsp.rmdir(dirname).catch(->)

  writeFile: (directory, basename, chunk, force = false) ->
    filename = @join('root', directory, basename)
    dirname = path.dirname(filename)
    relative = path.relative(@root, filename)
    if /^\.\./.test(relative)
      throw new Error("Invalid path \"#{relative}\"")
    if !force && fs.existsSync(filename)
      throw new Error("Overwriting existing file \"#{relative}\"")
    fs.mkdirSync(dirname, recursive: true)
    fs.writeFileSync(filename, chunk, 'UTF-8')

module.exports = Config
