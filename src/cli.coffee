#!/usr/bin/env coffee

Config = require('./Config')
Model = require('./Model')

path = require('path')
fs = require('fs')
inflection = require('inflection')
getopt = require('node-getopt')

parseOptions = (opts) ->
  opt = getopt
  .create(opts)  # create Getopt instance
  .parseSystem() # parse command line

config = new Config(process.cwd())

commands = {}

main = ->
  args = process.argv.slice(2)
  switch args[0]
    when 'c', 'console'
      commands['console']()
    when 's', 'server'
      commands['server']()
    when 'new'
      commands['new']()
    when 'db', 'database'
      switch args[1]
        when 'status'
          commands['db:status']()
        when 'create'
          commands['db:create']()
        when 'drop'
          commands['db:drop']()
        when 'reset'
          commands['db:reset']()
        when 'migrate'
          commands['db:migrate'](args.slice(2))
        when 'rollback'
          commands['db:rollback'](args.slice(2))
        when 'dump'
          commands['db:dump']()
        when 'restore'
          commands['db:restore']()
        when 'seed'
          commands['db:seed']()
        when 'console', 'c', ''
          commands['db']()
        else
          console.log('help:db')
    when 'g', 'generate'
      switch args[1]
        when 'migration'
          commands['generate:migration']()
        when 'seed'
          commands['generate:seed']()
        when 'model'
          commands['generate:model']()
        when 'view'
          commands['generate:view']()
        when 'controller'
          commands['generate:controller']()
        when 'helper'
          commands['generate:helper']()
        when 'script'
          commands['generate:script']()
        when 'stylesheet'
          commands['generate:stylesheet']()
        when 'scaffold'
          commands['generate:scaffold']()
        else
          console.log('help:generate')
    when 'd', 'destroy'
      switch args[1]
        when 'migration'
          commands['destroy:migration']()
        when 'seed'
          commands['destroy:seed']()
        when 'model'
          commands['destroy:model']()
        when 'view'
          commands['destroy:view']()
        when 'controller'
          commands['destroy:controller']()
        when 'helper'
          commands['destroy:helper']()
        when 'script'
          commands['destroy:script']()
        when 'stylesheet'
          commands['destroy:stylesheet']()
        when 'scaffold'
          commands['destroy:scaffold']()
        else
          console.log('help:destroy')
    else
      commands['help']()
  return

commands['help'] = ->
  args = parseOptions([
    ['h' , 'help',    'display this help'],
    ['v' , 'version', 'show version']
  ])
  args.setHelp """
  Serven Framework (1.0.0)

  Usage:
    serven COMMAND [OPTION]...

  Commands:
    help, h

    new

    generate, g | destroy, d
      model
      view
      controller
      script
      stylesheet
      scaffold
      migration

    database, db
      console
      status
      migrate
      rollback
      create
      clear
      reset
      dump
      restore

    console, c

    server, s

  General options:
  [[OPTIONS]]

  """
  if args.options.version
    console.log('1.0.0')
    return

  switch args.argv[1]
    when 'generate', 'g'
      console.log """
      Generates files into project

      Default generators:
             model NAME [COLUMN]... [--timestamps]
              view NAME
        controller NAME [ACTIONS...]
            script NAME
        stylesheet NAME
          scaffold NAME [COLUMN]... [--timestamps]
         migration NAME [COLUMN]...

      """
    when 'database', 'db'
      console.log """
      Database management

         console Database client console
          status Shows current migration status
         migrate Executes pending migrations
        rollback Rollbacks migrations to previous states
            seed Populates database with presets
          create Creates database schema
           clear Cleans database schema
           reset Will clear, migrate and populate database

      """
    when 'console', 'c'
      console.log """
      Opens iteractive CoffeeScript console with application runtime

      """
    when 'server', 's'
      console.log """
      Launches application server listening to given port and host

      """
    else
      args.showHelp()

  return

