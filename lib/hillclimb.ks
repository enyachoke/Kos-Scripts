{
  local hillclimb is lex(
    "seek", seek@
  ).
  local fitness_lookup is lex().
  function seek {
    parameter d, f_fn, ss is 1.
    local nd is best_neighbor(d, f_fn, ss).
    until f_fn(nd) <= f_fn(d) {
      set d to nd.
      set nd to best_neighbor(d, f_fn, ss).
    }
    return d.
  }
  function best_neighbor {
    parameter d, f_fn, ss.
    local best_fitness is -2^64.
    local best is 0.
    for neighbor in neighbors(d, ss) {
      if fitness_lookup:haskey(neighbor) {
        print "Fit Cache Hit".
        set fitness to fitness_lookup[neighbor].
      } else {
        set fitness to f_fn(neighbor).
        fitness_lookup:add(neighbor, fitness).
      }
      if fitness > best_fitness {
        set best to neighbor.
        set best_fitness to fitness.
    }}
    return best.
  }
  function neighbors {
    parameter d, ss, r is list().
    for i in range(0, d:length) {
      local ic is d:copy.
      local dc is d:copy.
      set ic[i] to ic[i] + ss.
      set dc[i] to dc[i] - ss.
      r:add(ic).
      r:add(dc).
    }
    return r.
  }
  export(hillclimb).
}
