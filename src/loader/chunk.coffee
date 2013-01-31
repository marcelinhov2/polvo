class Chunk

  @chunks = {}
  @chunks_list = []

  type: null

  id: null
  deps: null
  factory: null
  non_amd: null
  factored: null

  constructor:( @type, @id, @deps, @factory, @non_amd = false )->
    if @id? and @id[0] is ':'
      @id = (@id.substr 1)

    Chunk.chunks_list.push @

  # notify all loaded-but-not-yet-executed chunks that a new file has
  # finish loading, so the execution can occur
  @notify_all = ( loaded )->
    for chunk in @chunks_list
      chunk.exec loaded

  @reorder:( id )->

    start = @_get_index_by_id id

    for chunk, chunk_index in @chunks_list
      continue unless (deps = chunk.deps).length

      for dep_id, index in deps
        continue if dep_id[0] is ':'

        dep = @chunks[dep_id]
        dep_index = @_get_index_by_id dep_id

        if dep_index is null or (dep_index < chunk_index)
          continue

        if chunk.id in dep.deps
          console.error 'Circular dependency found between '
          continue

        else
          @chunks_list.splice chunk_index, 0, dep
          @chunks_list.splice dep_index + 1, 1
          @reorder true

  @_get_index_by_id:( id )->
    for chunk, index in @chunks_list
      return index if chunk.id is id
    return null

  # execute the factory method and stores it in a `factored` property
  exec:( loaded )->

    # if was already factored, just returns it
    return @factored if @factored?

    # abort if dependencies hasn't finish loading
    return unless @_is_subtree_loaded()

    # abort if there's no factory function/object reference
    return unless @factory?

    # loop through all dependencies
    refs = []
    for dep in @deps

      if dep[0] is ':'
        continue

      # collects the factored ref
      current = Chunk.chunks[ dep ]
      mod = current.exec( loaded )
      if mod?
        refs.push mod

    # if factory is a method, execute it and keep the returned ref
    if @factory instanceof Function
      @execd = true if @type is 'require'
      @factored = @factory.apply null, refs

    # otherwise if it's a object literal, just stores it
    else if typeof @factory is 'object'
      @factored = @factory

    return @factored

  # checks if all sub deps for this item has finish loading
  _is_subtree_loaded:->
    status = true
    for dep in @deps

      dep = dep.substr 1 if dep[0] is ':'

      if Chunk.chunks[ dep ]?
        dep = Chunk.chunks[ dep ]
        if dep.factored is null and dep.non_amd is false
          return false
      else
        return false

    return status