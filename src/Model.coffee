Annotations = require('./Annotations')
Sequelize = require('sequelize')

class Model extends Sequelize.Model
  @abstract: (flag) ->
    Annotations.assert(this).abstract = flag

  @tableName: (name) ->
    a = Annotations.assert(this)
    a.options ?= {}
    a.options.tableName = name

  @attr: (name, type, options = {}) ->
    a = Annotations.assert(this)
    a.attributes ?= {}
    a.attributes[name] = options
    args = undefined
    if Array.isArray(type)
      args = type.slice(1)
      type = type[0]
    if typeof type == 'string'
      switch type
        when 'UNSIGNED'
          Sequelize.DataTypes.INTEGER.UNSIGNED
        else
          type = Sequelize.DataTypes[type]
    if args
      type = new type(...args)
    options.type = type
    a.attributes[name]

  @timestamps: (flag = true) ->
    a = Annotations.assert(this)
    a.options ?= {}
    a.options.timestamps = flag

  @paranoid: (flag = true) ->
    a = Annotations.assert(this)
    a.options ?= {}
    a.options.paranoid = flag

  @belongsTo: (name, options) ->
    a = Annotations.assert(this)
    a.associations ?= []
    a.associations.push [ this, 'belongsTo', name, options ]

  @hasOne: (name, options) ->
    a = Annotations.assert(this)
    a.associations ?= []
    a.associations.push [ this, 'hasOne', name, options ]

  @hasMany: (name, options) ->
    a = Annotations.assert(this)
    a.associations ?= []
    a.associations.push [ this, 'hasMany', name, options ]

  @belongsToMany: (name, options) ->
    a = Annotations.assert(this)
    a.associations ?= []
    a.associations.push [ this, 'belongsToMany', name, options ]

  @setScope: (name, value) ->
    a = Annotations.assert(this)
    a.options ?= {}
    a.options.scopes ?= {}
    a.options.scopes[name] = value

  @hook: (name, value) ->
    a = Annotations.assert(this)
    a.options ?= {}
    a.options.hooks ?= {}
    a.options.hooks[name] ?= []
    a.options.hooks[name].push(value)

  collect_files = (record) ->
    for k,v of record.dataValues
      if v && typeof v == 'object'
        if v.filename && v.path
          record._files ?= {}
          record._files[k] = v
          record.dataValues[k] = v.filename
    return

  move_files = (record, params) ->
    return unless record.id
    return unless record._files
    fs = require('fs/promises')
    path = require('path')
    inflection = require('inflection')

    model = record.constructor
    config = model.config
    dataValues = {}
    for k,v of record._files
      console.log(v)
      name = inflection.underscore(model.options.name.plural)
      filename = config.join('storage', name, String(record.id), k)
      await config.mkdir("storage", "#{name}/#{record.id}")
      await fs.rename(v.path, filename)
      relative = path.relative(config.root, filename)
      dataValues[k] = relative
    await record.update(dataValues, {hooks: false})
    return

  @_beforeValidate: (record, params) ->
    for k,v of record.dataValues
      if v is ''
        record.dataValues[k] = null
    await collect_files(record)
    return

  @_validationFailed: (record, params, error) ->
    record.error = error

  @all: (...args) ->
    (await @findAll(...args)).map (record) ->
      record.toJSON()

  @find: (...args) ->
    record = await @findOne(...args)
    record && record.toJSON() || null

  @sync: (options = {}) ->
    if options.unsafe
      return super.sync(options)
    throw new Error()

  @load: (config) ->
    sequelize = config.require('sequelize')
    associations = []

    for file in config.readdir('models')
      model = config.import('models', file)

      model.config = config

      a = Annotations.assert(model)
      continue if a.abstract

      a.options ?= {}
      a.options.sequelize = sequelize
      a.associations ?= []
      model.init(a.attributes, a.options)

      for association in a.associations
        associations.push(association)

      model.addHook 'beforeValidate', @_beforeValidate
      model.addHook 'validationFailed', @_validationFailed
      model.addHook 'afterSave', move_files

    for association in associations
      [ model, method, name, options ] = association
      target = sequelize.models[name]
      Sequelize.Model[method].apply(model, [target, options])

    sequelize

module.exports = Model
