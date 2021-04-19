class Annotations
  @map: new WeakMap()
  @get: (o) -> @map.get(o)
  @set: (o, v) -> @map.set(o, v)
  @assert: (o) ->
    if !@map.has(o)
      @map.set(o, {})
    @map.get(o)

module.exports = Annotations
