///|
fn study_square(side : Double) -> Json {
  {
    "kind": "points",
    "threshold": 2.0,
    "points": [[0.0, 0.0], [side, 0.0], [side, side], [0.0, side]],
  }
}

///|
fn study_fields(value : Json) -> Map[String, Json] raise TopologyError {
  batch_object(value, "test report")
}

///|
fn study_rows(value : Json, key : String) -> Array[Json] raise TopologyError {
  @json.from_json(required_field(study_fields(value), key)) catch {
    _ => raise TopologyError("test expected rows")
  }
}

///|
fn study_reject(action : () -> Unit raise TopologyError) -> Unit raise {
  let rejected = try {
    action()
    false
  } catch {
    _ => true
  }
  assert_true(rejected)
}

///|
test "whole-point subsampling preserves the square diagram and seed replay" {
  let request : Json = {
    "kind": "reliability",
    "input": study_square(1.0),
    "sizes": [4],
    "trials": 3,
    "seed": 17,
  }
  let report = reliability_study(request.stringify())
  assert_eq(report, reliability_study(request.stringify()))
  for row in study_rows(report, "rows") {
    assert_eq(number_field(study_fields(row), "landscape_rms_change"), 0.0)
    assert_eq(number_field(study_fields(row), "bottleneck"), 0.0)
  }
  for row in study_rows(report, "features") {
    assert_eq(number_field(study_fields(row), "support_frequency"), 1.0)
  }
}

///|
test "zero field jitter is exact and three-point sampling removes square H1" {
  let grid : Json = {
    "kind": "grid",
    "threshold": 2,
    "grid": [[0, 0, 0], [0, 1, 0], [0, 0, 0]],
  }
  let request : Json = {
    "kind": "reliability",
    "mode": "jitter",
    "input": grid,
    "trials": 2,
    "jitter": 0,
  }
  for row in study_rows(reliability_study(request.stringify()), "rows") {
    assert_eq(number_field(study_fields(row), "bottleneck"), 0.0)
  }
  let sample : Json = {
    "kind": "reliability",
    "input": study_square(1.0),
    "sizes": [3],
    "trials": 2,
  }
  for row in study_rows(reliability_study(sample.stringify()), "features") {
    assert_eq(number_field(study_fields(row), "support_frequency"), 0.0)
  }
}

///|
test "mean band derives bounded finite-grid Hoeffding width and requires IID declaration" {
  let f : Map[String, Json] = Map([
    ("kind", "reliability".to_json()),
    ("mode", "mean_band".to_json()),
    ("inputs", [study_square(1.0), study_square(0.5)].to_json()),
    ("end", 2.0.to_json()),
  ])
  study_reject(fn() raise TopologyError {
    ignore(reliability_study(f.to_json().stringify()))
  })
  f.set("assumption", "iid_independent_samples".to_json())
  let report = reliability_study(f.to_json().stringify())
  let epsilon = (@math.ln(62.0 / 0.05) / 4.0).sqrt()
  assert_true(
    (number_field(study_fields(report), "epsilon") - epsilon).abs() < 1.0e-12,
  )
  assert_eq(required_field(study_fields(report), "vacuous"), true.to_json())
  for row in study_rows(report, "rows") {
    let rf = study_fields(row)
    assert_true(number_field(rf, "lower") <= number_field(rf, "mean"))
    assert_true(number_field(rf, "upper") >= number_field(rf, "mean"))
  }
}

///|
fn study_cohort(design : String, identical : Bool) -> Json {
  let samples : Array[Json] = []
  for i = 0; i < 4; i = i + 1 {
    samples.push({
      "name": "s\{i}",
      "group": if i < 2 {
        "A"
      } else {
        "B"
      },
      "request": study_square(if i < 2 || identical { 1.0 } else { 0.3 }),
    })
  }
  {
    "kind": "cohort",
    "samples": samples,
    "unit": "u",
    "end": 2.0,
    "design": design,
  }
}

///|
test "exact group randomization has analytic independent and paired probabilities" {
  let independent = study_fields(
    cohort_study(study_cohort("independent", false).stringify()),
  )
  assert_eq(integer_field(independent, "permutations", 0), 6)
  assert_true(
    (number_field(independent, "global_p_exact") - 1.0 / 3.0).abs() < 1.0e-12,
  )
  let paired = study_fields(
    cohort_study(study_cohort("paired", false).stringify()),
  )
  assert_eq(integer_field(paired, "permutations", 0), 4)
  assert_eq(number_field(paired, "global_p_exact"), 0.5)
  let identical = study_fields(
    cohort_study(study_cohort("independent", true).stringify()),
  )
  assert_eq(number_field(identical, "global_p_exact"), 1.0)
}

