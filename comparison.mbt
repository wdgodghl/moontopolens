///|
/// Indices refer to the original analysis interval arrays, not diagram rows.
/// A missing side in a finite match denotes the diagonal, not a deleted object.
pub struct IntervalMatch {
  left : Int?
  right : Int?
  cost : Double?
  kind : String
} derive(@debug.Debug)

///|
pub extend IntervalMatch with @debug.Debug::{to_repr}

///|
fn indexed_intervals(
  analysis : Analysis,
  dimension : Int,
  censored : Bool,
) -> Array[Int] {
  let indices : Array[Int] = []
  for i = 0; i < analysis.intervals.length(); i = i + 1 {
    let interval = analysis.intervals[i]
    if interval.dimension == dimension && (interval.death is None) == censored {
      indices.push(i)
    }
  }
  indices
}

///|
/// One optimal finite-diagram matching, plus sorted-birth censored matching.
/// If censored counts differ, all censored rows are marked unmatched with null cost.
pub fn interval_matching(
  a : Analysis,
  b : Analysis,
  dimension~ : Int,
) -> Array[IntervalMatch] raise TopologyError {
  let da = diagram(a, dimension)
  let db = diagram(b, dimension)
  let distance = bottleneck(da, db)
  let (costs, _) = diagram_costs(da, db)
  let owners = match matching_owners(costs, distance) {
    Some(owners) => owners
    None => raise TopologyError("could not reconstruct bottleneck matching")
  }
  let ia = indexed_intervals(a, dimension, false)
  let ib = indexed_intervals(b, dimension, false)
  let result : Array[IntervalMatch] = []
  for j = 0; j < owners.length(); j = j + 1 {
    let i = owners[j]
    if i >= ia.length() && j >= ib.length() {
      continue
    }
    let left = if i < ia.length() { Some(ia[i]) } else { None }
    let right = if j < ib.length() { Some(ib[j]) } else { None }
    result.push({
      left,
      right,
      cost: Some(costs[i][j]),
      kind: if left is None || right is None {
        "diagonal"
      } else {
        "finite"
      },
    })
  }
  let ea = indexed_intervals(a, dimension, true)
  let eb = indexed_intervals(b, dimension, true)
  if ea.length() != eb.length() {
    for i in ea {
      result.push({
        left: Some(i),
        right: None,
        cost: None,
        kind: "unmatched_censored",
      })
    }
    for j in eb {
      result.push({
        left: None,
        right: Some(j),
        cost: None,
        kind: "unmatched_censored",
      })
    }
  } else {
    ea.sort_by(fn(i, j) {
      let bi = a.intervals[i].birth
      let bj = a.intervals[j].birth
      if bi < bj {
        -1
      } else if bi > bj {
        1
      } else {
        i - j
      }
    })
    eb.sort_by(fn(i, j) {
      let bi = b.intervals[i].birth
      let bj = b.intervals[j].birth
      if bi < bj {
        -1
      } else if bi > bj {
        1
      } else {
        i - j
      }
    })
    for i = 0; i < ea.length(); i = i + 1 {
      result.push({
        left: Some(ea[i]),
        right: Some(eb[i]),
        cost: Some((a.intervals[ea[i]].birth - b.intervals[eb[i]].birth).abs()),
        kind: "censored",
      })
    }
  }
  result
}

///|
fn optional_number(value : Double?) -> Json {
  match value {
    Some(value) => value.to_json()
    None => Json::null()
  }
}

///|
fn matching_interval_json(analysis : Analysis, index : Int?) -> Json {
  match index {
    None => Json::null()
    Some(index) => {
      let interval = analysis.intervals[index]
      {
        "index": index,
        "birth": interval.birth,
        "death": optional_number(interval.death),
      }
    }
  }
}

///|
/// Existing comparison metadata plus a witness explaining every interval.
pub fn comparison_json(a : Analysis, b : Analysis) -> Json raise TopologyError {
  let distances : Array[Json] = []
  for dimension = 0; dimension < 2; dimension = dimension + 1 {
    let matches : Array[Json] = []
    for pair in interval_matching(a, b, dimension~) {
      matches.push({
        "left": matching_interval_json(a, pair.left),
        "right": matching_interval_json(b, pair.right),
        "cost": optional_number(pair.cost),
        "kind": pair.kind,
      })
    }
    let distance = compare_analyses(a, b, dimension~)
    distances.push({
      "dimension": dimension,
      "bottleneck": optional_number(distance),
      "finite_distance": distance is Some(_),
      "matches": matches,
    })
  }
  {
    "schema_version": 1,
    "metric": "bottleneck",
    "distances": distances,
    "left_cutoff": a.filtration.cutoff,
    "right_cutoff": b.filtration.cutoff,
    "cutoffs_equal": a.filtration.cutoff == b.filtration.cutoff,
    "complex_kinds_equal": a.filtration.kind == b.filtration.kind,
    "left_summary": summary_json(a),
    "right_summary": summary_json(b),
    "note": "one optimal matching, not unique; diagonal matches do not prove physical creation or deletion; censored counts differing imply null distance; use comparable cutoffs and units",
  }
}

///|
pub fn matching_csv(a : Analysis, b : Analysis) -> String raise TopologyError {
  let mut text = "dimension,left_interval,right_interval,kind,cost\n"
  for dimension = 0; dimension < 2; dimension = dimension + 1 {
    for pair in interval_matching(a, b, dimension~) {
      let left = match pair.left {
        Some(i) => i.to_string()
        None => ""
      }
      let right = match pair.right {
        Some(i) => i.to_string()
        None => ""
      }
      let cost = match pair.cost {
        Some(c) => c.to_string()
        None => ""
      }
      text += "\{dimension},\{left},\{right},\{pair.kind},\{cost}\n"
    }
  }
  text
}