commands['new'] = ->
  args = parseOptions([
    [ 'f', 'force', '' ]
    [ 'd', 'database=ARG', 'sqlite|postgres|mariadb|mysql|mssql' ]
  ])
  argv = args.argv.slice(1)
  options = args.options

  options.database ?= 'sqlite'
  dialects = [ 'sqlite', 'postgres', 'mariadb', 'mysql', 'mssql' ]

  if !dialects.includes(options.database)
    console.log('Database must be one of: sqlite|postgres|mariadb|mysql|mssql')
    process.exit(1)

  packages = {}
  switch options.database
    when 'sqlite'
      packages['sqlite3'] = '^5.0.2'
    when 'postgres'
      packages['pg'] = '^8.6.0'
      packages['pg-hstore'] = '^2.3.3'
    when 'mariadb'
      packages['mariadb'] = '^2.5.3'
    when 'mysql'
      packages['mysql2'] = "^2.2.5"
    when 'mssql'
      packages['tedious'] = '^0.0.0'

  name = argv[0]
  if !name
    return console.log('help:new')

  root = path.resolve(name)
  name = path.parse(root).name

  if !options.force && fs.existsSync(root)
    console.log("Directory %s is not empty", root)
    process.exit(1)

  # !!!
  version = "file:" + path.join(__dirname, '..')

  c = new Config(root)

  await c.mkdir('images')
  await c.mkdir('scripts')
  await c.mkdir('stylesheets')
  await c.mkdir('templates')
  await c.mkdir('models')
  await c.mkdir('views')
  await c.mkdir('controllers')
  await c.mkdir('helpers')
  await c.mkdir('config')
  await c.mkdir('public')
  await c.mkdir('test')
  await c.mkdir('logs')
  await c.mkdir('uploads')
  await c.mkdir('sessions')
  await c.mkdir('migrations')
  await c.mkdir('storage')
  await c.mkdir('seeds')

  # dotenv
  buffer = """
    SECRET=secret
    SESSION_SECRET=session_secret

    DATABASE_URL=sqlite://./data/database.sqlite3

    PRIVATE_KEY=
    CERTIFICATE=

    MAIL_HOST=
    MAIL_PORT=
    MAIL_USER=
    MAIL_PASS=

  """
  await c.writeFile('', '.env', buffer, true)

  # sequelize
  buffer = """
    Sequelize = require('sequelize')

    module.exports = (config) ->
      new Sequelize process.env.DATABASE_URL,
        sync:
          force: false
        define:
          underscored: true
          underscoreAll: true
          timestamps: false
        omitNull: false
        typeValidation: true
        logging: false

  """
  await c.writeFile('config', 'sequelize.coffee', buffer, true)

  # middleware
  buffer = """
    morgan         = require('morgan')
    methodOverride = require('method-override')
    multer         = require('multer')
    express        = require('express')

    module.exports = (app) ->
      app
      .set 'view engine', 'pug'
      .set 'views', 'app/views'
      .use methodOverride('_method')
      .use app.config.require('assets')
      .use '/', express.static(app.config.public)
      .use morgan('common', stream: app.logs.access)
      .use express.json()
      .use express.urlencoded(extended: true)
      .use multer(dest: app.config.uploads).any()
      .use app.config.require('session')

  """
  await c.writeFile('config', 'middleware.coffee', buffer, true)

  # routes
  buffer = """
    { Router } = require('serven')

    module.exports = Router.load ->
      @root 'main#home'

  """
  await c.writeFile('config', 'routes.coffee', buffer, true)

  # assets
  buffer = """
    { Asset } = require('serven')

    module.exports = (config) ->
      Asset
        force: false
        serve: false
        src: config.assets
        dest: config.public

  """
  await c.writeFile('config', 'assets.coffee', buffer, true)

  # acl
  buffer = """
    { ACL } = require('serven')

    module.exports = (config) ->
      new ACL
        cache: []
        roles: ['admin', 'staff', 'member', 'guest']
        permissions: []
        rules: rules

    rules = ->
      @allow('*', '*')

  """
  await c.writeFile('config', 'acl.coffee', buffer, true)

  # session
  buffer = """
    ExpressSession = require('express-session')
    FileStore = require('session-file-store')(ExpressSession)

    module.exports = (config) ->
      ExpressSession
        name: 'serven.sid'
        store: new FileStore(path: config.sessions)
        secret: process.env.SESSION_SECRET
        resave: true
        saveUninitialized: false
        proxy: true
        cookie:
          httpOnly: true
          maxAge: 365 * 24 * 60 * 60 * 1000
          sameSite: true
          secure: false

  """
  await c.writeFile('config', 'session.coffee', buffer, true)

  await c.writeFile('app/assets/scripts', 'application.coffee', "", true)
  await c.writeFile('app/assets/stylesheets', 'application.styl', "", true)

  buffer = """
    { Controller } = require('serven')

    class Main extends Controller

    module.exports = Main

  """
  await c.writeFile('app/controllers', 'Main.coffee', buffer, true)

  # home
  buffer = """
    extends /layout
    block content
      h3 Welcome to home page

  """
  await c.writeFile('app/views/main', 'home.pug', buffer, true)

  # server error
  buffer = """
    extends /layout
    block content
      h3 Error
      pre \#{error}

  """
  await c.writeFile('app/views', '500.pug', buffer, true)

  # forbidden
  buffer = """
    extends /layout
    block content
      h3 Forbidden

  """
  await c.writeFile('app/views', '403.pug', buffer, true)

  # page not found
  buffer = """
    extends /layout
    block content
      h3 Page not found

  """
  await c.writeFile('app/views', '404.pug', buffer, true)

  # layout
  buffer = """
    doctype
    html(lang="en")
      head
        meta(charset="UTF-8")
        title #{name}
        meta(name="viewport" content="width=device-width,initial-scale=1")
        link(rel="stylesheet" type="text/css" href="/application.css")
        block head
      body
        .container
          .info \#{_message}
          h1 #{name}
          hr
          block body
            block content
        #inlineScripts
          script(type="module" src="/application.js")
          block inline

  """
  await c.writeFile('app/views', 'layout.pug', buffer, true)

  # spec
  buffer = """
    global.assert  = require('assert');
    global.expect  = require('chai').expect;
    global.request = require('supertest');
    global.faker   = require('faker');

    const CoffeeScript = require('coffeescript');
    CoffeeScript.register();
  """
  await c.writeFile('test', '_spec.test.js', buffer)

  # package
  pkg =
    name: name
    scripts:
      start: "serven server",
      devel: "nodemon -e coffee --ignore 'app/assets/* data/* public/* tmp/*'"
      test: "NODE_ENV=test mocha --bail --parallel=false"
    dependencies:
      serven: version
    devDependencies:
      chai: "^4.3.4"
      faker: "^5.5.3"
      mocha: "^8.3.2"
      nodemon: "^2.0.7"
      supertest: "^6.1.3"

  for k,v of packages
    pkg.dependencies[k] = v

  buffer = JSON.stringify(pkg, null, 2)
  await c.writeFile('', 'package.json', buffer, true)

  child_process = require('child_process')
  child_process.spawn 'npm', ['install'],
    cwd: c.root
    env:
      PATH: process.env.PATH
    stdio: 'inherit'

  return

commands['console'] = (argv) ->
  repl = require('coffeescript/repl')
  serven = require('../index')
  sequelize = serven.Model.load(config)
  sess = repl.start()
  Object.assign sess.context,
    serven: serven
    config: config
    sequelize: sequelize
  Object.assign sess.context, sequelize.models

commands['server'] = (argv) ->
  args = parseOptions([
    [ 'p', 'port=ARG', 'port to listen'  ]
    [ 'h', 'host=ARG', 'hostname to bind' ]
  ])
  argv = args.argv.slice(2)
  options = args.options

  port = process.env.PORT || 5000
  if options.port
    port = parseInt(options.port)
    if isNaN(port)
      console.log('Invalid port %s', options.port)

  host = undefined
  if options.host
    host = options.host

  http = require('http')
  Application = require('./Application')
  app = new Application(process.cwd())
  server = http.createServer(app)
  server.listen(port, host)

# !!!
commands['db'] = (argv) ->
  child_process = require('child_process')
  sequelize = config.require('sequelize')
  switch sequelize.options.dialect
    when 'sqlite'
      cp = child_process.spawn 'sqlite3', [
        sequelize.config.database
      ], {
        stdio: 'inherit'
      }
    when 'postgres'
      env = Object.assign({}, process.env)
      env.PGPASSWORD = sequelize.config.password
      cp = child_process.spawn 'psql', [
        "--username=#{sequelize.config.username}"
        "--host=#{sequelize.config.host}"
        "--port=#{sequelize.config.port}"
        sequelize.config.database
      ], {
        stdio: 'inherit'
        env
      }
    when 'mariadb', 'mysql'
      console.log(sequelize.config)
      cp = child_process.spawn 'mysql', [
        "--user=#{sequelize.config.username}"
        "--password=#{sequelize.config.password}"
        "--host=#{sequelize.config.host}"
        "--port=#{sequelize.config.port}"
        sequelize.config.database
      ], {
        stdio: 'inherit'
      }
    when 'mssql'
      console.log('tedious is not implemented yet.')

