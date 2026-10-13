///|
pub struct PointSample {
  points : Array[Array[Double]]
  source_indices : Array[Int]
  source_count : Int
  covering_radius : Double
} derive(@debug.Debug)

///|
pub extend PointSample with @debug.Debug::{to_repr}

///|
/// Deterministic farthest-point sampling, starting at row zero with index ties.
/// The radius is measured in the supplied coordinates, not an error guarantee.
pub fn sample_points(
  points : Array[Array[Double]],
  size~ : Int,
) -> PointSample raise TopologyError {
  let n = points.length()
  if n < 1 || n > 10000 || size < 1 || size > 128 {
    raise TopologyError(
      "sampling requires 1..10000 points and sample size 1..128",
    )
  }
  let dimension = points[0].length()
  if dimension < 1 ||
    dimension > 32 ||
    n * minimum_int(n, size) * dimension > 40000000 {
    raise TopologyError("sampling dimension or work budget exceeded")
  }
  for row in points {
    if row.length() != dimension {
      raise TopologyError("inconsistent point dimensions")
    }
    for value in row {
      if !finite(value) || value.abs() > 1.0e100 {
        raise TopologyError("sampling coordinates out of range")
      }
    }
  }
  if n <= size {
    return {
      points: points.map(fn(row) { row.copy() }),
      source_indices: Array::makei(n, fn(i) { i }),
      source_count: n,
      covering_radius: 0.0,
    }
  }
  let selected : Array[Int] = []
  let used = Array::make(n, false)
  let nearest = Array::make(n, 1.0e200)
  let mut next = 0
  while selected.length() < size {
    selected.push(next)
    used[next] = true
    for i = 0; i < n; i = i + 1 {
      let mut distance = 0.0
      for c = 0; c < dimension; c = c + 1 {
        distance = @math.hypot(distance, points[i][c] - points[next][c])
      }
      if distance < nearest[i] {
        nearest[i] = distance
      }
    }
    let mut largest = -1.0
    for i = 0; i < n; i = i + 1 {
      if !used[i] && nearest[i] > largest {
        largest = nearest[i]
        next = i
      }
    }
  }
  let mut radius = 0.0
  for value in nearest {
    radius = maximum(radius, value)
  }
  {
    points: selected.map(fn(i) { points[i].copy() }),
    source_indices: selected,
    source_count: n,
    covering_radius: radius,
  }
}

///|
pub fn point_sample_json(sample : PointSample) -> Json {
  {
    "method": "farthest_point",
    "start_index": 0,
    "tie_break": "lowest source index",
    "approximate": sample.points.length() < sample.source_count,
    "source_count": sample.source_count,
    "sample_count": sample.points.length(),
    "source_indices": sample.source_indices,
    "covering_radius": sample.covering_radius,
    "radius_units": "input coordinates",
    "note": "radius is not a measured persistence-diagram error",
  }
}

///|
/// Return a bounded ordinary points request and its approximation metadata.
pub fn sampled_points_request(
  text : String,
  size~ : Int,
) -> (Json, Json) raise TopologyError {
  if text.length() > 1000000 {
    raise TopologyError("points request exceeds one million characters")
  }
  let parsed = @json.parse(text) catch {
    _ => raise TopologyError("invalid points JSON")
  }
  let fields = match parsed {
    Object(fields) => fields
    _ => raise TopologyError("points request must be an object")
  }
  let kind : String = @json.from_json(required_field(fields, "kind")) catch {
    _ => raise TopologyError("missing points kind")
  }
  if kind != "points" {
    raise TopologyError("points-sample accepts points requests only")
  }
  let points : Array[Array[Double]] = @json.from_json(
    required_field(fields, "points"),
  ) catch {
    _ => raise TopologyError("invalid point coordinates")
  }
  let sample = sample_points(points, size~)
  let output = fields.copy()
  output.set("points", sample.points.to_json())
  let request = output.to_json()
  ignore(analyze_json(request.stringify(), representatives=false))
  (request, point_sample_json(sample))
}
