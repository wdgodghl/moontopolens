///|
/// Convert a timestamp/value CSV into a signal study, preserving blank values.
pub fn signal_csv_request(
  csv : String,
  config : String,
) -> Json raise TopologyError {
  let parsed = @json.parse(config) catch {
    _ => raise TopologyError("invalid signal config")
  }
  let f = batch_object(parsed, "signal config").copy()
  if f.contains("values") || f.contains("times") {
    raise TopologyError("CSV config must not also supply times or values")
  }
  let time_name = research_string(f, "time_column", "time")
  let value_name = research_string(f, "value_column", "value")
  let source_rows : Array[Array[String]] = []
  let source_lines : Array[Int32] = []
  let headers : Array[String] = []
  let times : Array[Double] = []
  let values : Array[Json] = []
  let mut ti = -1
  let mut vi = -1
  if csv.length() > 1000000 {
    raise TopologyError("signal CSV exceeds 1 MB")
  }
  for line_index, raw in csv.split("\n").to_array() {
    let line = if line_index == 0 {
      raw.to_owned().trim_start(chars="\uFEFF").to_owned()
    } else {
      raw.to_owned()
    }
    if line.trim().to_owned() == "" {
      continue
    }
    let fields = csv_fields(line, line_index + 1)
    if headers.is_empty() {
      for i, name in fields {
        if name == "" || headers.contains(name) {
          raise TopologyError("signal CSV requires unique nonempty headers")
        }
        headers.push(name)
        if name == time_name {
          ti = i
        }
        if name == value_name {
          vi = i
        }
      }
      if ti < 0 || vi < 0 || ti == vi {
        raise TopologyError("signal CSV needs distinct time and value columns")
      }
      continue
    }
    if fields.length() != headers.length() || times.length() >= 8192 {
      raise TopologyError("signal CSV shape or row limit exceeded")
    }
    let t : Double = @json.from_json(@json.parse(fields[ti])) catch {
      _ => raise TopologyError("invalid timestamp")
    }
    source_rows.push(fields)
    source_lines.push(line_index + 1)
    times.push(t)
    if fields[vi] == "" {
      values.push(Json::null())
    } else {
      let v : Double = @json.from_json(@json.parse(fields[vi])) catch {
        _ => raise TopologyError("invalid signal value")
      }
      values.push(v.to_json())
    }
  }
  f.set(
    "csv_source",
    (
      { "headers": headers, "rows": source_rows, "line_numbers": source_lines } :
      Json),
  )
  f.set("times", times.to_json())
  f.set("values", values.to_json())
  f.to_json()
}

///|
fn signal_baselines(
  values : Array[Double],
  step : Double,
) -> (Double, Double, Double, Double, Double) {
  let n = values.length()
  let mut mean = 0.0
  for v in values {
    mean += v / n.to_double()
  }
  let mut rms = 0.0
  for v in values {
    rms = @math.hypot(rms, (v - mean) / n.to_double().sqrt())
  }
  let mut ac = 0.0
  for lag = 2; lag <= n / 2; lag = lag + 1 {
    let mut xy = 0.0
    let mut xx = 0.0
    let mut yy = 0.0
    for i = 0; i < n - lag; i = i + 1 {
      let x = values[i] - mean
      let y = values[i + lag] - mean
      xy += x * y
      xx += x * x
      yy += y * y
    }
    if xx > 0.0 && yy > 0.0 {
      ac = maximum(ac, (xy / xx.sqrt() / yy.sqrt()).abs())
    }
  }
  let mut power = 0.0
  let mut peak = 0.0
  let mut frequency = 0.0
  for k = 1; k <= n / 2; k = k + 1 {
    let mut re = 0.0
    let mut im = 0.0
    for i = 0; i < n; i = i + 1 {
      let phase = 2.0 *
        3.141592653589793 *
        k.to_double() *
        i.to_double() /
        n.to_double()
      let v = values[i] - mean
      re += v * @math.cos(phase)
      im += v * @math.sin(phase)
    }
    let p = re * re + im * im
    power += p
    if p > peak {
      peak = p
      frequency = k.to_double() / n.to_double() / step
    }
  }
  (mean, rms, ac, if power == 0.0 { 0.0 } else { peak / power }, frequency)
}