# !!!
commands['db:create'] = (argv) ->
  sequelize = config.require('sequelize')
  sequelize.options.logging = console.log
  info('db create', '')
  await sequelize.createSchema()

commands['db:drop'] = (argv) ->
  sequelize = config.require('sequelize')
  if config.env == 'production'
    console.log('Drop table is disable on production environment')
    process.exit(1)
    throw new Error()
  sequelize.options.logging = console.log
  warn('db drop', '')
  await sequelize.queryInterface.dropAllTables()

commands['db:reset'] = (argv) ->
  await commands['db:drop']()
  await commands['db:create']()
  await commands['db:migrate']()
  await commands['db:seed']()

commands['db:seed'] = (argv) ->
  sequelize = Model.load(config)
  seeds = config.readdir('seeds')
  for file in seeds
    if /^\d+-/.test(file) == false
      continue
    name = path.parse(file).name
    index = name.indexOf('-')
    id = parseInt(name.substr(0, index))
    name = name.substr(index + 1)

    info('seed', name)
    loader = config.import('seeds', file)
    seed = loader(config, sequelize)
    await seed.up()

commands['db:migrate'] = (argv) ->
  sequelize = config.require('sequelize')
  { queryInterface, Sequelize } = sequelize

  sequelize.options.logging = console.log

  await createMigrationsTable(sequelize)

  migrations = config.readdir('migrations')

  for file in migrations
    name = path.parse(file).name
    index = name.indexOf('-')
    id = parseInt(name.substr(0, index))
    name = name.substr(index + 1)

    rows = await queryInterface.select null, 'migrations',
      where: {id}
      logging: false
    continue if rows.length

    loader = config.import('migrations', file)
    migration = loader(config, sequelize)

    info('migrate', name)
    try
      await migration.up()
      await queryInterface.insert null, 'migrations', {id},
        logging: false
    catch error
      console.error(error)

  # process.exit(0)

commands['db:status'] = (arv) ->
  sequelize = config.require('sequelize')
  { Sequelize } = sequelize

  await createMigrationsTable(sequelize)

  files = config.readdir('migrations')

  query = 'select * from migrations order by id asc'
  rows = await sequelize.query(query, Sequelize.QueryTypes.SELECT, logging: false)
  rows = rows[0].map (r) -> r.id
  found = []
  for file in files
    up = false
    basename = path.basename(file)
    for id in rows
      if basename.match("^#{id}-")
        up = true
        found.push(id)
        break
    name = basename.replace(/\.coffee$/, '')
    status = up && ' up ' || 'down'
    console.log('[ %s ] %s', status, name)
  lost = rows.filter (v) => found.includes(v) == false
  await sequelize.queryInterface.bulkDelete('migrations', {id: lost}, logging: false)
  process.exit(0)
  return

commands['db:rollback'] = (argv) ->
  args = parseOptions([
    [ '', 'to=ARG', 'rollbacks everything after ARG' ]
  ])
  argv = args.argv.slice(2)
  options = args.options

  if argv[0] == 'all'
    steps = -1
  else
    steps = if argv[0] then parseInt(argv[0]) else 1

  sequelize = config.require('sequelize')
  { queryInterface, Sequelize } = sequelize
  sequelize.options.logging = console.log

  await createMigrationsTable(sequelize)

  where = {}

  if options.to
    to = parseInt(options.to)
    if isNaN(to)
      console.log('Invalid number: %s', options.to)
      process.exit(1)
    where.id = {
      [Sequelize.Op.gt]: to
    }
    steps = -1

  rows = await queryInterface.select null, 'migrations',
    where: where
    order: [['id', 'desc']]
    limit: steps
    logging: false

  return if rows.length == 0

  migrations = config.readdir('migrations')

  for row in rows
    rowid = parseInt(row.id)
    for file in migrations
      name = path.parse(file).name
      index = name.indexOf('-')
      id = parseInt(name.substr(0, index))
      name = name.substr(index + 1)
      continue if id != rowid

      loader = config.import('migrations', file)
      migration = loader(config, sequelize)

      warn('rollback', name)
      try
        await migration.down()
        await queryInterface.bulkDelete 'migrations', {id},
          logging: false
      catch error
        console.error(error)
  process.exit(0)

commands['db:dump'] = (argv) ->
  args = parseOptions([
    [ '', 'pretty', 'Outputs formatted data' ]
  ])
  argv = args.argv.slice(2)
  options = args.options

  name = argv[0]
  if !name
    return console.log('help:db:dumb')

  indent = if options.pretty then 2 else undefined

  sequelize = Model.load(config)
  { queryInterface }  = sequelize

  dump = {}
  restore = {}
  for k,v of sequelize.models
    restore[k] = (await queryInterface.select(null, v.tableName))

  count = Object.keys(restore).length
  its = 0
  while count
    its += 1
    if its > 30
      throw new RangeError('max call stack exceeded')

    for modelName,model of restore
      m = sequelize.models[modelName]
      pending = []
      for k,v of m.associations
        if v.associationType == 'BelongsTo'
          if !dump[v.target.name]
            pending.push(v.target.name)
      continue if pending.length
      dump[modelName] = restore[modelName]
      delete restore[modelName]
    count = Object.keys(restore).length

  dump = JSON.stringify(dump, null, indent)
  fs.writeFileSync(name, dump)

