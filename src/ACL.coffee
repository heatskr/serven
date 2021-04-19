class ACL
  constructor: (options = {}) ->
    @cache = options.cache ? []
    @roles = options.roles ? []
    @permissions = options.permissions ? []
    @rules = options.rules ? []

  addRole: (role) ->
    if @roles.indexOf(role) == -1
      @roles.push(role)
    this

  addPermission: (permission) ->
    if @permissions.indexOf(permission) == -1
      @permissions.push(permission)
    this

  can: (roles, perm) ->
    roles = [roles] if typeof roles == 'string'
    allowed = false
    for role in roles
      for [ permName, roleNames ] in @cache
        if permName == perm && roleNames.includes(role)
          allowed = true
          break
          break
    allowed

  allow: (roles, perms) ->
    @exec('allow', roles, perms)

  deny: (roles, perms) ->
    @exec('deny', roles, perms)

  exec: (type, roles, perms) ->
    allow = (type == 'allow')
    roles = [roles] if typeof roles == 'string'
    perms = [perms] if typeof perms == 'string'

    foundRoles = @roles.filter (r) ->
      for role in roles
        re = new RegExp("^#{role.replace(/\*/,'.+')}$")
        if re.test(r)
          return true
      false

    for role in foundRoles
      permissions = @permissions.filter (p) ->
        for perm in perms
          re = new RegExp("^#{perm.replace(/\*/,'.+')}(_\d+)?$")
          if re.test(p)
            return true
        false

      for permission in permissions
        entry = @cache.filter((e) -> e[0] == permission)[0]
        if !entry
          entry = [permission, []]
          @cache.push(entry)
        if allow
          if entry[1].indexOf(role) == -1
            entry[1].push(role)
        else
          entry[1] = entry[1].filter((r) -> r != role)
    this

  flush: ->
    @cache = []
    this

  save: ->
    for permission in @permissions
      entry = @cache.filter((e) -> e[0] == permission)[0]
      if !entry
        @cache.push([permission, []])

    if typeof @rules == 'function'
      @rules()
    else
      for rule in @rules
        @exec(...rule)
    this

module.exports = ACL
