///|
test "solid 2x2x2 cubical volume has one cube and no void" {
  let volume = Array::makei(2, fn(_) {
    Array::makei(2, fn(_) { Array::make(2, 0.0) })
  })
  let filtration = @moontopolens.cubical_volume(volume, threshold=0.0)
  assert_eq(filtration.cells.length(), 27)
  assert_eq(filtration.vertex_count, 8)
  @moontopolens.validate_filtration(filtration)
  let result = @moontopolens.analyze(filtration, max_homology_dimension=2)
  assert_eq(@moontopolens.betti(result, 0, 0.0), 1)
  assert_eq(@moontopolens.betti(result, 1, 0.0), 0)
  assert_eq(@moontopolens.betti(result, 2, 0.0), 0)
}

///|
test "hollow 3x3x3 shell has H2 void that dies when center enters" {
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
  let result = @moontopolens.analyze(
    @moontopolens.cubical_volume(volume, threshold=1.0),
    max_homology_dimension=2,
  )
  assert_eq(result.filtration.cells.length(), 125)
  assert_eq(@moontopolens.betti(result, 0, 0.0), 1)
  assert_eq(@moontopolens.betti(result, 1, 0.0), 0)
  assert_eq(@moontopolens.betti(result, 2, 0.0), 1)
  assert_eq(@moontopolens.betti(result, 2, 1.0), 0)
  assert_eq(@moontopolens.diagram(result, 2), [(0.0, 1.0)])
  assert_true(
    @moontopolens.volume_slices_html(result).contains("三维体素切片"),
  )
}

///|
test "volume JSON defaults to H2 and rejects invalid shape or budget" {
  let text = "{\"kind\":\"volume\",\"threshold\":0,\"volume\":[[[0,0],[0,0]],[[0,0],[0,0]]]}"
  let result = @moontopolens.analyze_json(text)
  assert_eq(result.homology_dimension, 2)
  assert_eq(result.filtration.kind, "cubical_volume")
  assert_eq(result.filtration.positions[7], [1.0, -1.0, 1.0])
  let invalid = [
    "{\"kind\":\"volume\",\"threshold\":0,\"volume\":[]}", "{\"kind\":\"volume\",\"threshold\":0,\"volume\":[[[0,0]],[[0]]]}",
    "{\"kind\":\"volume\",\"threshold\":0,\"volume\":[[[0,0],[0,0]],[[0,0],[0,0]]],\"homology_dimension\":1}",
    "{\"kind\":\"volume\",\"threshold\":0,\"max_cells\":10,\"volume\":[[[0,0],[0,0]],[[0,0],[0,0]]]}",
  ]
  for request in invalid {
    let rejected = try {
      ignore(@moontopolens.analyze_json(request))
      false
    } catch {
      _ => true
    }
    assert_true(rejected)
  }
}