commands['db:restore'] = (argv) ->
  args = parseOptions([
    [ '', 'pretty', 'Outputs formatted data' ]
  ])
  argv = args.argv.slice(2)
  options = args.options

  name = argv[0]
  if !name
    return console.log('help:db:restore')

  resolved = {}
  sequelize = Model.load(config)
  { queryInterface } = sequelize

  opt =
    validate: true
    hooks: true
    individualHooks: true

  dump = JSON.parse(fs.readFileSync(name))
  count = Object.keys(dump).length
  its = 0
  while count
    its += 1
    if its > 30
      throw new RangeError('max call stack exceeded')

    for modelName,rows of dump
      model = sequelize.models[modelName]
      pending = []
      for assocName,association of model.associations
        if association.associationType == 'BelongsTo'
          target = association.target.name
          pending.push(target) if !resolved[target]
      continue if pending.length

      try
        if rows.length
          # await queryInterface.bulkDelete(model.tableName, {})
          await queryInterface.bulkInsert(model.tableName, rows, opt)
      catch error
        console.log(error.message)
        console.log(rows)
        return

      resolved[modelName] = true
      delete dump[modelName]
    count = Object.keys(dump).length
  return

commands["generate:model"] = (argv) ->
  args = parseOptions([
    [ 'f', 'force',      'overwrite existing files'  ]
    [  '', 'timestamps', 'generate create and modify timestamps' ]
  ])
  argv = args.argv.slice(2)
  options = args.options

  name = argv[0]
  if !name
    return console.log('help:generate:model')

  columns   = argv.slice(1)

  await generateModel(name, columns, options)
  return

commands['generate:migration'] = (argv) ->
  args = parseOptions([
    [ 'f', 'force',      'overwrite existing files'  ]
    [  '', 'timestamps', 'generate create and modify timestamps' ]
  ])
  argv = args.argv.slice(2)
  options = args.options

  name = argv[0]
  if !name
    console.log('help:generate:migration')
    return

  files = config.readdir('migrations')
  for file in files
    re = new RegExp("^\\d+-#{name}.coffee$")
    continue unless re.test(file)
    filename = config.join('migrations', file)
    break

  if filename
    if !options.force
      console.log('Migration %s already exists.', name)
      console.log('Use --force to overwrite.')
      process.exit(1)
  else
    id = Date.now()
    basename = "#{id}-#{name}.coffee"
    filename = config.join('migrations', basename)

  if (re = /^add_(\w+)_to_(\w+)$/) && re.test(name)
    tableName = re.exec(name)[2]
    columns = argv.slice(1)
    buffer = CodeGenerator.addColumn(tableName, columns, options)
  else if (re = /^create_(\w+)$/) && re.test(name)
    tableName = re.exec(name)[1]
    columns = argv.slice(1)
    # columns.unshift('id:primary_key')
    if options.timestamps
      columns.push('created_at:date:r:g')
      columns.push('updated_at:date:r:g')
    buffer = CodeGenerator.createTable(tableName, columns, options)
  else if (re = /^rename_(\w+)_to_(\w+)_from_(\w+)$/) && re.test(name)
    matches = name.match(re)
    tableName = matches[3]
    oldName = matches[1]
    newName = matches[2]
    buffer = CodeGenerator.renameColumn(tableName, oldName, newName, options)
  else if (re = /^change_(\w+)_from_(\w+)$/) && re.test(name)
    matches = name.match(re)
    field = matches[1]
    tableName = matches[2]
    oldCol = parseColumn(field + ':' + argv[1])
    newCol = parseColumn(field + ':' + argv[2])
    buffer = CodeGenerator.changeColumn(tableName, oldCol, newCol)
  else
    buffer = CodeGenerator.migration(name, options)

  await writeFile(filename, buffer, options.force)

commands['generate:seed'] = (argv) ->
  name = argv[0]
  if !name
    console.log('help:generate:seed')
    return
  id = Date.now()
  basename = "#{id}-#{name}.coffee"
  filename = config.join('seeds', basename)
  buffer = CodeGenerator.seed()
  await writeFile(filename, buffer)

commands['destroy:model'] = (argv) ->
  args = parseOptions([
    [ 'f', 'force',      'overwrite existing files'  ]
  ])
  argv = args.argv.slice(2)
  options = args.options

  name = argv[0]
  if !name
    return console.log('help:destroy:model')

  await destroyModel(name, options)
  return

commands['destroy:migration'] = (argv) ->
  args = parseOptions([
    [ 'f', 'force', 'overwrite existing files'  ]
  ])
  argv = args.argv.slice(2)
  options = args.options

  name = argv[0]
  if !name
    console.log('help:destroy:migration')
    return

  files = config.readdir('migrations')
  for file in files
    re = new RegExp("^\\d+-#{name}.coffee$")
    continue unless re.test(file)
    filename = config.join('migrations', file)
    await unlink(filename)
    break

commands['destroy:seed'] = (argv) ->
  name = argv[0]
  if !name
    return console.log('help:destroy:seed')
  files = config.readdir('seeds')
  for file in files
    re = new RegExp("^\\d+-#{name}.coffee$")
    continue unless re.test(file)
    filename = config.join('seeds', file)
    await unlink(filename)
    break

commands["generate:script"] = (argv) ->
  args = parseOptions([
    [ 'f', 'force',   'overwrite existing files' ]
  ])
  argv = args.argv.slice(2)
  options = args.options

  name = argv[0]
  if !name
    return console.log('help:generate:script')

  await generateScript(name, options)
  return

commands["destroy:script"] = (argv) ->
  args = parseOptions([
    [ 'f', 'force',      'overwrite existing files'  ]
  ])
  argv = args.argv.slice(2)
  options = args.options

  name = argv[0]
  if !name
    return console.log('help:destroy:script')

  await destroyScript(name, options)
  return

commands["generate:stylesheet"] = (argv) ->
  args = parseOptions([
    [ 'f', 'force',   'overwrite existing files' ]
  ])
  argv = args.argv.slice(2)
  options = args.options

  name = argv[0]
  if !name
    return console.log('help:generate:stylesheet')

  await generateStylesheet(name, options)
  return

commands["destroy:stylesheet"] = (argv) ->
  args = parseOptions([
    [ 'f', 'force',      'overwrite existing files'  ]
  ])
  argv = args.argv.slice(2)
  options = args.options

  name = argv[0]
  if !name
    return console.log('help:destroy:stylesheet')

  await destroyStylesheet(name, options)
  return