///|
test "cohort correction is never below raw p and shared transform is recorded" {
  let f = study_fields(study_cohort("independent", false)).copy()
  f.set("preprocessing", "pooled_zscore".to_json())
  let report = cohort_study(f.to_json().stringify())
  let offsets : Array[Double] = @json.from_json(
    required_field(study_fields(report), "offsets"),
  )
  assert_eq(offsets.length(), 2)
  for row in study_rows(report, "rows") {
    let r = study_fields(row)
    assert_true(number_field(r, "p_max_adjusted") >= number_field(r, "p_raw"))
  }
}

///|
fn study_signal() -> Map[String, Json] {
  let values = Array::makei(64, fn(i) {
    @math.sin(i.to_double() * 3.141592653589793 / 4.0)
  })
  Map([
    ("kind", "signal_study".to_json()),
    ("values", values.to_json()),
    ("threshold", 2.0.to_json()),
    ("window", (16).to_json()),
    ("hop", (8).to_json()),
    ("baseline_windows", (2).to_json()),
    ("lag", (2).to_json()),
    ("normalization", "baseline_zscore".to_json()),
  ])
}

///|
test "future signal values cannot change baseline normalization or thresholds" {
  let f = study_signal()
  let a = study_fields(signal_study(f.to_json().stringify()))
  let values : Array[Double] = @json.from_json(f["values"])
  for i = 24; i < values.length(); i = i + 1 {
    values[i] *= 2.0
  }
  f.set("values", values.to_json())
  let b = study_fields(signal_study(f.to_json().stringify()))
  for key in ["offset", "scale", "thresholds"] {
    assert_eq(a[key], b[key])
  }
  assert_eq(
    study_rows(a.to_json(), "rows")[0],
    study_rows(b.to_json(), "rows")[0],
  )
}

///|
test "signal blank CSV is explicit, bounded interpolation preserves provenance" {
  let config = study_signal()
  config.remove("values") |> ignore
  let mut csv = "time,value,tag\n"
  for i = 0; i < 64; i = i + 1 {
    csv += "\{i}," +
      (if i == 30 { "" } else { "\{@math.sin(i.to_double()/2.0)}" }) +
      ",row\n"
  }
  let request = signal_csv_request(csv, config.to_json().stringify())
  study_reject(fn() raise TopologyError {
    ignore(signal_study(request.stringify()))
  })
  let f = study_fields(request).copy()
  f.set("interpolation", "linear".to_json())
  f.set("max_gap", 2.0.to_json())
  let report = signal_study(f.to_json().stringify())
  let map = study_fields(study_rows(report, "provenance")[30])
  assert_eq(integer_field(map, "left", 0), 29)
  assert_eq(integer_field(map, "right", 0), 31)
  assert_eq(number_field(map, "weight_right"), 0.5)
  assert_eq(study_rows(report, "original_values")[30], Json::null())
}

///|
test "signal long gaps skip monitoring windows and empty labels evaluate negatives" {
  let f = study_signal()
  let values : Array[Json] = @json.from_json(f["values"])
  for i = 30; i <= 40; i = i + 1 {
    values[i] = Json::null()
  }
  f.set("values", values.to_json())
  f.set("interpolation", "linear".to_json())
  f.set("events", ([] : Array[Json]).to_json())
  let report = signal_study(f.to_json().stringify())
  assert_true(study_rows(report, "invalid_windows").length() > 0)
  assert_eq(study_rows(report, "evaluation").length(), 4)
  for row in study_rows(report, "evaluation") {
    assert_eq(integer_field(study_fields(row), "tp", -1), 0)
    assert_eq(integer_field(study_fields(row), "fn", -1), 0)
  }
}

///|
fn study_pore(volume : Array[Array[Array[Double]]]) -> Json {
  {
    "kind": "pores",
    "volume": volume,
    "spacing": [2.0, 3.0, 4.0],
    "origin": [10.0, 20.0, 30.0],
    "unit": "um",
    "radii": [0.0, 1.0, 1.1],
  }
}

///|
test "single enclosed anisotropic voxel has exact volume area centroid and clearance" {
  let volume = Array::makei(3, fn(z) {
    Array::makei(3, fn(y) {
      Array::makei(3, fn(x) {
        if x == 1 && y == 1 && z == 1 {
          1.0
        } else {
          0.0
        }
      })
    })
  })
  let report = pore_study(study_pore(volume).stringify())
  let f = study_fields(report)
  assert_eq(integer_field(f, "enclosed_components", 0), 1)
  let row = study_fields(study_rows(report, "rows")[0])
  assert_eq(number_field(row, "volume"), 24.0)
  assert_eq(number_field(row, "solid_interface_area"), 52.0)
  assert_eq(number_field(row, "crop_cap_area"), 0.0)
  assert_eq(row["centroid"], [12.0, 23.0, 34.0].to_json())
  assert_eq(number_field(row, "contained_ball_radius_at_voxel_center"), 1.0)
  assert_eq(study_rows(report, "solid_clearance")[13], 1.0.to_json())
  let obj = pore_surface_obj(report)
  assert_eq(obj.split("\nf ").to_array().length() - 1, 12)
}

