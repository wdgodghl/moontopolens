///|
fn required_field(
  object : Map[String, Json],
  name : String,
) -> Json raise TopologyError {
  match object.get(name) {
    Some(value) => value
    None => raise TopologyError("missing field: " + name)
  }
}

///|
fn number_field(
  object : Map[String, Json],
  name : String,
) -> Double raise TopologyError {
  @json.from_json(required_field(object, name)) catch {
    _ => raise TopologyError(name + " must be a number")
  }
}

///|
fn integer_field(
  object : Map[String, Json],
  name : String,
  fallback : Int,
) -> Int raise TopologyError {
  match object.get(name) {
    None => fallback
    Some(Number(n, ..)) => {
      if !finite(n) ||
        n != @math.floor(n) ||
        n < -2147483648.0 ||
        n > 2147483647.0 {
        raise TopologyError(name + " must be a 32-bit integer")
      }
      n.to_int()
    }
    Some(_) => raise TopologyError(name + " must be an integer")
  }
}

///|
fn rows_field(
  object : Map[String, Json],
  name : String,
) -> Array[Array[Double]] raise TopologyError {
  @json.from_json(required_field(object, name)) catch {
    _ => raise TopologyError(name + " must be an array of number arrays")
  }
}

///|
/// Parse a bounded JSON request, construct a filtration, then analyze it.
/// Supported kinds: points, matrix, grid, series. Unknown fields are errors.
pub fn analyze_json(text : String) -> Analysis raise TopologyError {
  if text.length() > 1000000 {
    raise TopologyError("JSON request exceeds one million characters")
  }
  let value = @json.parse(text) catch {
    _ => raise TopologyError("invalid JSON request")
  }
  let object = match value {
    Object(fields) => fields
    _ => raise TopologyError("request must be a JSON object")
  }
  let kind : String = @json.from_json(required_field(object, "kind")) catch {
    _ => raise TopologyError("kind must be a string")
  }
  let threshold = number_field(object, "threshold")
  let budget = integer_field(object, "max_cells", 4000)
  let allowed = match kind {
    "points" => ["kind", "threshold", "max_cells", "points"]
    "matrix" => ["kind", "threshold", "max_cells", "matrix"]
    "grid" => ["kind", "threshold", "max_cells", "grid"]
    "series" =>
      ["kind", "threshold", "max_cells", "series", "dimension", "lag", "stride"]
    _ =>
      raise TopologyError(
        "unknown kind; expected points, matrix, grid or series",
      )
  }
  for field in object.keys() {
    if !allowed.contains(field) {
      raise TopologyError("unknown field for " + kind + ": " + field)
    }
  }
  let filtration = match kind {
    "points" => rips(rows_field(object, "points"), threshold~, max_cells=budget)
    "matrix" =>
      rips_matrix(rows_field(object, "matrix"), threshold~, max_cells=budget)
    "grid" =>
      cubical_grid(rows_field(object, "grid"), threshold~, max_cells=budget)
    "series" => {
      let series : Array[Double] = @json.from_json(
        required_field(object, "series"),
      ) catch {
        _ => raise TopologyError("series must be an array of numbers")
      }
      let points = delay_embed(
        series,
        dimension=integer_field(object, "dimension", 2),
        lag=integer_field(object, "lag", 1),
        stride=integer_field(object, "stride", 1),
      )
      rips(points, threshold~, max_cells=budget)
    }
    _ => raise TopologyError("unreachable kind")
  }
  analyze(filtration)
}

///|
/// Portable report schema. null death means alive at the input cutoff.
/// Representative cell indices refer to the accompanying cells array.
pub fn report_json(analysis : Analysis) -> Json {
  let intervals : Array[Json] = []
  for interval in analysis.intervals {
    let death : Json = match interval.death {
      None => Json::null()
      Some(value) => value.to_json()
    }
    let death_cell : Json = match interval.death_cell {
      None => Json::null()
      Some(value) => value.to_json()
    }
    intervals.push({
      "dimension": interval.dimension,
      "birth": interval.birth,
      "death": death,
      "birth_cell": interval.birth_cell,
      "death_cell": death_cell,
      "representative": interval.representative,
    })
  }
  let cells : Array[Json] = []
  for cell in analysis.filtration.cells {
    cells.push({
      "key": cell.key,
      "dimension": cell.dimension,
      "value": cell.value,
      "boundary": cell.boundary,
      "vertices": cell.vertices,
    })
  }
  {
    "schema_version": 1,
    "project": "MoonTopoLens",
    "coefficients": "GF(2)",
    "kind": analysis.filtration.kind,
    "cutoff": analysis.filtration.cutoff,
    "vertex_count": analysis.filtration.vertex_count,
    "cell_count": cells.length(),
    "column_additions": analysis.column_additions,
    "positions": analysis.filtration.positions,
    "position_meaning": "display projection: first two point coordinates; grid x and negative row; matrix has none",
    "summary": summary_json(analysis),
    "betti_events": betti_events_json(analysis),
    "essential_meaning": "alive at input cutoff; not proof of infinite lifetime",
    "representative_meaning": "cycle at birth; not guaranteed shortest",
    "intervals": intervals,
    "cells": cells,
  }
}