commands["generate:helper"] = (argv) ->
  args = parseOptions([
    [ 'f', 'force',   'overwrite existing files' ]
  ])
  argv = args.argv.slice(2)
  options = args.options

  name = argv[0]
  if !name
    return console.log('help:generate:helper')

  namespace = path.dirname(name)
  basename = inflection.camelize(path.basename(name)) + '.coffee'
  await config.mkdir('helpers', namespace)

  filename = config.join('helpers', namespace, basename)
  relative = path.relative(config.root, filename)
  buffer = CodeGenerator.helper(relative, options)
  await writeFile(filename, buffer, options.force)

commands["destroy:helper"] = (argv) ->
  args = parseOptions([
    [ 'f', 'force',      'overwrite existing files'  ]
  ])
  argv = args.argv.slice(2)
  options = args.options

  name = argv[0]
  if !name
    return console.log('help:destroy:helper')

  await destroyHelper(name, options)
  return

commands["generate:view"] = (argv) ->
  args = parseOptions([
    [ 'f', 'force',   'overwrite existing files' ]
    [ 'e', 'extends=ARG', 'parent view to extend' ]
  ])
  argv = args.argv.slice(2)
  options = args.options

  name = argv[0]
  if !name
    return console.log('help:generate:view')

  await generateView(name, options)

commands["destroy:view"] = (argv) ->
  args = parseOptions([
    [ 'f', 'force', 'overwrite existing files'  ]
  ])
  argv = args.argv.slice(2)
  options = args.options

  name = argv[0]
  if !name
    return console.log('help:destroy:view')

  await destroyView(name)

commands["generate:controller"] = (argv) ->
  args = parseOptions([
    [ 'f', 'force', 'overwrite existing files' ]
  ])
  argv = args.argv.slice(2)
  options = args.options

  name = argv[0]
  if !name
    return console.log('help:generate:controller')

  actions = argv.slice(1)

  await generateController(name, actions, options)
  return

commands['destroy:controller'] = (argv) ->
  args = parseOptions([
    [ 'f', 'force', 'overwrite existing files'  ]
  ])
  argv = args.argv.slice(2)
  options = args.options

  name = argv[0]
  if !name
    return console.log('help:destroy:controller')

  actions = argv.slice(1)

  await destroyController(name, actions, options)
  return

commands["generate:scaffold"] = (argv) ->
  args = parseOptions([
    [ 'f', 'force',       'overwrite existing files'  ]
    [  '', 'timestamps',  'generate create and modify timestamps' ]
    [ 'e', 'extends=ARG', 'parent view to extend' ]
  ])
  argv = args.argv.slice(2)
  options = args.options

  name = argv[0]
  if !name
    return console.log('help:generate:scaffold')

  columns = argv.slice(1)

  await generateModel(name, columns, options)

  className = path.basename(name).replace(/-/g, '_')
  className = inflection.pluralize(className)
  className = inflection.camelize(className)
  model = inflection.classify(className)
  record = inflection.underscore(model)
  collection = inflection.underscore(className)
  human = inflection.humanize(record, false)
  title = inflection.humanize(collection, false)
  layout = options.extends || '/layout'

  namespace = path.dirname(name)
  url = '/' + inflection.dasherize(namespace) + '/' +
    inflection.dasherize(collection)
  views = path.join(
    inflection.dasherize(namespace),
    inflection.dasherize(collection)
  )

  generateScript(views, options)
  generateStylesheet(views, options)
  await config.mkdir('views', views)

  deps = []
  collections = {}
  cols = columns.map(parseColumn)
  for col in cols
    if col.options.references
      t = col.options.references.model.tableName
      m = inflection.classify(t)
      collections[col.fieldName] = t;
      deps.push("    @dep.#{t} = await @models.#{m}.findAll()")

  # controller
  basename = className + '.coffee'
  filename = config.join('controllers', namespace, basename)
  buffer = """
  { Controller } = require('serven')

  class #{className} extends Controller
    @before_action 'set_#{record}', only: ['read', 'edit', 'update', 'delete']

    @before_action 'get_dependencies', only: ['new', 'edit', 'create', 'update']

    get_dependencies: ->
      return if @_api
      @dep = {}
  #{deps.join('\n')}

    search: ->
      @#{collection} = await @models.#{model}.findAndCountAll(@search_params())
      if @_api
        @_json = @#{collection}
      else
        @#{record} = @models.#{model}.build()

    new: ->
      @#{record} = @models.#{model}.build()

    create: ->
      @#{record} = @models.#{model}.build(@#{record}_params())
      try
        await @#{record}.save()
        if @_api
          @render(status: 201, location: @#{record}_url(@#{record}), json: @#{record})
        else
          @render
            redirect: @#{collection}_url()
            message: "#{human} created successfully."
      catch error
        if @_api
          @render(status: 422, json: error)
        else
          @#{record}.error = error
          @render('new')

    read: ->
      @render(json: @#{record}) if @_api

    update: ->
      try
        await @#{record}.update(@#{record}_params())
        if @_api
          @render(location: @#{record}_url(@#{record}), json: @#{record})
        else
          @render
            redirect: @#{record}_url(@#{record})
            message: "#{human} updated successfully."
      catch error
        @#{record}.error = error
        if @_api
          @render(status: 422, json: error)
        else
          @render('edit', status: 422)

    delete: ->
      await @#{record}.destroy()
      if @_api
        @render(head: 204)
      else
        @render
          redirect: @#{collection}_url()
          message: "#{human} deleted successfully."

    set_#{record}: ->
      @#{record} = await @models.#{model}.findByPk @_params['id']
      if @#{record} == null
        @render(head: 404)

    #{record}_params: ->
      @_body.#{record}

    search_params: ->

  module.exports = #{className}

  """
  await config.mkdir('controllers', namespace)
  await writeFile(filename, buffer, options.force)

  # helpers
  filename = config.join('helpers', namespace, className + '.coffee')
  buffer = """
  path = require('path')
  module.exports =
    #{record}_url: (record, ...action) ->
      path.join('#{url}', String(record.id), ...action)

    #{collection}_url: (...action) ->
      path.join('#{url}', ...action)

  """
  await config.mkdir('helpers', namespace)
  await writeFile(filename, buffer, options.force)

  # search
  headers = []
  cells = []
  for col in cols
    continue if col.options._autoGenerated
    header = inflection.humanize(col.field)
    headers.push "        th #{header}"
    cell = "          td \#{#{record}.#{col.fieldName}}"
    cells.push cell
  filename = viewName(path.join(views, 'search'))
  buffer = """
  extends #{layout}
  block content
    div
      h3 #{title}
      hr
      p
        a(href=#{collection}_url('new')) Create #{human}
      table
        thead
  #{headers.join('\n')}
          th
          th
        tbody: each #{record} in #{collection}.rows
          tr
  #{cells.join('\n')}
            td
              a(href=#{record}_url(#{record})) view
            td
              a(href=#{record}_url(#{record}, 'edit')) edit
            td
              a(href=#{record}_url(#{record}) data-delete) delete

  """
  await writeFile(filename, buffer, options.force)

  # read
  presenters = []
  tab = "    "
  for col in cols
    continue if col.options._autoGenerated
    label = inflection.humanize(col.field)
    presenter = "#{record}.#{col.fieldName}"
    presenters.push """
    #{tab}p
    #{tab}  b #{label}&nbsp;
    #{tab}  span \#{#{presenter}}
    """

  filename = viewName(path.join(views, 'read'))
  buffer = """
  extends #{layout}
  block content
    div
      h3 #{human}
      hr
      p
        a(href=#{collection}_url()) back
        | &nbsp;
        a(href=#{record}_url(#{record}, 'edit')) edit
  #{presenters.join('\n')}

  """
  await writeFile(filename, buffer, options.force)


  # form
  filename = viewName(path.join(views, 'form'))
  fields = []
  for col in cols
    continue if col.options._autoGenerated
    label = inflection.humanize(col.field)
    opt = { label }
    if collections[col.fieldName]
      c = "dep.#{collections[col.fieldName]}"
      opt.collection = '$c'
    opt = JSON.stringify(opt).replace('"$c"', c)
    fields.push "!= field('#{col.fieldName}', #{opt})"

  buffer = """
  != form(#{record})
  #{fields.join('\n\n')}

  """
  await writeFile(filename, buffer, options.force)

  enctype="multipart/form-data"

  # new
  filename = viewName(path.join(views, 'new'))
  buffer = """
  extends #{layout}
  block content
    h3 Create #{human}
    hr
    p
      a(href=#{collection}_url()) back
    form(method="POST" action=#{collection}_url() enctype="#{enctype}")
      include form
      p
        button(type="submit") Create

  """
  await writeFile(filename, buffer, options.force)

  # edit
  filename = viewName(path.join(views, 'edit'))
  buffer = """
  extends #{layout}
  block content
    div
      h3 Edit #{human}
      hr
      p
        a(href=#{collection}_url()) back
        | &nbsp;
        a(href=#{record}_url(#{record})) view
      form(method="POST" action=#{record}_url(#{record}) + '?_method=PUT' enctype="#{enctype}")
        include form
        p
          button(type="submit") Update

  """
  await writeFile(filename, buffer, options.force)

  resources = path.join(namespace, collection)
  fd = fs.openSync(config.join('config', 'routes.coffee'), 'a+')
  fs.writeFileSync(fd, "\n  @resources '#{resources}'\n")
  fs.closeSync(fd)

  return

