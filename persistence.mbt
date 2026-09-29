///|
/// Symmetric difference of sorted sparse GF(2) vectors (addition modulo two).
fn xor_columns(a : Array[Int], b : Array[Int]) -> Array[Int] {
  let result : Array[Int] = []
  let mut i = 0
  let mut j = 0
  while i < a.length() && j < b.length() {
    if a[i] == b[j] {
      i += 1
      j += 1
    } else if a[i] < b[j] {
      result.push(a[i])
      i += 1
    } else {
      result.push(b[j])
      j += 1
    }
  }
  while i < a.length() {
    result.push(a[i])
    i += 1
  }
  while j < b.length() {
    result.push(b[j])
    j += 1
  }
  result
}

///|
/// Validate a public filtration before reduction, including boundary squared.
/// Protects callers who construct or mutate the exposed data structures.
pub fn validate_filtration(filtration : Filtration) -> Unit raise TopologyError {
  let cells = filtration.cells
  if !finite(filtration.cutoff) ||
    filtration.cutoff.abs() > 1.0e100 ||
    filtration.vertex_count < 0 {
    raise TopologyError("invalid filtration cutoff or vertex count")
  }
  check_budget(cells.length(), 10000)
  let keys : Map[String, Bool] = Map([])
  for i = 0; i < cells.length(); i = i + 1 {
    let cell = cells[i]
    if !finite(cell.value) ||
      cell.value.abs() > 1.0e100 ||
      cell.value > filtration.cutoff ||
      cell.dimension < 0 ||
      cell.dimension > 2 {
      raise TopologyError("invalid cell value or dimension")
    }
    if keys.contains(cell.key) {
      raise TopologyError("duplicate cell key")
    }
    keys.set(cell.key, true)
    if i > 0 && cell.value < cells[i - 1].value {
      raise TopologyError("filtration values must be nondecreasing")
    }
    if cell.dimension == 0 && !cell.boundary.is_empty() {
      raise TopologyError("vertices must have empty boundaries")
    }
    let mut last = -1
    let mut twice : Array[Int] = []
    for face in cell.boundary {
      if face <= last || face >= i || face < 0 {
        raise TopologyError(
          "boundary indices must be sorted, unique and earlier",
        )
      }
      if cells[face].dimension + 1 != cell.dimension {
        raise TopologyError("boundary face has wrong dimension")
      }
      twice = xor_columns(twice, cells[face].boundary)
      last = face
    }
    if !twice.is_empty() {
      raise TopologyError("boundary squared must be zero")
    }
  }
}

///|
/// Standard left-to-right sparse boundary matrix reduction over GF(2).
/// Tracks change-of-basis chains to return representatives at birth.
/// Emits only H0 and H1. Zero-length intervals are omitted by default.
pub fn analyze(
  filtration : Filtration,
  include_zero? : Bool = false,
  max_additions? : Int = 2000000,
) -> Analysis raise TopologyError {
  validate_filtration(filtration)
  if max_additions < 1 || max_additions > 10000000 {
    raise TopologyError("max_additions must be between 1 and 10000000")
  }
  let cells = filtration.cells
  let reduced : Array[Array[Int]] = []
  let chains : Array[Array[Int]] = []
  let owner = Array::make(cells.length(), -1)
  let deaths = Array::make(cells.length(), -1)
  let positive = Array::make(cells.length(), false)
  let mut additions = 0
  let mut stored_entries = 0
  for j = 0; j < cells.length(); j = j + 1 {
    let mut column = cells[j].boundary.copy()
    // Triangle basis chains are not needed for H0/H1 representatives.
    let mut chain = if cells[j].dimension < 2 { [j] } else { [] }
    while !column.is_empty() {
      let low = column[column.length() - 1]
      let k = owner[low]
      if k < 0 {
        break
      }
      additions += 1
      if additions > max_additions {
        raise TopologyError(
          "reduction work budget exceeded; reduce the filtration",
        )
      }
      column = xor_columns(column, reduced[k])
      if cells[j].dimension < 2 {
        chain = xor_columns(chain, chains[k])
      }
    }
    if column.is_empty() {
      positive[j] = true
    } else {
      let low = column[column.length() - 1]
      owner[low] = j
      deaths[low] = j
    }
    stored_entries += column.length() + chain.length()
    if stored_entries > 2000000 {
      raise TopologyError(
        "sparse storage budget exceeded; reduce the filtration",
      )
    }
    reduced.push(column)
    chains.push(chain)
  }
  let intervals : Array[Interval] = []
  for i = 0; i < cells.length(); i = i + 1 {
    if !positive[i] || cells[i].dimension > 1 {
      continue
    }
    let d = deaths[i]
    if d >= 0 && cells[d].value == cells[i].value && !include_zero {
      continue
    }
    intervals.push({
      dimension: cells[i].dimension,
      birth: cells[i].value,
      death: if d < 0 {
        None
      } else {
        Some(cells[d].value)
      },
      birth_cell: i,
      death_cell: if d < 0 {
        None
      } else {
        Some(d)
      },
      representative: chains[i].copy(),
    })
  }
  { filtration, intervals, column_additions: additions, }
}

///|
/// Count classes alive at a scale in the analyzed (possibly truncated) complex.
pub fn betti(
  analysis : Analysis,
  dimension : Int,
  scale : Double,
) -> Int raise TopologyError {
  if dimension < 0 || dimension > 1 || !finite(scale) {
    raise TopologyError("Betti query requires dimension 0/1 and finite scale")
  }
  let mut count = 0
  for interval in analysis.intervals {
    if interval.dimension != dimension || scale < interval.birth {
      continue
    }
    match interval.death {
      None => count += 1
      Some(d) => if scale < d { count += 1 }
    }
  }
  count
}

///|
/// Decode an H1 representative into vertex pairs for plotting.
pub fn cycle_edges(
  analysis : Analysis,
  interval : Interval,
) -> Array[(Int, Int)] raise TopologyError {
  if interval.dimension != 1 {
    raise TopologyError("cycle_edges requires an H1 interval")
  }
  let edges : Array[(Int, Int)] = []
  for i in interval.representative {
    if i < 0 || i >= analysis.filtration.cells.length() {
      raise TopologyError("representative index outside filtration")
    }
    let cell = analysis.filtration.cells[i]
    if cell.dimension != 1 || cell.vertices.length() != 2 {
      raise TopologyError("representative cell is not an edge")
    }
    edges.push((cell.vertices[0], cell.vertices[1]))
  }
  edges
}