///|
/// Windowed topology with training-only calibration and explicit interpolation.
pub fn signal_study(text : String) -> Json raise TopologyError {
  let f = research_object(text, "signal_study", [
    "times", "values", "time_column", "value_column", "unit", "interpolation", "grid_step",
    "max_gap", "window", "hop", "baseline_windows", "dimension", "lag", "threshold",
    "max_cells", "normalization", "detrend", "threshold_factor", "events", "csv_source",
  ])
  let raw_values : Array[Json] = @json.from_json(required_field(f, "values")) catch {
    _ => raise TopologyError("values must be an array")
  }
  let values : Array[Double?] = raw_values.map(fn(v) raise TopologyError {
    match v {
      Null => None
      Number(x, ..) => Some(x)
      _ => raise TopologyError("values must be numeric or null")
    }
  })
  let times = research_numbers(
    f,
    "times",
    Array::makei(values.length(), fn(i) { i.to_double() }),
  )
  if values.length() < 8 ||
    values.length() > 8192 ||
    times.length() != values.length() {
    raise TopologyError("signal requires 8..8192 matched timestamps and values")
  }
  let observed : Array[Int32] = []
  for i, t in times {
    if t.abs() > 1.0e12 || (i > 0 && t <= times[i - 1]) {
      raise TopologyError("timestamps must be strictly increasing and bounded")
    }
    match values[i] {
      Some(v) => {
        if !finite(v) || v.abs() > 1.0e50 {
          raise TopologyError("signal value out of range")
        }
        observed.push(i)
      }
      None => ()
    }
  }
  if observed.length() < 2 {
    raise TopologyError("not enough observed signal samples")
  }
  let step = research_number(f, "grid_step", times[1] - times[0])
  let policy = research_string(f, "interpolation", "reject")
  let max_gap = research_number(f, "max_gap", 3.0 * step)
  if step < 1.0e-9 ||
    step > 1.0e12 ||
    max_gap <= 0.0 ||
    (policy != "reject" && policy != "linear") {
    raise TopologyError("invalid signal grid or interpolation policy")
  }
  if policy == "reject" {
    for i, t in times {
      if values[i] is None ||
        (i > 0 && (t - times[i - 1] - step).abs() > 1.0e-8 * maximum(1.0, step)) {
        raise TopologyError(
          "missing or irregular samples require explicit linear interpolation",
        )
      }
    }
  }
  let count_number = @math.floor(
      (times[times.length() - 1] - times[0]) / step + 1.0e-8,
    ) +
    1.0
  if count_number < 8.0 || count_number > 8192.0 {
    raise TopologyError("resampled grid must have 8..8192 positions")
  }
  let grid = if policy == "reject" {
    times.copy()
  } else {
    Array::makei(count_number.to_int(), fn(i) {
      times[0] + i.to_double() * step
    })
  }
  for i = 1; i < grid.length(); i = i + 1 {
    if grid[i] <= grid[i - 1] {
      raise TopologyError("grid step is below timestamp precision")
    }
  }
  let regular : Array[Double?] = []
  let provenance : Array[Json] = []
  let mut cursor = 0
  for t in grid {
    while cursor + 1 < observed.length() && times[observed[cursor + 1]] <= t {
      cursor += 1
    }
    let left = observed[cursor]
    if (times[left] - t).abs() <= 1.0e-8 * maximum(1.0, step) {
      regular.push(values[left])
      provenance.push({ "left": left, "right": left, "weight_right": 0.0 })
    } else if cursor + 1 < observed.length() &&
      t > times[left] &&
      times[observed[cursor + 1]] - times[left] <= max_gap {
      let right = observed[cursor + 1]
      let weight = (t - times[left]) / (times[right] - times[left])
      let v = values[left].unwrap() +
        weight * (values[right].unwrap() - values[left].unwrap())
      regular.push(Some(v))
      provenance.push({ "left": left, "right": right, "weight_right": weight })
    } else {
      regular.push(None)
      provenance.push(Json::null())
    }
  }
  let window = integer_field(f, "window", 32)
  let hop = integer_field(f, "hop", window / 2)
  let baseline_count = integer_field(f, "baseline_windows", 3)
  let dimension = integer_field(f, "dimension", 2)
  let lag = integer_field(f, "lag", 1)
  let budget = integer_field(f, "max_cells", 4000)
  let cutoff = number_field(f, "threshold")
  let factor = research_number(f, "threshold_factor", 1.5)
  if window < 8 ||
    window > 128 ||
    window > regular.length() ||
    hop < 1 ||
    hop > window ||
    baseline_count < 2 ||
    baseline_count > 16 ||
    factor < 1.0 ||
    factor > 100.0 ||
    cutoff <= 0.0 ||
    !finite(cutoff) {
    raise TopologyError("invalid window, calibration or cutoff")
  }
  let windows = (regular.length() - window) / hop + 1
  if windows > 64 || baseline_count >= windows {
    raise TopologyError(
      "signal study requires <=64 windows and monitoring data after baseline",
    )
  }
  let normalization = research_string(f, "normalization", "none")
  let detrend = research_string(f, "detrend", "none")
  if !["none", "baseline_zscore"].contains(normalization) ||
    !["none", "linear"].contains(detrend) {
    raise TopologyError("invalid normalization or detrending")
  }
  let fit_end = (baseline_count - 1) * hop + window
  let mut offset = 0.0
  let mut scale = 1.0
  for i = 0; i < fit_end; i = i + 1 {
    if regular[i] is None {
      raise TopologyError("baseline windows must not contain unresolved gaps")
    }
  }
  for i = 0; i < fit_end; i = i + 1 {
    let pf = batch_object(provenance[i], "baseline provenance")
    if times[integer_field(pf, "right", i)] > grid[fit_end - 1] {
      raise TopologyError(
        "baseline interpolation must not use observations after the baseline period",
      )
    }
  }
  if normalization == "baseline_zscore" {
    for i = 0; i < fit_end; i = i + 1 {
      offset += regular[i].unwrap() / fit_end.to_double()
    }
    scale = 0.0
    for i = 0; i < fit_end; i = i + 1 {
      scale = @math.hypot(
        scale,
        (regular[i].unwrap() - offset) / fit_end.to_double().sqrt(),
      )
    }
    if Array::makei(fit_end, fn(i) { regular[i] == regular[0] }).all(fn(v) { v }) {
      offset = regular[0].unwrap()
      scale = 1.0
    } else if scale == 0.0 {
      scale = 1.0
    }
  }
  let vectors : Array[Array[Double]] = []
  let comparators : Array[Array[Double]] = []
  let details : Array[Json] = []
  let indices : Array[Int32] = []
  let mut total = 0
  let invalid : Array[Json] = []
  for w = 0; w < windows; w = w + 1 {
    let begin = w * hop
    if Array::makei(window, fn(i) { regular[begin + i] is None }).contains(true) {
      invalid.push({
        "window_index": w,
        "start": grid[begin],
        "end": grid[begin + window - 1],
        "reason": "unresolved gap",
      })
      continue
    }
    let raw = Array::makei(window, fn(i) { regular[begin + i].unwrap() })
    let (mean, rms, ac, spectral, frequency) = signal_baselines(raw, step)
    let processed = raw.map(fn(v) { (v - offset) / scale })
    let mut intercept = 0.0
    let mut slope = 0.0
    if detrend == "linear" {
      for v in processed {
        intercept += v / window.to_double()
      }
      let center = (window - 1).to_double() / 2.0
      let mut xx = 0.0
      let mut xy = 0.0
      for i = 0; i < window; i = i + 1 {
        let x = i.to_double() - center
        xx += x * x
        xy += x * (processed[i] - intercept)
      }
      slope = xy / xx
      for i = 0; i < window; i = i + 1 {
        processed[i] -= intercept + slope * (i.to_double() - center)
      }
    }
    let embedded = delay_embed(processed, dimension~, lag~)
    if embedded.length() < 3 {
      raise TopologyError("signal embedding must yield >=3 points")
    }
    let a = analyze(rips(embedded, threshold=cutoff, max_cells=budget))
    total += a.filtration.cells.length()
    if total > 64000 {
      raise TopologyError("signal windows exceed 64000 cells")
    }
    let vector = research_vector(a, 1, 0.0, cutoff, 31).map(fn(v) { v / cutoff })
    let mut longest = 0.0
    let mut chosen = -1
    for i, interval in a.intervals {
      if interval.dimension == 1 && observed_lifetime(a, interval) > longest {
        longest = observed_lifetime(a, interval)
        chosen = i
      }
    }
    let alive = a.intervals
      .filter(fn(i) { i.dimension == 1 && i.death is None })
      .length()
    vector.push(longest / cutoff)
    vector.push(alive.to_double() / embedded.length().to_double())
    vectors.push(vector)
    comparators.push([mean, rms, ac, spectral])
    indices.push(w)
    let edges = if chosen < 0 {
      []
    } else {
      cycle_edges(a, a.intervals[chosen])
    }
    details.push({
      "window_index": w,
      "start": grid[begin],
      "end": grid[begin + window - 1],
      "mean": mean,
      "rms": rms,
      "autocorrelation_peak": ac,
      "spectral_peak_fraction": spectral,
      "spectral_peak_frequency": frequency,
      "observed_loop_score": longest / cutoff,
      "censored_h1": alive,
      "embedding_points": embedded,
      "representative_edges": edges,
      "grid_indices": Array::makei(window, fn(i) { begin + i }),
      "embedding_source_grid_indices": Array::makei(embedded.length(), fn(i) {
        Array::makei(dimension, fn(c) { begin + i + c * lag })
      }),
      "detrend_intercept": intercept,
      "detrend_slope_per_sample": slope,
      "request": (
        {
          "kind": "series",
          "threshold": cutoff,
          "series": processed,
          "dimension": dimension,
          "lag": lag,
          "stride": 1,
          "max_cells": budget,
        } : Json),
    })
  }
  let center = Array::make(33, 0.0)
  let simple = Array::make(4, 0.0)
  for i = 0; i < baseline_count; i = i + 1 {
    for j = 0; j < 33; j = j + 1 {
      center[j] += vectors[i][j] / baseline_count.to_double()
    }
    for j = 0; j < 4; j = j + 1 {
      simple[j] += comparators[i][j] / baseline_count.to_double()
    }
  }
  let limits = Array::make(4, 1.0e-9)
  for i = 0; i < baseline_count; i = i + 1 {
    let loo = baseline_count.to_double() / (baseline_count - 1).to_double()
    limits[0] = maximum(
      limits[0],
      research_l2(vectors[i], center) * loo * factor,
    )
    limits[1] = maximum(
      limits[1],
      research_l2(comparators[i][:2].to_owned(), simple[:2].to_owned()) *
      loo *
      factor,
    )
    limits[2] = maximum(
      limits[2],
      (comparators[i][2] - simple[2]).abs() * loo * factor,
    )
    limits[3] = maximum(
      limits[3],
      (comparators[i][3] - simple[3]).abs() * loo * factor,
    )
  }
  let event_values : Array[Array[Double]] = match f.get("events") {
    None => []
    Some(v) =>
      @json.from_json(v) catch {
        _ => raise TopologyError("invalid annotated events")
      }
  }
  let mut event_end = -1.0e100
  for e in event_values {
    if e.length() != 2 ||
      !finite(e[0]) ||
      !finite(e[1]) ||
      e[0] >= e[1] ||
      e[0] < event_end {
      raise TopologyError(
        "events must be sorted nonoverlapping [start,end] pairs",
      )
    }
    event_end = e[1]
  }
  let counts = Array::makei(4, fn(_) { [0, 0, 0] })
  let rows : Array[Json] = []
  let segments : Array[Json] = []
  let mut segment_start : Double? = None
  let mut segment_end = 0.0
  for i, detail in details {
    let df = batch_object(detail, "window").copy()
    let scores = [
      research_l2(vectors[i], center),
      research_l2(comparators[i][:2].to_owned(), simple[:2].to_owned()),
      (comparators[i][2] - simple[2]).abs(),
      (comparators[i][3] - simple[3]).abs(),
    ]
    let monitoring = indices[i] >= baseline_count
    let anomalous = monitoring && scores[0] > limits[0]
    let begin = number_field(df, "start")
    let end = number_field(df, "end")
    let mut overlap = 0.0
    for e in event_values {
      let left = maximum(begin, e[0])
      let right = if end < e[1] { end } else { e[1] }
      overlap += maximum(0.0, right - left)
    }
    let actual = overlap >= (end - begin) / 2.0
    if monitoring && f.contains("events") {
      for m = 0; m < 4; m = m + 1 {
        let detected = scores[m] > limits[m]
        if detected && actual {
          counts[m][0] += 1
        } else if detected {
          counts[m][1] += 1
        } else if actual {
          counts[m][2] += 1
        }
      }
    }
    df.set("scores", scores.to_json())
    df.set("monitoring", monitoring.to_json())
    df.set("anomaly", anomalous.to_json())
    rows.push(df.to_json())
    if anomalous {
      if segment_start is Some(_) && begin <= segment_end + step {
        segment_end = end
      } else {
        if segment_start is Some(s) {
          segments.push({ "start": s, "end": segment_end })
        }
        segment_start = Some(begin)
        segment_end = end
      }
    } else if segment_start is Some(s) {
      segments.push({ "start": s, "end": segment_end })
      segment_start = None
    }
  }
  if segment_start is Some(s) {
    segments.push({ "start": s, "end": segment_end })
  }
  let evaluation : Array[Json] = []
  for i, name in ["topology", "mean_rms", "autocorrelation", "spectral_peak"] {
    let c = counts[i]
    evaluation.push({
      "method": name,
      "tp": c[0],
      "fp": c[1],
      "fn": c[2],
      "precision": if c[0] + c[1] == 0 {
        Json::null()
      } else {
        (c[0].to_double() / (c[0] + c[1]).to_double()).to_json()
      },
      "recall": if c[0] + c[2] == 0 {
        Json::null()
      } else {
        (c[0].to_double() / (c[0] + c[2]).to_double()).to_json()
      },
    })
  }
  {
    "kind": "signal_study",
    "request": f.to_json(),
    "unit": research_string(f, "unit", "sample units"),
    "rows": rows,
    "invalid_windows": invalid,
    "anomaly_segments": segments,
    "original_times": times,
    "original_values": raw_values,
    "grid": grid,
    "resampled_values": regular.map(optional_number),
    "provenance": provenance,
    "baseline_windows": baseline_count,
    "baseline_grid_end": fit_end - 1,
    "normalization": normalization,
    "offset": offset,
    "scale": scale,
    "detrend": detrend,
    "grid_step": step,
    "max_gap": max_gap,
    "score_order": ["topology", "mean_rms", "autocorrelation", "spectral_peak"],
    "thresholds": limits,
    "threshold_factor": factor,
    "evaluation": if !f.contains("events") {
      Json::null()
    } else {
      evaluation.to_json()
    },
    "interpretation": "training-only leave-one-out maximum-distance calibration, not a probabilistic false-alarm guarantee; windows overlap; interpolation uses bounded gaps and never extrapolates; annotated-window positives require >=50% duration overlap; topological features must be compared with simple baselines, not assumed superior",
  }
}
