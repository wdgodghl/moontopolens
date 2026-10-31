///|
test "public capability limits agree with accepted and rejected point inputs" {
  assert_eq(boundary_dense_points, 128)
  assert_eq(boundary_sparse_points, 8192)
  assert_eq(boundary_maximum_cells, 10000)
  for n in [127, 128] {
    assert_eq(
      analyze(rips(Array::makei(n, fn(i) { [i.to_double()] }), threshold=0.0)).filtration.vertex_count,
      n,
    )
  }
  study_reject(fn() raise TopologyError {
    ignore(rips(Array::makei(129, fn(i) { [i.to_double()] }), threshold=0.0))
  })
  assert_eq(
    analyze(
      rips_sparse(Array::makei(8192, fn(i) { [i.to_double()] }), threshold=0.0),
    ).filtration.vertex_count,
    8192,
  )
  study_reject(fn() raise TopologyError {
    ignore(
      rips_sparse(Array::makei(8193, fn(i) { [i.to_double()] }), threshold=0.0),
    )
  })
  ignore(rips([Array::make(32, 0.0)], threshold=0.0))
  study_reject(fn() raise TopologyError {
    ignore(rips([Array::make(33, 0.0)], threshold=0.0))
  })
}

///|
test "cell limits accept exact boundary and never silently reduce input" {
  let points = [[0.0, 0.0], [1.0, 0.0], [0.0, 1.0]]
  assert_eq(rips(points, threshold=2.0, max_cells=7).cells.length(), 7)
  study_reject(fn() raise TopologyError {
    ignore(rips(points, threshold=2.0, max_cells=6))
  })
  ignore(rips(points, threshold=2.0, max_cells=10000))
  study_reject(fn() raise TopologyError {
    ignore(rips(points, threshold=2.0, max_cells=10001))
  })
  assert_eq(rips(points, threshold=0.0, max_cells=3).vertex_count, 3)
}

///|
test "grid volume and pore axis boundaries have distinct contracts" {
  ignore(cubical_grid([Array::make(64, 1.0)], threshold=0.0))
  study_reject(fn() raise TopologyError {
    ignore(cubical_grid([Array::make(65, 1.0)], threshold=0.0))
  })
  ignore(
    cubical_volume(
      Array::makei(32, fn(_) { [[1.0, 1.0], [1.0, 1.0]] }),
      threshold=0.0,
    ),
  )
  study_reject(fn() raise TopologyError {
    ignore(
      cubical_volume(
        Array::makei(33, fn(_) { [[1.0, 1.0], [1.0, 1.0]] }),
        threshold=0.0,
      ),
    )
  })
  ignore(pore_study(study_pore([[Array::make(64, 0.0)]]).stringify()))
  study_reject(fn() raise TopologyError {
    ignore(pore_study(study_pore([[Array::make(65, 0.0)]]).stringify()))
  })
}

///|
test "point relabeling and translation preserve diagrams across tied and duplicate data" {
  for seed = 0; seed < 8; seed = seed + 1 {
    let points = Array::makei(6, fn(i) {
      [((i * 3 + seed) % 5).to_double(), ((i * i + seed) % 4).to_double()]
    })
    let original = analyze(
      rips(points, threshold=8.0, max_dimension=3),
      max_homology_dimension=2,
    )
    let reordered = Array::makei(6, fn(i) {
      points[5 - i].map(fn(v) { v + 1024.0 })
    })
    let changed = analyze(
      rips(reordered, threshold=8.0, max_dimension=3),
      max_homology_dimension=2,
    )
    for dimension in [0, 1, 2] {
      assert_eq(compare_analyses(original, changed, dimension~), Some(0.0))
    }
  }
}

///|
test "positive unit conversions preserve intervals and finite landscape scaling" {
  let points = [[0.0, 0.0], [1.0, 0.0], [1.0, 1.0], [0.0, 1.0]]
  let a = analyze(rips(points, threshold=2.0))
  let base = persistence_landscape(
      a,
      dimension=1,
      start=0.0,
      end=2.0,
      samples=31,
      layers=1,
    )[0]
  for factor in [1.0e-6, 1000000.0] {
    let b = analyze(
      rips(
        points.map(fn(row) { row.map(fn(v) { v * factor }) }),
        threshold=2.0 * factor,
      ),
    )
    let scaled = persistence_landscape(
        b,
        dimension=1,
        start=0.0,
        end=2.0 * factor,
        samples=31,
        layers=1,
      )[0]
    for i = 0; i < 31; i = i + 1 {
      assert_true((base[i] - scaled[i] / factor).abs() < 1.0e-12)
    }
  }
}

///|
test "result contract distinguishes not computed empty observed and censored" {
  let a = analyze(rips([[0.0, 0.0]], threshold=0.0), representatives=false)
  let report = study_fields(report_json(a))
  assert_eq(report["schema_version"], Json(1))
  let contract = study_fields(report["result_contract"])
  let dims = study_rows(Json(contract), "dimensions")
  assert_eq(study_fields(dims[0])["status"], Json("observed"))
  assert_eq(study_fields(dims[0])["alive_at_cutoff"], Json(1))
  assert_eq(study_fields(dims[1])["status"], Json("empty"))
  assert_eq(study_fields(dims[2])["status"], Json("not_computed"))
  assert_eq(study_fields(dims[2])["finite_intervals"], Json::null())
  assert_eq(study_fields(dims[0])["representatives"], Json("not_computed"))
  assert_eq(contract["study_design_verified"], Json(false))
}

///|
test "approximation stays explicit in numeric and visible reports" {
  let a = analyze(rips([[0.0]], threshold=0.0))
  let source : Json = { "coarsening": { "approximate": true, "stride": 2 } }
  let report = report_json(a, source~)
  assert_eq(
    study_fields(study_fields(report)["result_contract"])["approximation"],
    Json("declared_approximation"),
  )
  assert_true(
    html_report(a, source~).contains("本次使用显式近似输入"),
  )
}