///|
test "open channel spans only its axis and all-void crop has no observed-solid clearance" {
  let channel = Array::makei(3, fn(z) {
    Array::makei(3, fn(y) {
      Array::makei(3, fn(_) { if y == 1 && z == 1 { 1.0 } else { 0.0 } })
    })
  })
  let report = pore_study(study_pore(channel).stringify())
  let r = study_fields(study_rows(report, "rows")[0])
  assert_eq(r["spans_xyz"], [true, false, false].to_json())
  assert_eq(r["touches_crop"], true.to_json())
  let full = Array::makei(3, fn(_) {
    Array::makei(3, fn(_) { [1.0, 1.0, 1.0] })
  })
  let report = pore_study(study_pore(full).stringify())
  assert_eq(study_rows(report, "solid_clearance")[13], Json::null())
  assert_eq(
    number_field(
      study_fields(study_rows(report, "rows")[0]),
      "contained_ball_radius_at_voxel_center",
    ),
    3.0,
  )
}

///|
test "pore distance transform agrees with brute force solid boxes" {
  let w = 4
  let h = 3
  let d = 3
  let spacing = [1.3, 2.1, 0.7]
  let mask = Array::makei(w * h * d, fn(i) { i % 7 != 0 && i % 11 != 0 })
  let got = pore_distances(mask, w, h, d, spacing)
  for i = 0; i < mask.length(); i = i + 1 {
    let mut best = 1.0e100
    for j = 0; j < mask.length(); j = j + 1 {
      if !mask[j] {
        let a = [i % w, i / w % h, i / (w * h)]
        let b = [j % w, j / w % h, j / (w * h)]
        let mut sum = 0.0
        for axis = 0; axis < 3; axis = axis + 1 {
          let delta = maximum(0.0, (a[axis] - b[axis]).abs().to_double() - 0.5) *
            spacing[axis]
          sum += delta * delta
        }
        if sum < best {
          best = sum
        }
      }
    }
    assert_true((got[i] - best.sqrt()).abs() < 1.0e-12)
  }
}

///|
test "pore overlap identifies merges splits births losses and rejects unregistered grids" {
  let before = pore_study(study_pore([[[1.0, 0.0, 1.0]]]).stringify())
  let after = pore_study(study_pore([[[1.0, 1.0, 1.0]]]).stringify())
  for row in study_rows(pore_compare(before, after), "rows") {
    assert_eq(study_fields(row)["merge_candidate"], true.to_json())
  }
  for row in study_rows(pore_compare(after, before), "rows") {
    assert_eq(study_fields(row)["split_candidate"], true.to_json())
  }
  let solid = pore_study(study_pore([[[0.0, 0.0, 0.0]]]).stringify())
  assert_eq(study_rows(pore_compare(solid, before), "appeared_labels"), [
    (1).to_json(),
    (2).to_json(),
  ])
  assert_eq(study_rows(pore_compare(before, solid), "disappeared_labels"), [
    (1).to_json(),
    (2).to_json(),
  ])
  let f = study_fields(after).copy()
  f.set("origin", [0.0, 0.0, 0.0].to_json())
  study_reject(fn() raise TopologyError {
    ignore(pore_compare(before, f.to_json()))
  })
}

///|
test "research APIs reject invalid requests without producing reports" {
  study_reject(fn() raise TopologyError {
    ignore(pore_study("{\"kind\":\"pores\",\"volume\":[]}"))
  })
  let f = study_fields(study_cohort("independent", false)).copy()
  f.set("unit", "".to_json())
  study_reject(fn() raise TopologyError {
    ignore(cohort_study(f.to_json().stringify()))
  })
  let f = study_signal()
  f.set("times", Array::make(64, 0.0).to_json())
  study_reject(fn() raise TopologyError {
    ignore(signal_study(f.to_json().stringify()))
  })
  let f : Json = {
    "kind": "reliability",
    "input": study_square(1.0),
    "trials": 100,
  }
  study_reject(fn() raise TopologyError {
    ignore(reliability_study(f.stringify()))
  })
}

