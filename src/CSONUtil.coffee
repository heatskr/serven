
class CSONUtil
  sp = ' '

  @stringify: (o, dpt) ->
    cson = new CSONUtil(2)
    cson.ori(o, dpt)
    cson.buf

  constructor: (@tab = 0) ->
    @buf = ""
    @walker = @str.bind(this)
    @width = 40

  # JSON beautifier helper
  json: (msg, dpt) ->
    pref = ''.padEnd(dpt * @tab, sp)
    str = ' ' + pref + JSON.stringify(msg) + '\n'
    if (str.length < @width)
      @buf += str
      return true
    return false

  # stringifier
  str: (key, val, dpt = 0) ->
    pref = ''.padEnd(dpt * @tab, sp)
    @buf += pref
    @buf += key + ':'
    if typeof val == 'object'
      if Array.isArray(val, dpt)
        return if @json(val)
        @buf += ' [\n'
        @ari(val, dpt)
        @buf += pref
        @buf += ']'
    else
      @buf += ' ' + JSON.stringify(val)
    @buf += '\n'
    return

  # Object recursive iterator
  ori: (obj, dpt = 0) ->
    for key, val of obj
      @walker(key, val, dpt)
      if typeof val == 'object'
        if Array.isArray(val) == false
          @ori(val, dpt + 1)
    return

  # Array recursive iterator
  ari: (ary, dpt) ->
    pref = ''.padEnd((dpt + 1) * @tab, sp)
    for item in ary
      # continue if @json(item, dpt)
      @buf += pref
      if (typeof item) == 'object'
        @buf += '{\n'
        @ori(item, dpt + 2)
        @buf += pref
        @buf += '}'
      else
        @buf += JSON.stringify(item)
      @buf += '\n'
    return

module.exports = CSONUtil