commands['destroy:scaffold'] = (argv) ->
  args = parseOptions([
    [ 'f', 'force', 'overwrite existing files' ]
  ])
  argv = args.argv.slice(2)
  options = args.options

  name = argv[0]
  if !name
    return console.log('help:generate:scaffold')

  columns = argv.slice(1)

  await destroyModel(name, options)

  className = path.basename(name).replace(/-/g, '_')
  className = inflection.pluralize(className)
  className = inflection.camelize(className)
  model = inflection.classify(className)
  record = inflection.underscore(model)
  collection = inflection.underscore(className)
  human = inflection.humanize(record, false)
  title = inflection.humanize(collection, false)
  layout = options.extends || '/layout'

  namespace = path.dirname(name)
  url = '/' + inflection.dasherize(namespace) + '/' +
    inflection.dasherize(collection)
  views = path.join(
    inflection.dasherize(namespace),
    inflection.dasherize(collection)
  )

  name = path.join(namespace, collection)

  actions = [
    'search', 'create', 'read', 'update', 'delete', 'new', 'edit', 'form'
  ]
  await destroyController(name, actions, options)

  await destroyHelper(name, options)

  await destroyScript(name, options)

  await destroyStylesheet(name, options)

  return

createMigrationsTable = (sequelize) ->
  { queryInterface, Sequelize } = sequelize
  await queryInterface.createTable 'migrations',
    id:
      allowNull: false
      primaryKey: true
      type: Sequelize.BIGINT
  , logging: false

viewName = (name) ->
  namespace = inflection.dasherize(path.dirname(name))
  basename = inflection.dasherize(path.basename(name)) + '.pug'
  filename = config.join('views', namespace, basename)

generateModel = (name, columns, options) ->
  className = path.basename(name).replace(/-/g, '_')
  className = inflection.classify(className)

  namespace = path.dirname(name)
  basename = className + '.coffee'

  tableName = inflection.underscore(className)
  tableName = inflection.pluralize(tableName)

  await config.mkdir('models', namespace)

  basename = "#{className}.coffee"
  filename = config.join('models', namespace, basename)
  buffer = CodeGenerator.model(className, columns, options)
  await writeFile(filename, buffer, options.force)

  filename = null
  buffer = null

  re = new RegExp("^\\d+-create_#{tableName}.coffee$")
  files = config.readdir('migrations')
  for file in files
    continue unless re.test(file)
    filename = config.join('migrations', file)
    break

  if filename
    if !options.force
      console.log('Migration %s already exists.', name)
      console.log('Use --force to overwrite.')
      process.exit(1)
  else
    id = Date.now()
    basename = "#{id}-create_#{tableName}.coffee"
    filename = config.join('migrations', basename)

  columns.unshift('id:primary_key')
  if options.timestamps
    columns.push('created_at:date:r:g')
    columns.push('updated_at:date:r:g')
  buffer = CodeGenerator.createTable(tableName, columns, options)
  await writeFile(filename, buffer, options.force)
  return

generateController = (name, actions, options) ->
  className = path.basename(name).replace(/-/g, '_')
  className = inflection.camelize(className)

  namespace = path.dirname(name)
  basename = className + '.coffee'

  await config.mkdir('controllers', namespace)
  filename = config.join('controllers', namespace, basename)

  buffer = CodeGenerator.controller(className, actions, options)
  await writeFile(filename, buffer, options.force)

  for action in actions
    await generateView(path.join(name, action), options)
  return

