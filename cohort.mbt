///|
/// Exact label permutations or paired sign flips on a common finite landscape.
pub fn cohort_study(text : String) -> Json raise TopologyError {
  let f = research_object(text, "cohort", [
    "samples", "dimension", "start", "end", "design", "unit", "preprocessing",
  ])
  let unit = batch_string(f, "unit")
  if unit == "" || unit.length() > 80 {
    raise TopologyError("cohort requires explicit common units")
  }
  let design = research_string(f, "design", "independent")
  if design != "independent" && design != "paired" {
    raise TopologyError("design must be independent or paired")
  }
  let samples : Array[Json] = @json.from_json(required_field(f, "samples")) catch {
    _ => raise TopologyError("invalid cohort samples")
  }
  if samples.length() < 4 || samples.length() > 16 {
    raise TopologyError("cohort requires 4..16 samples")
  }
  let mode = research_string(f, "preprocessing", "none")
  if mode != "none" && mode != "pooled_zscore" {
    raise TopologyError("preprocessing must be none or pooled_zscore")
  }
  let names : Array[String] = []
  let groups : Array[String] = []
  let requests : Array[Json] = []
  let pooled : Array[Array[Double]] = []
  let mut width = 0
  for sample in samples {
    let sf = batch_object(sample, "cohort sample")
    for key in sf.keys() {
      if !["name", "group", "request"].contains(key) {
        raise TopologyError("unknown cohort sample field")
      }
    }
    let name = batch_string(sf, "name")
    batch_name(name)
    if names.contains(name) {
      raise TopologyError("duplicate cohort sample name")
    }
    let group = batch_string(sf, "group")
    if group != "A" && group != "B" {
      raise TopologyError("cohort groups must be A or B")
    }
    let request = required_field(sf, "request")
    if mode == "pooled_zscore" {
      let rf = batch_object(request, "cohort request")
      if !["points", "points_sparse"].contains(batch_string(rf, "kind")) {
        raise TopologyError("pooled scaling requires point clouds")
      }
      for row in rows_field(rf, "points") {
        if width == 0 {
          width = row.length()
        }
        if row.length() != width ||
          width < 1 ||
          width > 32 ||
          pooled.length() >= 10000 {
          raise TopologyError("pooled table shape or size exceeded")
        }
        pooled.push(row)
      }
    }
    names.push(name)
    groups.push(group)
    requests.push(request)
  }
  let offsets : Array[Double] = []
  let scales : Array[Double] = []
  if mode == "pooled_zscore" {
    let table : NumericCsv = {
      headers: Array::makei(width, fn(i) { "column_\{i}" }),
      rows: pooled,
    }
    let params = batch_object(
      csv_transform_json(table, normalization="zscore"),
      "scaling",
    )
    let off : Array[Double] = @json.from_json(required_field(params, "offsets")) catch {
      _ => raise TopologyError("invalid offsets")
    }
    let sc : Array[Double] = @json.from_json(required_field(params, "scales")) catch {
      _ => raise TopologyError("invalid scales")
    }
    for v in off {
      offsets.push(v)
    }
    for v in sc {
      scales.push(v)
    }
    for i = 0; i < requests.length(); i = i + 1 {
      let rf = batch_object(requests[i], "request").copy()
      let rows = rows_field(rf, "points").map(fn(row) {
        Array::makei(width, fn(c) { (row[c] - offsets[c]) / scales[c] })
      })
      rf.set("points", rows.to_json())
      requests[i] = rf.to_json()
    }
  }
  let a_ids : Array[Int] = []
  let b_ids : Array[Int] = []
  for i, g in groups {
    if g == "A" {
      a_ids.push(i)
    } else {
      b_ids.push(i)
    }
  }
  if a_ids.length() < 2 ||
    b_ids.length() < 2 ||
    a_ids.length() > 8 ||
    b_ids.length() > 8 ||
    (design == "paired" && a_ids.length() != b_ids.length()) ||
    (design == "independent" && samples.length() > 14) {
    raise TopologyError(
      "independent cohorts: 2..8 per group, <=14 total; paired: 2..8 pairs in group order",
    )
  }
  let dimension = integer_field(f, "dimension", 1)
  let start = research_number(f, "start", 0.0)
  let end = number_field(f, "end")
  let analyses : Array[Analysis] = []
  let vectors : Array[Array[Double]] = []
  let mut total = 0
  for request in requests {
    let a = research_request(request)
    if end > a.filtration.cutoff {
      raise TopologyError("cohort end exceeds observation cutoff")
    }
    if analyses.length() > 0 &&
      (
        a.filtration.kind != analyses[0].filtration.kind ||
        a.filtration.cutoff != analyses[0].filtration.cutoff
      ) {
      raise TopologyError("cohort cases require common complex kind and cutoff")
    }
    total += a.filtration.cells.length()
    if total > 32000 {
      raise TopologyError("cohort exceeds 32000 cells")
    }
    vectors.push(research_vector(a, dimension, start, end, 31))
    analyses.push(a)
  }
  let mean_a = Array::make(31, 0.0)
  let mean_b = Array::make(31, 0.0)
  for id in a_ids {
    for j = 0; j < 31; j = j + 1 {
      mean_a[j] += vectors[id][j] / a_ids.length().to_double()
    }
  }
  for id in b_ids {
    for j = 0; j < 31; j = j + 1 {
      mean_b[j] += vectors[id][j] / b_ids.length().to_double()
    }
  }
  let observed = Array::makei(31, fn(j) { (mean_a[j] - mean_b[j]).abs() })
  let observed_l2 = research_l2(mean_a, mean_b)
  let mut comparison_scale = 0.0
  for vector in vectors {
    for value in vector {
      comparison_scale = maximum(comparison_scale, value.abs())
    }
  }
  let tolerance = 1.0e-12 * comparison_scale
  let raw_counts = Array::make(31, 0)
  let adjusted_counts = Array::make(31, 0)
  let mut global_count = 0
  let mut permutations = 0
  let limit = 1 <<
    (if design == "paired" { a_ids.length() } else { samples.length() })
  for mask = 0; mask < limit; mask = mask + 1 {
    let mut count = 0
    for i = 0; i < samples.length(); i = i + 1 {
      if (mask & (1 << i)) != 0 {
        count += 1
      }
    }
    if design == "independent" && count != a_ids.length() {
      continue
    }
    let ma = Array::make(31, 0.0)
    let mb = Array::make(31, 0.0)
    if design == "independent" {
      for i = 0; i < samples.length(); i = i + 1 {
        for j = 0; j < 31; j = j + 1 {
          if (mask & (1 << i)) != 0 {
            ma[j] += vectors[i][j] / a_ids.length().to_double()
          } else {
            mb[j] += vectors[i][j] / b_ids.length().to_double()
          }
        }
      }
    } else {
      for p = 0; p < a_ids.length(); p = p + 1 {
        let x = if (mask & (1 << p)) == 0 { a_ids[p] } else { b_ids[p] }
        let y = if (mask & (1 << p)) == 0 { b_ids[p] } else { a_ids[p] }
        for j = 0; j < 31; j = j + 1 {
          ma[j] += vectors[x][j] / a_ids.length().to_double()
          mb[j] += vectors[y][j] / b_ids.length().to_double()
        }
      }
    }
    let mut peak = 0.0
    for j = 0; j < 31; j = j + 1 {
      peak = maximum(peak, (ma[j] - mb[j]).abs())
    }
    for j = 0; j < 31; j = j + 1 {
      if (ma[j] - mb[j]).abs() + tolerance >= observed[j] {
        raw_counts[j] += 1
      }
      if peak + tolerance >= observed[j] {
        adjusted_counts[j] += 1
      }
    }
    if research_l2(ma, mb) + tolerance >= observed_l2 {
      global_count += 1
    }
    permutations += 1
  }
  let grid = landscape_grid(start, end, 31)
  let rows : Array[Json] = Array::makei(31, fn(j) {
    {
      "scale": grid[j],
      "mean_A": mean_a[j],
      "mean_B": mean_b[j],
      "effect_A_minus_B": mean_a[j] - mean_b[j],
      "p_raw": raw_counts[j].to_double() / permutations.to_double(),
      "p_max_adjusted": adjusted_counts[j].to_double() /
      permutations.to_double(),
    }
  })
  let cases : Array[Json] = []
  for i, a in analyses {
    cases.push({
      "name": names[i],
      "group": groups[i],
      "distance_to_group_mean": research_l2(
        vectors[i],
        if groups[i] == "A" {
          mean_a
        } else {
          mean_b
        },
      ),
      "landscape": vectors[i],
      "excluded_censored": a.intervals
      .filter(fn(x) { x.dimension == dimension && x.death is None })
      .length(),
      "original_request": required_field(
        batch_object(samples[i], "sample"),
        "request",
      ),
      "analysis": report_json(a),
    })
  }
  {
    "kind": "cohort",
    "request": f.to_json(),
    "design": design,
    "unit": unit,
    "preprocessing": mode,
    "offsets": offsets,
    "scales": scales,
    "dimension": dimension,
    "start": start,
    "end": end,
    "rows": rows,
    "samples": cases,
    "permutations": permutations,
    "global_l2_rms": observed_l2,
    "comparison_tolerance": tolerance,
    "global_p_exact": global_count.to_double() / permutations.to_double(),
    "assumptions": if design == "paired" {
      "independent pairs; within-pair label exchangeability under the null; pair A[i] with B[i]"
    } else {
      "independent sampling units; group-label exchangeability under the null; overlapping windows are not independent samples"
    },
    "interpretation": "exact two-sided randomization tests on finite first-layer landscapes; max-statistic adjustment over 31 scales under joint label exchangeability (complete null); no causal attribution; pooled preprocessing is group-blind; units must be declared consistently",
  }
}
