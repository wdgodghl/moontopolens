///|
/// Greedily shorten a birth-time representative by adding boundaries of
/// available cells one dimension higher. Each accepted XOR preserves the
/// homology class and filtration scale, but does not guarantee a global minimum.
pub fn simplify_representative(
  analysis : Analysis,
  interval_index : Int,
) -> Array[Int] raise TopologyError {
  if !analysis.representatives_computed {
    raise TopologyError("representatives were not computed")
  }
  if interval_index < 0 || interval_index >= analysis.intervals.length() {
    raise TopologyError("representative interval index out of range")
  }
  let interval = analysis.intervals[interval_index]
  if interval.dimension != 1 && interval.dimension != 2 {
    raise TopologyError("representative simplification requires H1 or H2")
  }
  let cells = analysis.filtration.cells
  let mut chain = interval.representative.copy()
  chain.sort_by(fn(a, b) { a - b })
  let mut last = -1
  for index in chain {
    if index <= last ||
      index >= cells.length() ||
      index < 0 ||
      cells[index].dimension != interval.dimension ||
      cells[index].value > interval.birth {
      raise TopologyError("invalid representative for birth filtration")
    }
    last = index
  }
  let mut changed = true
  while changed {
    changed = false
    for cell in cells {
      if cell.dimension == interval.dimension + 1 &&
        cell.value <= interval.birth {
        let candidate = xor_columns(chain, cell.boundary)
        if candidate.length() < chain.length() {
          chain = candidate
          changed = true
        }
      }
    }
  }
  chain
}
