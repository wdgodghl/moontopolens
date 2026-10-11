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
  for index, interval in analysis.intervals {
    if interval.dimension == 2 {
      let simple = @moontopolens.simplify_representative(analysis, index)
      assert_true(simple.length() <= interval.representative.length())
      let boundary : Map[Int, Bool] = Map([])
      for face in simple {
        for edge in analysis.filtration.cells[face].boundary {
          boundary[edge] = !boundary.get(edge).unwrap_or(false)
        }
      }
      for value in boundary.values() {
        assert_eq(value, false)
      }
    }
  }
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

///|
test "NIfTI-1 4D study reads time frames and sform" {
  let bytes = Array::make(368, 0)
  bytes[0] = 92
  bytes[1] = 1
  bytes[40] = 4
  bytes[42] = 2
  bytes[44] = 2
  bytes[46] = 2
  bytes[48] = 2
  bytes[70] = 2
  bytes[72] = 8
  bytes[82] = 128
  bytes[83] = 63
  bytes[86] = 128
  bytes[87] = 63
  bytes[90] = 128
  bytes[91] = 63
  bytes[94] = 192
  bytes[95] = 63
  bytes[110] = 176
  bytes[111] = 67
  bytes[138] = 0
  bytes[139] = 64
  bytes[123] = 10
  bytes[254] = 1
  bytes[282] = 0
  bytes[283] = 64
  bytes[294] = 32
  bytes[295] = 65
  bytes[302] = 64
  bytes[303] = 64
  bytes[310] = 160
  bytes[311] = 65
  bytes[322] = 128
  bytes[323] = 64
  bytes[326] = 240
  bytes[327] = 65
  bytes[344] = 110
  bytes[345] = 43
  bytes[346] = 49
  bytes[360] = 7
  let study = @moontopolens.parse_nifti1_study(bytes)
  assert_eq(study.volumes.length(), 2)
  assert_eq(study.volumes[1][0][0][0], 7.0)
  assert_eq(study.affine[0], [2.0, 0.0, 0.0, 10.0])
  assert_eq(study.affine[1], [0.0, 3.0, 0.0, 20.0])
  assert_eq(study.affine[2], [0.0, 0.0, 4.0, 30.0])
  assert_eq(study.time_step, 1.5)
  assert_eq(study.time_offset, 2.0)
  assert_eq(study.spatial_units, 2)
  assert_eq(study.temporal_units, 1)
  assert_true(
    @moontopolens.nifti_study_metadata(study)
    .stringify()
    .contains("\"transform_source\":\"sform\""),
  )
}

///|
test "NIfTI qform honors negative slice direction" {
  let bytes = Array::make(360, 0)
  bytes[0] = 92
  bytes[1] = 1
  bytes[40] = 3
  bytes[42] = 2
  bytes[44] = 2
  bytes[46] = 2
  bytes[70] = 2
  bytes[72] = 8
  bytes[79] = 192 // pixdim[0] = -1, the qfac sign
  bytes[82] = 0
  bytes[83] = 64 // pixdim[1] = 2
  bytes[86] = 64
  bytes[87] = 64 // pixdim[2] = 3
  bytes[90] = 128
  bytes[91] = 64 // pixdim[3] = 4
  bytes[110] = 176
  bytes[111] = 67 // vox_offset = 352
  bytes[252] = 1 // qform_code
  bytes[344] = 110
  bytes[345] = 43
  bytes[346] = 49
  let study = @moontopolens.parse_nifti1_study(bytes)
  assert_eq(study.affine[0], [2.0, 0.0, 0.0, 0.0])
  assert_eq(study.affine[1], [0.0, 3.0, 0.0, 0.0])
  assert_eq(study.affine[2], [0.0, 0.0, -4.0, 0.0])
  assert_eq(study.transform_source, "qform")
}

///|
test "volume resampling preserves stride one and bounds coarse cost" {
  let volume = Array::makei(8, fn(z) {
    Array::makei(8, fn(y) {
      Array::makei(8, fn(x) { (z * 64 + y * 8 + x).to_double() })
    })
  })
  let same = @moontopolens.resample_volume(volume, 1)
  assert_eq(same, volume)
  let sampled = @moontopolens.resample_volume(volume, 3, sampling="sample")
  assert_eq(sampled.length(), 4)
  assert_eq(sampled[3][3][3], volume[7][7][7])
  let (result, stride) = @moontopolens.analyze_volume_coarse(
    volume,
    threshold=511.0,
    max_cells=1000,
  )
  assert_true(stride > 1)
  assert_true(result.filtration.cells.length() <= 1000)
}