destroyModel = (name, options) ->
  className = path.basename(name).replace(/-/g, '_')
  className = inflection.classify(className)

  namespace = path.dirname(name)
  basename = className + '.coffee'

  tableName = inflection.underscore(className)
  tableName = inflection.pluralize(tableName)

  filename = config.join('models', namespace, basename)

  await unlink(filename)

  files = config.readdir('migrations')
  re = new RegExp("^\\d+-create_#{tableName}.coffee$")
  for file in files
    continue unless re.test(file)
    filename = config.join('migrations', file)
    await unlink(filename)
    break
  await config.rmdir('models', namespace)
  return

destroyController = (name, actions, options) ->
  className = path.basename(name).replace(/-/g, '_')
  className = inflection.camelize(className)

  namespace = path.dirname(name)
  basename = className + '.coffee'

  filename = config.join('controllers', namespace, basename)
  relative = path.relative(config.controllers, filename)
  if /^\./.test(relative)
    console.log('Invalid path %s', name)
    process.exit(1)

  await unlink(filename)
  await config.rmdir('controllers', namespace)

  for action in actions
    await destroyView(path.join(name, action), options)
  return

generateView = (name, options) ->
  namespace = inflection.dasherize(path.dirname(name))
  basename = inflection.dasherize(path.basename(name)) + '.pug'
  await config.mkdir('views', namespace)
  filename = config.join('views', namespace, basename)
  relative = path.relative(config.root, filename)
  buffer = CodeGenerator.view(relative, options)
  await writeFile(filename, buffer, options.force)

generateScript = (name, options) ->
  namespace = inflection.dasherize(path.dirname(name))
  basename = inflection.dasherize(path.basename(name)) + '.coffee'
  await config.mkdir('scripts', namespace)
  filename = config.join('scripts', namespace, basename)
  relative = path.relative(config.root, filename)
  buffer = CodeGenerator.script(relative, options)
  await writeFile(filename, buffer, options.force)

destroyScript = (name, options) ->
  filename = config.join('scripts', name) + '.coffee'
  relative = path.relative(config.scripts, filename)
  if /^\./.test(relative)
    console.log('Invalid path %s', name)
    process.exit(1)
  await unlink(filename)

  namespace = inflection.dasherize(path.dirname(name))
  await config.rmdir('scripts', namespace)

generateStylesheet = (name, options) ->
  namespace = inflection.dasherize(path.dirname(name))
  basename = inflection.dasherize(path.basename(name)) + '.styl'
  await config.mkdir('stylesheets', namespace)
  filename = config.join('stylesheets', namespace, basename)
  relative = path.relative(config.root, filename)
  buffer = CodeGenerator.stylesheet(relative, options)
  await writeFile(filename, buffer, options.force)
  return

destroyStylesheet = (name, options) ->
  filename = config.join('stylesheets', name) + '.styl'
  relative = path.relative(config.stylesheets, filename)
  if /^\./.test(relative)
    console.log('Invalid path %s', name)
    process.exit(1)
  await unlink(filename)

  namespace = inflection.dasherize(path.dirname(name))
  await config.rmdir('stylesheets', namespace)
  return

destroyView = (name, options) ->
  filename = config.join('views', name) + '.pug'
  relative = path.relative(config.views, filename)
  if /^\./.test(relative)
    console.log('Invalid path %s', name)
    process.exit(1)
  await unlink(filename)
  namespace = path.dirname(name)
  await config.rmdir('views', namespace)

destroyHelper = (name, options) ->
  namespace = path.dirname(name)
  className = path.basename(name).replace(/-/g, '_')
  className = inflection.underscore(className)
  className = inflection.camelize(className)
  basename = className + '.coffee'

  filename = config.join('helpers', namespace, basename)
  relative = path.relative(config.helpers, filename)
  if /^\./.test(relative)
    console.log('Invalid path %s', name)
    process.exit(1)
  await unlink(filename)
  await config.rmdir('helpers', namespace)
  return

info = (label, text) ->
  c = process.env.COLORTERM == 'truecolor'
  pref = c && '\x1b[0;32m' || ''
  suff = c && '\x1b[0m' || ''
  console.log("[ #{pref}#{label}#{suff} ] %s", text)

warn = (label, text) ->
  c = process.env.COLORTERM == 'truecolor'
  pref = c && '\x1b[0;31m' || ''
  suff = c && '\x1b[0m' || ''
  console.log("[ #{pref}#{label}#{suff} ] %s", text)

writeFile = (filename, buffer, force = false) ->
  relative = path.relative('.', filename)
  info('create', relative)
  if !force && fs.existsSync(filename)
    console.log('Existing file "%s" will not be overwriten.', filename)
    console.log('Use --force overwrite existing files.')
    process.exit(1)
    throw new Error()
  else
    fs.writeFileSync(filename, buffer, 'UTF-8')

unlink = (filename) ->
  new Promise (resolve, reject) ->
    relative = path.relative('.', filename)
    warn('remove', relative)
    if fs.existsSync(filename)
      fs.unlink filename, (error) ->
        resolve()
    else
      resolve()

class ColumnParser
  reInput = /^(\w{1,})\:(\w{1,})(\{.+\})?([:\w]{0,})$/
  reType = /((?:\w+)+)/g
  reFlag = /((?:\w+)+)/g

  constructor: (@input) ->
    matches = reInput.exec(@input)

    if !matches
      console.log('Invalid column: %s', @input)
      process.exit(1)

    @field = matches[1]
    @type = matches[2].toUpperCase()
    @targ = (matches[3] || '').match(reType) || []
    @carg = (matches[4] || '').match(reFlag) || []

    @args = []
    for value,index in @targ
      if /^\w+$/.test(value)
        value = parseInt(value)
        @targ[index] = value
      @args.push(value)

    @options = {}
    @associations = []

    @resolveType()
    @resolveOptions()

    @fieldName = inflection.camelize(@field, @associations.length == 0)
    if @targ.length
        args = @args.map((v) => JSON.stringify(v)).join(', ')
        @columnType = "Sequelize.#{@type}(#{args})"
        @modelType = [ @type, ...@args ]
      else
        @columnType = "Sequelize.#{@type}"
        @modelType = @type

  resolveType: ->
    switch @type
      when 'PRIMARY_KEY'
        @type = 'INTEGER'
        @options['allowNull'] = false
        @options['autoIncrement'] = true
        @options['primaryKey'] = true
        @options['_autoGenerated'] = true
      when 'UNSIGNED'
        @type = 'INTEGER'
        @args.push(unsigned: true)
      when 'REFERENCES'
        @type = 'INTEGER'
        tableName = inflection.pluralize(@field)
        @options.allowNull = false
        @options.references =
          model:
            tableName: tableName
          key: 'id'
        @associations.push([
          'belongsTo',
          inflection.classify(@field)
        ])
        @field += '_id'
    return

  resolveOptions: ->
    for arg in @carg
      switch arg
        when 'r', 'req', 'required'
          @options['allowNull'] = false
        when 'o', 'opt', 'optional'
          @options['allowNull'] = true
        when 'u', 'uniq', 'unique'
          @options['unique'] = true
        when 'i', 'index'
          console.log('...')
        when 'a', 'auto', 'autoincrement'
          @options['autoIncrement'] = true
        when 'g', 'gen', 'generated'
          @options['_autoGenerated'] = true
    return