///|
test "block resampling preserves contiguous within-block source indices" {
  let series = Array::makei(16, fn(i) { @math.sin(i.to_double()) })
  let input : Json = {
    "kind": "series",
    "series": series,
    "threshold": 2.0,
    "dimension": 2,
    "lag": 1,
    "stride": 1,
  }
  let request : Json = {
    "kind": "reliability",
    "mode": "block_series",
    "input": input,
    "trials": 2,
    "block_length": 4,
    "seed": 91,
  }
  for row in study_rows(reliability_study(request.stringify()), "rows") {
    let ids : Array[Int] = @json.from_json(
      required_field(study_fields(row), "source_indices"),
    )
    assert_eq(ids.length(), 16)
    for i = 0; i < 16; i = i + 1 {
      assert_true(ids[i] >= 0 && ids[i] < 16)
      if i % 4 != 0 {
        assert_eq(ids[i], ids[i - 1] + 1)
      }
    }
  }
}

///|
test "bootstrap records duplicate observations and bounded indices" {
  let request : Json = {
    "kind": "reliability",
    "mode": "bootstrap_points",
    "input": study_square(1.0),
    "trials": 8,
    "seed": 2,
  }
  let mut duplicate = false
  for row in study_rows(reliability_study(request.stringify()), "rows") {
    let ids : Array[Int] = @json.from_json(
      required_field(study_fields(row), "source_indices"),
    )
    for i, v in ids {
      assert_true(v >= 0 && v < 4)
      for j = 0; j < i; j = j + 1 {
        if ids[j] == v {
          duplicate = true
        }
      }
    }
  }
  assert_true(duplicate)
}

///|
test "baseline interpolation cannot borrow monitoring samples and constant calibration stays exact" {
  let f = study_signal()
  let values : Array[Json] = @json.from_json(f["values"])
  values[23] = Json::null()
  f.set("values", values.to_json())
  f.set("interpolation", "linear".to_json())
  study_reject(fn() raise TopologyError {
    ignore(signal_study(f.to_json().stringify()))
  })
  f.set("values", Array::make(64, 0.1).to_json())
  let report = study_fields(signal_study(f.to_json().stringify()))
  assert_eq(number_field(report, "offset"), 0.1)
  assert_eq(number_field(report, "scale"), 1.0)
}

///|
test "pore NIfTI uses declared physical geometry and rejects shear or flipped axes" {
  let study : NiftiStudy = {
    volumes: [[[[0.0, 1.0], [0.0, 0.0]], [[0.0, 0.0], [0.0, 0.0]]]],
    affine: [
      [2.0, 0.0, 0.0, 10.0],
      [0.0, 3.0, 0.0, 20.0],
      [0.0, 0.0, 4.0, 30.0],
    ],
    spatial_units: 2,
    temporal_units: 0,
    time_step: 1.0,
    time_offset: 0.0,
    transform_source: "sform",
  }
  let request = pore_nifti_request(study, "{\"kind\":\"pores\"}")
  let report = study_fields(pore_study(request.stringify()))
  assert_eq(report["unit"], "mm".to_json())
  assert_eq(report["spacing"], [2.0, 3.0, 4.0].to_json())
  study.affine[0][1] = 0.1
  study_reject(fn() raise TopologyError {
    ignore(pore_nifti_request(study, "{\"kind\":\"pores\"}"))
  })
  study.affine[0][1] = 0.0
  study.affine[0][0] = -2.0
  study_reject(fn() raise TopologyError {
    ignore(pore_nifti_request(study, "{\"kind\":\"pores\"}"))
  })
}

///|
test "cohort permutation probabilities are invariant to small unit conversion" {
  let request = study_fields(study_cohort("independent", false)).copy()
  let original = cohort_study(request.to_json().stringify())
  let samples = study_rows(request.to_json(), "samples")
  for i, sample in samples {
    let sf = study_fields(sample).copy()
    let rf = study_fields(sf["request"]).copy()
    rf.set(
      "points",
      rows_field(rf, "points")
      .map(fn(row) { row.map(fn(v) { v * 1.0e-13 }) })
      .to_json(),
    )
    rf.set("threshold", 2.0e-13.to_json())
    sf.set("request", rf.to_json())
    samples[i] = sf.to_json()
  }
  request.set("samples", samples.to_json())
  request.set("end", 2.0e-13.to_json())
  let converted = cohort_study(request.to_json().stringify())
  assert_eq(
    study_fields(original)["global_p_exact"],
    study_fields(converted)["global_p_exact"],
  )
  let a = study_rows(original, "rows")
  let b = study_rows(converted, "rows")
  for i = 0; i < a.length(); i = i + 1 {
    assert_eq(study_fields(a[i])["p_raw"], study_fields(b[i])["p_raw"])
    assert_eq(
      study_fields(a[i])["p_max_adjusted"],
      study_fields(b[i])["p_max_adjusted"],
    )
  }
}
