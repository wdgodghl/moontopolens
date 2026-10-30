///|
fn reliability_noise(
  value : Json,
  state : Ref[Int32],
  amplitude : Double,
) -> Json raise TopologyError {
  match value {
    Array(values) =>
      values
      .map(fn(v) raise TopologyError { reliability_noise(v, state, amplitude) })
      .to_json()
    Number(v, ..) =>
      (v + amplitude * (research_next(state, 65536).to_double() / 32768.0 - 1.0)).to_json()
    _ =>
      raise TopologyError(
        "jitter requires numeric coordinates or scalar fields",
      )
  }
}

///|
/// Finite-grid simultaneous Hoeffding bands for an IID mean landscape.
fn reliability_mean_band(f : Map[String, Json]) -> Json raise TopologyError {
  if research_string(f, "assumption", "") != "iid_independent_samples" {
    raise TopologyError(
      "mean_band requires explicit iid_independent_samples assumption",
    )
  }
  let cases : Array[Json] = @json.from_json(required_field(f, "inputs")) catch {
    _ => raise TopologyError("inputs must be independent analysis requests")
  }
  if cases.length() < 2 || cases.length() > 64 {
    raise TopologyError("mean band requires 2..64 independent samples")
  }
  let start = research_number(f, "start", 0.0)
  let end = number_field(f, "end")
  let confidence = research_number(f, "confidence", 0.95)
  if !finite(end) || start >= end || confidence <= 0.0 || confidence >= 1.0 {
    raise TopologyError("invalid confidence or range")
  }
  let dimension = integer_field(f, "dimension", 1)
  let vectors : Array[Array[Double]] = []
  let mut total = 0
  let mut kind = ""
  let excluded : Array[Int32] = []
  for request in cases {
    let a = research_request(request)
    if a.filtration.cutoff != end {
      raise TopologyError("mean band inputs require common cutoff=end")
    }
    if kind != "" && kind != a.filtration.kind {
      raise TopologyError("mean band requires a common complex kind")
    }
    kind = a.filtration.kind
    for cell in a.filtration.cells {
      if cell.value < start {
        raise TopologyError(
          "mean band start must bound all filtration values from below",
        )
      }
    }
    total += a.filtration.cells.length()
    if total > 64000 {
      raise TopologyError("mean band exceeds 64000 cells")
    }
    vectors.push(research_vector(a, dimension, start, end, 31))
    excluded.push(
      a.intervals
      .filter(fn(i) { i.dimension == dimension && i.death is None })
      .length(),
    )
  }
  let mean = Array::make(31, 0.0)
  for row in vectors {
    for j = 0; j < 31; j = j + 1 {
      mean[j] += row[j] / cases.length().to_double()
    }
  }
  let bound = (end - start) / 2.0
  let epsilon = bound *
    (@math.ln(62.0 / (1.0 - confidence)) / (2.0 * cases.length().to_double())).sqrt()
  let grid = landscape_grid(start, end, 31)
  let rows : Array[Json] = Array::makei(31, fn(j) {
    {
      "scale": grid[j],
      "mean": mean[j],
      "lower": maximum(0.0, mean[j] - epsilon),
      "upper": if mean[j] + epsilon > bound {
        bound
      } else {
        mean[j] + epsilon
      },
    }
  })
  {
    "kind": "reliability",
    "request": f.to_json(),
    "mode": "mean_band",
    "rows": rows,
    "sample_count": cases.length(),
    "confidence": confidence,
    "epsilon": epsilon,
    "dimension": dimension,
    "censored_excluded_per_sample": excluded,
    "grid_simultaneous": true,
    "vacuous": epsilon >= bound,
    "interpretation": "Hoeffding plus union bound over 31 fixed grid points for the population mean first finite landscape under IID independent sampling units and common observation conditions; not confidence for individual intervals, whole continuous curves, or overlapping windows",
  }
}

