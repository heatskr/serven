_form = null

entry = (record, key, options) ->
  model = record.constructor
  name = model.options.name.singular
    .replace(/^([A-Z])/, (i,v) => v.toLowerCase())
    .replace(/([A-Z])/g, (i,v) => "_" + v.toLowerCase())

  field = model.rawAttributes[key]
  attrs = {}
  attrs.name = "#{name}[#{key}]"
  attrs.id = "#{name}-#{key}"
  attrs.class = "form-control"

  empty = (record[key] == undefined) || (record[key] == null)
  attrs.value = if empty then '' else  record[key]

  tagName = 'input'
  innerHTML = []

  switch field.type.key
    when 'INTEGER'
      if field.references
        tagName = 'select'
        if options.collection
          for r in options.collection
            v = r.id
            k = r.name || r.id
            selected = if (v == record[key]) then "selected" else ""
            innerHTML.push("<option #{selected} value=\"#{v}\">#{k}</option>")
      else
        attrs.type = 'number'
    when 'DECIMAL'
      attrs.type = 'number'
      attrs.step = '0.01'
    when 'TEXT'
      tagName = 'textarea'
      innerHTML.push(record[key]) unless empty
    else
      if key == 'password'
        attrs.type = 'password'
      else
        attrs.type = options.type || 'text'
        attrs.autocomplete = "off"
        attrs.spellcheck = "false"

  attrib = []

  for k,v of attrs
    attrib.push("#{k}=\"#{v}\"")

  selfClosable = [ 'input' ].includes(tagName)
  tag = "<#{tagName} #{attrib.join(' ')} " + (selfClosable && "/>" || ">")
  if !selfClosable
    tag += innerHTML.join('\n')
    tag += "</#{tagName}>"

  label = options.label || (
    key.replace(/Id$/, '').replace(/^([a-z])/, (i,v) => v.toUpperCase())
  )

  errors = []
  if record.error && record.error.errors
    for error in record.error.errors
      if error.path == key
        errors.push(error.message)

  """
  <div class="form-group">
    <label for="">#{label}</label>
    <div>#{tag}</div>
    <div class="validate">#{errors.join('<br/>')}</div>
  </div>
  """

module.exports =
  form: (record) ->
    _form = record
    return

  field: (field, options) ->
    entry(_form, field, options)

  currency: (value, currency='USD', locale='en-US') ->
    intl = new Intl.NumberFormat locale,
      style: 'currency'
      currency: currency
    intl.format(value)
