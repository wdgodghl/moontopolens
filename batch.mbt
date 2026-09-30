///|
pub struct BatchCase {
  name : String
  input : String
  format : String
  threshold : Double?
  auto_threshold : Bool
  invert : Bool
} derive(@debug.Debug)

///|
pub extend BatchCase with @debug.Debug::{to_repr}

///|
pub struct BatchPair {
  name : String
  left : String
  right : String
} derive(@debug.Debug)

///|
pub extend BatchPair with @debug.Debug::{to_repr}

///|
pub struct BatchPlan {
  cases : Array[BatchCase]
  comparisons : Array[BatchPair]
} derive(@debug.Debug)

///|
pub extend BatchPlan with @debug.Debug::{to_repr}

///|
fn batch_string(
  fields : Map[String, Json],
  field : String,
) -> String raise TopologyError {
  @json.from_json(required_field(fields, field)) catch {
    _ => raise TopologyError("batch field " + field + " must be a string")
  }
}

///|
fn batch_name(value : String) -> Unit raise TopologyError {
  if value == "" || value.length() > 32 {
    raise TopologyError(
      "batch names must contain 1..32 ASCII letters, digits, - or _",
    )
  }
  for c in value {
    let code = c.to_int()
    if !((code >= 48 && code <= 57) ||
      (code >= 65 && code <= 90) ||
      (code >= 97 && code <= 122) ||
      code == 45 ||
      code == 95) {
      raise TopologyError(
        "batch names must contain 1..32 ASCII letters, digits, - or _",
      )
    }
  }
}

///|
fn batch_object(
  value : Json,
  label : String,
) -> Map[String, Json] raise TopologyError {
  match value {
    Object(fields) => fields
    _ => raise TopologyError(label + " must be an object")
  }
}

///|
fn batch_array(
  fields : Map[String, Json],
  field : String,
  required : Bool,
) -> Array[Json] raise TopologyError {
  match fields.get(field) {
    Some(Array(items)) => items
    Some(_) => raise TopologyError(field + " must be an array")
    None =>
      if required {
        raise TopologyError("missing field: " + field)
      } else {
        []
      }
  }
}

///|
fn batch_fields(
  fields : Map[String, Json],
  allowed : Array[String],
  label : String,
) -> Unit raise TopologyError {
  for key in fields.keys() {
    if !allowed.contains(key) {
      raise TopologyError("unknown " + label + " field: " + key)
    }
  }
}

///|
/// Bounded manifest for up to eight local inputs and twelve comparisons.
/// File paths are resolved and confined by the CLI host adapter.
pub fn parse_batch_manifest(text : String) -> BatchPlan raise TopologyError {
  if text.length() > 1000000 {
    raise TopologyError("batch manifest exceeds one million characters")
  }
  let parsed = @json.parse(text) catch {
    _ => raise TopologyError("invalid batch manifest JSON")
  }
  let root = batch_object(parsed, "batch manifest")
  batch_fields(root, ["cases", "comparisons"], "manifest")
  let case_values = batch_array(root, "cases", true)
  let pair_values = batch_array(root, "comparisons", false)
  if case_values.length() < 1 ||
    case_values.length() > 8 ||
    pair_values.length() > 12 {
    raise TopologyError("batch requires 1..8 cases and at most 12 comparisons")
  }
  let seen_cases : Map[String, Bool] = Map([])
  let cases : Array[BatchCase] = []
  for value in case_values {
    let fields = batch_object(value, "case")
    batch_fields(
      fields,
      ["name", "input", "format", "threshold", "invert"],
      "case",
    )
    let name = batch_string(fields, "name")
    batch_name(name)
    if seen_cases.contains(name) {
      raise TopologyError("duplicate case name: " + name)
    }
    seen_cases[name] = true
    let input = batch_string(fields, "input")
    if input == "" || input.length() > 256 {
      raise TopologyError("batch input path must contain 1..256 characters")
    }
    let format = match fields.get("format") {
      None => "json"
      Some(_) => batch_string(fields, "format")
    }
    if format != "json" && format != "pgm" {
      raise TopologyError("batch format must be json or pgm")
    }
    let auto_threshold = match fields.get("threshold") {
      Some(String("auto")) => true
      _ => false
    }
    let threshold = match fields.get("threshold") {
      Some(Number(n, ..)) => Some(n)
      Some(String("auto")) => None
      Some(_) => raise TopologyError("batch threshold must be numeric or auto")
      None => None
    }
    if (format == "pgm" && threshold is None && !auto_threshold) ||
      (format == "json" && fields.contains("threshold")) {
      raise TopologyError(
        "threshold is required for pgm and forbidden for json cases",
      )
    }
    let invert = match fields.get("invert") {
      Some(value) => {
        let parsed : Bool = @json.from_json(value) catch {
          _ => raise TopologyError("batch invert must be boolean")
        }
        parsed
      }
      None => false
    }
    if format == "json" && fields.contains("invert") {
      raise TopologyError("invert is only supported for pgm cases")
    }
    if threshold is Some(n) {
      if !finite(n) || n.abs() > 1.0e100 {
        raise TopologyError("PGM threshold must be bounded and finite")
      }
    }
    cases.push({ name, input, format, threshold, auto_threshold, invert, })
  }
  let seen_pairs : Map[String, Bool] = Map([])
  let comparisons : Array[BatchPair] = []
  for value in pair_values {
    let fields = batch_object(value, "comparison")
    batch_fields(fields, ["name", "left", "right"], "comparison")
    let name = batch_string(fields, "name")
    batch_name(name)
    if seen_pairs.contains(name) {
      raise TopologyError("duplicate comparison name: " + name)
    }
    seen_pairs[name] = true
    let left = batch_string(fields, "left")
    let right = batch_string(fields, "right")
    if !seen_cases.contains(left) || !seen_cases.contains(right) {
      raise TopologyError("comparison references an unknown case: " + name)
    }
    comparisons.push({ name, left, right, })
  }
  { cases, comparisons, }
}
