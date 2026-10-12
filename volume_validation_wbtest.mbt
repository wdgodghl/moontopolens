///|
fn validation_shell() -> Analysis raise TopologyError {
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
  analyze(cubical_volume(volume, threshold=1.0), max_homology_dimension=2)
}

///|
test "world H2 corners apply scale translation and reflected slice axis" {
  let analysis = validation_shell()
  let world = volume_h2_world_surfaces_json(analysis, [
    [2.0, 0.0, 0.0, 10.0],
    [0.0, 3.0, 0.0, 20.0],
    [0.0, 0.0, -4.0, 30.0],
  ])
  let fields = batch_object(world, "world")
  let surfaces = batch_array(fields, "surfaces", true)
  assert_eq(surfaces.length(), 1)
  let surface = batch_object(surfaces[0], "surface")
  let faces = batch_array(surface, "faces", true)
  assert_true(faces.length() > 0)
  let mut count = 0
  for face in faces {
    let face = batch_object(face, "face")
    for corner in batch_array(face, "world_corners", true) {
      let p : Array[Double] = @json.from_json(corner)
      assert_eq(p.length(), 3)
      assert_true(p[0] == 10.0 || p[0] == 12.0 || p[0] == 14.0)
      assert_true(p[1] == 20.0 || p[1] == 23.0 || p[1] == 26.0)
      assert_true(p[2] == 30.0 || p[2] == 26.0 || p[2] == 22.0)
      count += 1
    }
  }
  assert_eq(count, faces.length() * 4)
  assert_eq(diagram(analysis, 2), [(0.0, 1.0)])
}

///|
test "world surfaces reject malformed nonfinite and overflowing affines" {
  let analysis = validation_shell()
  let invalid = [
    [],
    [[1.0], [1.0], [1.0]],
    [[1.0 / 0.0, 0.0, 0.0, 0.0], [0.0, 1.0, 0.0, 0.0], [0.0, 0.0, 1.0, 0.0]],
    [[1.0e308, 0.0, 0.0, 1.0e308], [0.0, 1.0, 0.0, 0.0], [0.0, 0.0, 1.0, 0.0]],
  ]
  for affine in invalid {
    let rejected = try {
      ignore(volume_h2_world_surfaces_json(analysis, affine))
      false
    } catch {
      _ => true
    }
    assert_true(rejected)
  }
  let solid = Array::makei(2, fn(_) {
    Array::makei(2, fn(_) { Array::make(2, 0.0) })
  })
  let h1 = analyze(cubical_volume(solid, threshold=0.0))
  let rejected = try {
    ignore(
      volume_h2_world_surfaces_json(h1, [
        [1.0, 0.0, 0.0, 0.0],
        [0.0, 1.0, 0.0, 0.0],
        [0.0, 0.0, 1.0, 0.0],
      ]),
    )
    false
  } catch {
    _ => true
  }
  assert_true(rejected)
}

///|
test "NIfTI study validates bytes before normalizing frame headers" {
  // dim[4] is normalized for a 3D study. Invalid source bytes must still fail.
  let bytes = Array::make(360, 0)
  bytes[0] = 92
  bytes[1] = 1
  bytes[40] = 3
  bytes[42] = 2
  bytes[44] = 2
  bytes[46] = 2
  bytes[70] = 2
  bytes[72] = 8
  bytes[83] = 63
  bytes[82] = 128
  bytes[87] = 63
  bytes[86] = 128
  bytes[91] = 63
  bytes[90] = 128
  bytes[110] = 176
  bytes[111] = 67
  bytes[344] = 110
  bytes[345] = 43
  bytes[346] = 49
  assert_eq(parse_nifti1_study(bytes).volumes.length(), 1)
  for invalid in [-1, 256] {
    bytes[48] = invalid
    let rejected = try {
      ignore(parse_nifti1_study(bytes))
      false
    } catch {
      _ => true
    }
    assert_true(rejected)
  }
}
