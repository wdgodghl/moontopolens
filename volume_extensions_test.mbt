///|
test "H2 volume representatives expose boundary faces" {
  let volume = Array::makei(3, fn(z) {
    Array::makei(3, fn(y) {
      Array::makei(3, fn(x) {
        if z == 1 && y == 1 && x == 1 {
          1.0
        } else {
          0.0
        }
      })
    })
  })
  let analysis = @moontopolens.analyze(
    @moontopolens.cubical_volume(volume, threshold=1.0),
    max_homology_dimension=2,
  )
  let surfaces = @moontopolens.volume_h2_surfaces_json(analysis).stringify()
  assert_true(surfaces.contains("\"face_count\":"))
  assert_true(surfaces.contains("\"corners\":"))
  assert_true(surfaces.contains("\"interval_index\":"))
}

///|
test "sparse 20 cube is accepted under cell budget" {
  let volume = Array::makei(20, fn(z) {
    Array::makei(20, fn(y) {
      Array::makei(20, fn(x) {
        if z == 0 && y == 0 && x == 0 {
          0.0
        } else {
          1.0
        }
      })
    })
  })
  let result = @moontopolens.analyze(
    @moontopolens.cubical_volume(volume, threshold=0.0),
    max_homology_dimension=2,
  )
  assert_eq(result.filtration.cells.length(), 1)
  assert_eq(@moontopolens.betti(result, 0, 0.0), 1)
}

///|
test "volume sequence tracks a cavity disappearance and return" {
  let hollow = "[[[0,0,0],[0,0,0],[0,0,0]],[[0,0,0],[0,1,0],[0,0,0]],[[0,0,0],[0,0,0],[0,0,0]]]"
  let solid = "[[[0,0,0],[0,0,0],[0,0,0]],[[0,0,0],[0,0,0],[0,0,0]],[[0,0,0],[0,0,0],[0,0,0]]]"
  let request = "{\"kind\":\"volume_sequence\",\"threshold\":1,\"frames\":[{\"name\":\"before\",\"volume\":" +
    hollow +
    "},{\"name\":\"filled\",\"volume\":" +
    solid +
    "},{\"name\":\"after\",\"volume\":" +
    hollow +
    "}]}"
  let report = @moontopolens.volume_sequence_json(request)
  let text = report.stringify()
  assert_true(text.contains("\"frame_count\":3"))
  assert_true(text.contains("\"disappeared_h2\":1"))
  assert_true(text.contains("\"appeared_h2\":1"))
  assert_true(
    @moontopolens.volume_sequence_html(report).contains("三维拓扑变化"),
  )
}

///|
test "zero intensity perturbation preserves cubical diagrams" {
  let request = "{\"kind\":\"volume\",\"threshold\":1,\"volume\":[[[0,0,0],[0,0,0],[0,0,0]],[[0,0,0],[0,1,0],[0,0,0]],[[0,0,0],[0,0,0],[0,0,0]]]}"
  let report = @moontopolens.field_stability_json(request, 0.0, trials=2)
  assert_true(
    report.stringify().contains("\"bottleneck_by_dimension\":[0,0,0]"),
  )
}

///|
test "NIfTI-1 uint8 header and voxel order" {
  let bytes = Array::make(360, 0)
  bytes[0] = 92
  bytes[1] = 1
  bytes[40] = 3
  bytes[42] = 2
  bytes[44] = 2
  bytes[46] = 2
  bytes[48] = 1
  bytes[70] = 2
  bytes[72] = 8
  bytes[108] = 0
  bytes[109] = 0
  bytes[110] = 176
  bytes[111] = 67
  bytes[344] = 110
  bytes[345] = 43
  bytes[346] = 49
  for i = 0; i < 8; i = i + 1 {
    bytes[352 + i] = i
  }
  let volume = @moontopolens.parse_nifti1(bytes)
  assert_eq(volume[0][0], [0.0, 1.0])
  assert_eq(volume[1][1], [6.0, 7.0])
  bytes[344] = 0
  let rejected = try {
    ignore(@moontopolens.parse_nifti1(bytes))
    false
  } catch {
    _ => true
  }
  assert_true(rejected)
}

///|
test "NIfTI-1 big-endian float32 applies scaling" {
  let bytes = Array::make(384, 0)
  bytes[2] = 1
  bytes[3] = 92
  bytes[41] = 3
  bytes[43] = 2
  bytes[45] = 2
  bytes[47] = 2
  bytes[49] = 1
  bytes[71] = 16
  bytes[73] = 32
  bytes[108] = 67
  bytes[109] = 176
  bytes[112] = 64
  bytes[116] = 63
  bytes[117] = 128
  bytes[344] = 110
  bytes[345] = 43
  bytes[346] = 49
  for i = 0; i < 8; i = i + 1 {
    bytes[352 + i * 4] = 63
    bytes[353 + i * 4] = 128
  }
  let volume = @moontopolens.parse_nifti1(bytes)
  assert_eq(volume[1][1][1], 3.0)
  bytes[71] = 4
  let rejected = try {
    ignore(@moontopolens.parse_nifti1(bytes))
    false
  } catch {
    _ => true
  }
  assert_true(rejected)
}

///|
test "grid intensity stability retains H1 under zero perturbation" {
  let request = "{\"kind\":\"grid\",\"threshold\":1,\"grid\":[[0,0,0],[0,1,0],[0,0,0]]}"
  let result = @moontopolens.field_stability_json(request, 0.0, trials=2)
  assert_true(result.stringify().contains("\"source_kind\":\"grid\""))
  assert_true(result.stringify().contains("\"bottleneck_by_dimension\":[0,0]"))
}