parseColumn = (input) ->
  new ColumnParser(input)

class CodeGenerator
  MIGRATION_HEADER = """
  module.exports = (config, sequelize) ->
    { queryInterface, Sequelize } = sequelize
  """

  @model: (className, columns, options) ->
    CSONUtil = require('./CSONUtil')
    cols = columns.map (c) -> parseColumn(c)

    attrs = []
    assocs = []
    tags = []
    for col in cols
      skip = false
      for [ type, model ] in col.associations
        assocs.push("  @#{type} \"#{model}\"")
        skip = true
      continue if skip
      type = JSON.stringify(col.modelType)
      opt = CSONUtil.stringify(col.options, 2)
      opt = if opt.length then ",\n#{opt}" else "\n"
      attrs.push "  @attr \"#{col.fieldName}\", #{type}#{opt}"
    if options.timestamps
      tags.push("  @timestamps true")

    """
    { Model } = require('serven')

    class #{className} extends Model
    #{attrs.join('\n')}
    #{assocs.join('\n\n')}

    #{tags.join('\n')}

    module.exports = #{className}

    """.replace(/\n{2,}/g, '\n\n')

  validateColumns = (columns, options) ->
    keys = {}
    for column in columns
      { field } = column
      if keys[field]
        console.log('Field "%s" was duplicated.', field)
        process.exit(1)
      keys[field] = true
    return

  @createTable = (tableName, columns, options) ->
    CSONUtil = require('./CSONUtil')
    cols = columns.map((c) -> parseColumn(c))

    validateColumns(cols)

    up = []
    tab = ""
    for col in cols
      opt = Object.assign({}, col.options)
      opt.type = "${TYPE}"
      opt = CSONUtil.stringify(opt, 4).replace('"${TYPE}"', col.columnType)
      up.push "      #{col.field}:\n#{opt}"

    """
    #{MIGRATION_HEADER}

      up: ->
        await queryInterface.createTable "#{tableName}",
    #{up.join('\n')}
      down: ->
        await queryInterface.dropTable "#{tableName}"

    """

  @addColumn = (tableName, columns) ->
    CSONUtil = require('./CSONUtil')

    cols = columns.map((c) -> parseColumn(c))
    up = []
    down = []
    tab = "    "
    for col in cols
      opt = Object.assign({}, col.options)
      opt.type = "${TYPE}"
      opt = CSONUtil.stringify(opt, 3).replace('"${TYPE}"', col.columnType)
      up.push """
      #{tab}await queryInterface.addColumn "#{tableName}", "#{col.field}",
      #{opt}
      """
      down.push """
      #{tab}await queryInterface.removeColumn "#{tableName}", "#{col.field}"
      """

    """
      #{MIGRATION_HEADER}

        up: ->
        #{up.join('\n')}

        down: ->
      #{down.join('\n')}

    """

  @renameColumn = (tableName, oldName, newName, options) ->
    """
      #{MIGRATION_HEADER}

        up: ->
          await queryInterface.renameColumn("#{tableName}", "#{oldName}", "#{newName}")

        down: ->
          await queryInterface.renameColumn("#{tableName}", "#{newName}", "#{oldName}")

    """

  @changeColumn: (tableName, oldCol, newCol, options) ->
    CSONUtil = require('./CSONUtil')

    opt1 = Object.assign({}, oldCol.options)
    opt1.type = "${TYPE}"
    opt1 = CSONUtil.stringify(opt1, 3).replace('"${TYPE}"', oldCol.columnType)

    opt2 = Object.assign({}, newCol.options)
    opt2.type = "${TYPE}"
    opt2 = CSONUtil.stringify(opt2, 3).replace('"${TYPE}"', newCol.columnType)

    """
      #{MIGRATION_HEADER}

        up: ->
          await queryInterface.changeColumn "#{tableName}", "#{newCol.field}",
      #{opt2}
        down: ->
          await queryInterface.changeColumn "#{tableName}", "#{oldCol.field}",
      #{opt1}
    """

  @migration: (name, options) ->
    """
      #{MIGRATION_HEADER}

        up: ->

        down: ->

    """

  @seed = ->
    """
    module.exports = (config, sequelize) ->
      { models } = sequelize

      up: ->
        # await models.User.bulkCreate([
        #   { username: administrator" }
        # ])

      down: ->
        # await models.User.bulkDelete({
        #   username: ['administrator']
        # })

    """

  @view: (name, options) ->
    base = options.extends || '/layout'

    """
    extends #{base}
    block content
      p edit me at #{name}

    """

  @script: (name, options) ->
    """
    ###
    # Generated script file
    # #{name}
    ###

    """

  @stylesheet: (name, options) ->
    """
    //
    // Generated stylesheet file
    // #{name}
    //

    """

  @helper: (name, options) ->
    """
    module.exports = {
      # my_helper_method: (arg1, arg2) ->
      #   arg1 + '/' + arg2
    }
    """

  @controller: (className, actions, options) ->
    methods = []

    for action in actions
      methods.push "  #{action}: ->\n"

    """
    { Controller } = require('serven')

    class #{className} extends Controller
    #{methods.join('\n')}

    module.exports = #{className}

    """

main()