///|
/// Seeded sensitivity and resampling envelopes; frequencies are not probabilities.
pub fn reliability_study(text : String) -> Json raise TopologyError {
  let f = research_object(text, "reliability", [
    "mode", "input", "inputs", "start", "end", "confidence", "assumption", "dimension",
    "trials", "seed", "sizes", "thresholds", "jitter", "block_length", "match_tolerance",
  ])
  let mode = research_string(f, "mode", "subsample_points")
  if mode == "mean_band" {
    return reliability_mean_band(f)
  }
  if !["subsample_points", "bootstrap_points", "block_series", "jitter"].contains(
      mode,
    ) {
    raise TopologyError("unknown reliability mode")
  }
  let original = batch_object(required_field(f, "input"), "reliability input")
  let input_kind = batch_string(original, "kind")
  let trials = integer_field(f, "trials", 16)
  let seed = integer_field(f, "seed", 1)
  let dimension = integer_field(f, "dimension", 1)
  let amplitude = research_number(f, "jitter", 0.0)
  if trials < 2 ||
    trials > 64 ||
    seed < 0 ||
    seed > 65535 ||
    amplitude < 0.0 ||
    amplitude > 1.0e6 {
    raise TopologyError(
      "reliability requires 2..64 trials, 16-bit seed and bounded nonnegative jitter",
    )
  }
  let thresholds = research_numbers(f, "thresholds", [
    number_field(original, "threshold"),
  ])
  let base = research_request(original.to_json())
  let n = if input_kind == "points" || input_kind == "points_sparse" {
    rows_field(original, "points").length()
  } else {
    base.filtration.vertex_count
  }
  let sizes = research_numbers(f, "sizes", [n.to_double()])
  if thresholds.length() < 1 ||
    thresholds.length() > 8 ||
    sizes.length() < 1 ||
    sizes.length() > 8 ||
    thresholds.length() * sizes.length() * trials > 96 {
    raise TopologyError("reliability requires <=96 resampled cases")
  }
  if mode == "subsample_points" || mode == "bootstrap_points" {
    if (input_kind != "points" && input_kind != "points_sparse") ||
      n < 2 ||
      n > 128 {
      raise TopologyError("point resampling requires 2..128 original points")
    }
    for size in sizes {
      if size < 2.0 || size > n.to_double() || size != @math.floor(size) {
        raise TopologyError(
          "resampling sizes must be integers in 2..original count",
        )
      }
    }
  } else if sizes.length() != 1 || sizes[0] != n.to_double() {
    raise TopologyError("sizes apply only to point resampling")
  }
  if mode == "block_series" && input_kind != "series" {
    raise TopologyError("block resampling requires a series")
  }
  let state = Ref(seed)
  let rows : Array[Json] = []
  let features : Array[Json] = []
  let envelopes : Array[Json] = []
  let mut total = 0
  for cutoff in thresholds {
    let baseline_request = original.copy()
    baseline_request.set("threshold", cutoff.to_json())
    let baseline = research_request(baseline_request.to_json())
    let start = research_number(
      f,
      "start",
      if cutoff > 0.0 {
        0.0
      } else {
        cutoff - 1.0
      },
    )
    if start >= cutoff {
      raise TopologyError("reliability start must be below every cutoff")
    }
    let reference = research_vector(baseline, dimension, start, cutoff, 31)
    let tolerance = research_number(
      f,
      "match_tolerance",
      maximum(1.0e-12, (cutoff - start) * 0.1),
    )
    if tolerance < 0.0 {
      raise TopologyError("negative matching tolerance")
    }
    for size in sizes {
      let support = Array::make(baseline.intervals.length(), 0)
      let vectors : Array[Array[Double]] = []
      for trial = 0; trial < trials; trial = trial + 1 {
        let request = baseline_request.copy()
        let indices : Array[Int32] = []
        if mode == "subsample_points" || mode == "bootstrap_points" {
          let points = rows_field(original, "points")
          let order = Array::makei(n, fn(i) { i })
          for i = 0; i < size.to_int(); i = i + 1 {
            if mode == "bootstrap_points" {
              indices.push(research_next(state, n))
            } else {
              let j = i + research_next(state, n - i)
              let old = order[i]
              order[i] = order[j]
              order[j] = old
              indices.push(order[i])
            }
          }
          request.set("points", indices.map(fn(i) { points[i] }).to_json())
        } else if mode == "block_series" {
          let series : Array[Double] = @json.from_json(
            required_field(original, "series"),
          ) catch {
            _ => raise TopologyError("invalid series")
          }
          let length = integer_field(f, "block_length", 4)
          if length < 1 || length > series.length() || series.length() > 512 {
            raise TopologyError(
              "block_length must fit a series of <=512 samples",
            )
          }
          while indices.length() < series.length() {
            let begin = research_next(state, series.length() - length + 1)
            for j = 0
                j < length && indices.length() < series.length()
                j = j + 1 {
              indices.push(begin + j)
            }
          }
          request.set("series", indices.map(fn(i) { series[i] }).to_json())
        } else {
          let field = match input_kind {
            "points" | "points_sparse" => "points"
            "grid" => "grid"
            "volume" => "volume"
            "series" => "series"
            _ => raise TopologyError("jitter does not support this input")
          }
          request.set(
            field,
            reliability_noise(required_field(original, field), state, amplitude),
          )
        }
        let result = analyze_json(
          request.to_json().stringify(),
          representatives=false,
        )
        total += result.filtration.cells.length()
        if total > 64000 {
          raise TopologyError("reliability exceeds 64000 resampled cells")
        }
        let vector = research_vector(result, dimension, start, cutoff, 31)
        vectors.push(vector)
        for m in interval_matching(baseline, result, dimension~) {
          if m.left is Some(id) &&
            m.right is Some(_) &&
            m.cost is Some(cost) &&
            cost <= tolerance {
            support[id] += 1
          }
        }
        rows.push({
          "cutoff": cutoff,
          "size": size,
          "trial": trial,
          "landscape_rms_change": research_l2(reference, vector),
          "bottleneck": optional_number(
            compare_analyses(baseline, result, dimension~),
          ),
          "censored_count": result.intervals
          .filter(fn(i) { i.dimension == dimension && i.death is None })
          .length(),
          "source_indices": indices,
        })
      }
      for i, interval in baseline.intervals {
        if interval.dimension == dimension {
          features.push({
            "cutoff": cutoff,
            "size": size,
            "interval_index": i,
            "birth": interval.birth,
            "death": optional_number(interval.death),
            "retained": support[i],
            "trials": trials,
            "support_frequency": support[i].to_double() / trials.to_double(),
            "match_tolerance": tolerance,
          })
        }
      }
      let grid = landscape_grid(start, cutoff, 31)
      for j = 0; j < 31; j = j + 1 {
        let column = vectors.map(fn(v) { v[j] })
        envelopes.push({
          "cutoff": cutoff,
          "size": size,
          "scale": grid[j],
          "q025": research_quantile(column, 0.025),
          "median": research_quantile(column, 0.5),
          "q975": research_quantile(column, 0.975),
        })
      }
    }
  }
  {
    "kind": "reliability",
    "request": f.to_json(),
    "mode": mode,
    "seed": seed,
    "dimension": dimension,
    "rows": rows,
    "features": features,
    "envelopes": envelopes,
    "baseline": report_json(base),
    "interpretation": "seeded empirical sensitivity experiment; pointwise resampling percentiles and matching support are not coverage guarantees, probabilities that a feature is real, or confidence sets; block resampling synthesizes block joins and assumes locally stationary dependence for interpretation; censored-count mismatch yields null distance",
  }
}
