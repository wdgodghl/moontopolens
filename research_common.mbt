///|
fn research_object(
  text : String,
  kind : String,
  allowed : Array[String],
) -> Map[String, Json] raise TopologyError {
  if text.length() > 1000000 {
    raise TopologyError("research request exceeds 1 MB")
  }
  let parsed = @json.parse(text) catch {
    _ => raise TopologyError("invalid research JSON")
  }
  let fields = batch_object(parsed, "research request")
  if batch_string(fields, "kind") != kind {
    raise TopologyError("expected research kind " + kind)
  }
  for key in fields.keys() {
    if key != "kind" && !allowed.contains(key) {
      raise TopologyError("unknown research field: " + key)
    }
  }
  fields
}

///|
fn research_number(
  fields : Map[String, Json],
  name : String,
  fallback : Double,
) -> Double raise TopologyError {
  let v = match fields.get(name) {
    Some(_) => number_field(fields, name)
    None => fallback
  }
  if !finite(v) || v.abs() > 1.0e100 {
    raise TopologyError("invalid research number " + name)
  }
  v
}

///|
fn research_string(
  fields : Map[String, Json],
  name : String,
  fallback : String,
) -> String raise TopologyError {
  match fields.get(name) {
    Some(_) => batch_string(fields, name)
    None => fallback
  }
}

///|
fn research_numbers(
  fields : Map[String, Json],
  name : String,
  fallback : Array[Double],
) -> Array[Double] raise TopologyError {
  let values : Array[Double] = match fields.get(name) {
    None => fallback
    Some(v) =>
      @json.from_json(v) catch {
        _ => raise TopologyError("expected number array " + name)
      }
  }
  for v in values {
    if !finite(v) || v.abs() > 1.0e100 {
      raise TopologyError("invalid number in " + name)
    }
  }
  values
}

///|
fn research_next(state : Ref[Int], n : Int) -> Int {
  state.val = (state.val * 25173 + 13849) % 65536
  (state.val.to_double() * n.to_double() / 65536.0).to_int()
}

///|
fn research_quantile(values : Array[Double], q : Double) -> Double {
  let sorted = values.copy()
  sorted.sort()
  let pos = q * (sorted.length() - 1).to_double()
  let low = @math.floor(pos).to_int()
  let high = minimum_int(low + 1, sorted.length() - 1)
  sorted[low] + (sorted[high] - sorted[low]) * (pos - low.to_double())
}

///|
fn research_vector(
  a : Analysis,
  dimension : Int,
  start : Double,
  end : Double,
  samples : Int,
) -> Array[Double] raise TopologyError {
  persistence_landscape(a, dimension~, start~, end~, samples~, layers=1)[0]
}

///|
fn research_l2(a : Array[Double], b : Array[Double]) -> Double {
  let mut norm = 0.0
  for i = 0; i < a.length(); i = i + 1 {
    norm = @math.hypot(norm, a[i] - b[i])
  }
  norm / a.length().to_double().sqrt()
}

///|
fn research_request(value : Json) -> Analysis raise TopologyError {
  let a = analyze_json(value.stringify())
  if a.filtration.cells.length() > 10000 {
    raise TopologyError("research case cell budget exceeded")
  }
  a
}

///|
fn research_csv_rows(
  header : Array[String],
  rows : Array[Array[Json]],
) -> String {
  let mut text = header.join(",") + "\n"
  for row in rows {
    let cells = row.map(fn(value) {
      match value {
        Null => ""
        String(s) => "\"" + s.replace_all(old="\"", new="\"\"") + "\""
        _ => value.stringify()
      }
    })
    text += cells.join(",") + "\n"
  }
  text
}
