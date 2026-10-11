///|
/// Birth-time representative face chains for H2 classes in a 3D volume.
/// They are algebraic cycles, not a segmentation or a shortest enclosing shell.
pub fn volume_h2_surfaces_json(analysis : Analysis) -> Json raise TopologyError {
  if analysis.filtration.kind != "cubical_volume" ||
    analysis.homology_dimension < 2 {
    raise TopologyError("H2 surfaces require a three-dimensional volume")
  }
  let result : Array[Json] = []
  for index, interval in analysis.intervals {
    if interval.dimension == 2 {
      let faces : Array[Json] = []
      let simplified = simplify_representative(analysis, index)
      for cell_index in simplified {
        let cell = analysis.filtration.cells[cell_index]
        if cell.dimension != 2 || cell.vertices.length() != 4 {
          raise TopologyError("invalid H2 representative face")
        }
        let corners : Array[Json] = []
        for vertex in cell.vertices {
          corners.push(analysis.filtration.positions[vertex].to_json())
        }
        faces.push({
          "cell_index": cell_index,
          "vertices": cell.vertices,
          "corners": corners,
          "value": cell.value,
        })
      }
      result.push({
        "interval_index": index,
        "birth": interval.birth,
        "death": match interval.death {
          Some(value) => value.to_json()
          None => Json::null()
        },
        "face_count": faces.length(),
        "original_face_count": interval.representative.length(),
        "faces": faces,
      })
    }
  }
  {
    "schema_version": 1,
    "kind": "volume_h2_representatives",
    "cutoff": analysis.filtration.cutoff,
    "surfaces": result,
    "interpretation": "birth-time GF(2) representative face cycles; not a shortest shell or proof of a unique physical cavity",
  }
}

///|
/// Transform H2 representative face corners with a NIfTI voxel-to-world
/// affine. Topology remains on the original voxel grid.
pub fn volume_h2_world_surfaces_json(
  analysis : Analysis,
  affine : Array[Array[Double]],
) -> Json raise TopologyError {
  if analysis.filtration.kind != "cubical_volume" || affine.length() != 3 {
    raise TopologyError("world surfaces require volume and a 3x4 affine")
  }
  for row in affine {
    if row.length() != 4 {
      raise TopologyError("world surfaces require a 3x4 affine")
    }
    for value in row {
      if !finite(value) {
        raise TopologyError("world surface affine must be finite")
      }
    }
  }
  let surfaces : Array[Json] = []
  for index, interval in analysis.intervals {
    if interval.dimension == 2 {
      let faces : Array[Json] = []
      for cell_index in simplify_representative(analysis, index) {
        let corners : Array[Json] = []
        for vertex in analysis.filtration.cells[cell_index].vertices {
          let p = analysis.filtration.positions[vertex]
          let x = p[0]
          let y = -p[1]
          let z = p[2]
          corners.push(
            Array::makei(3, fn(axis) {
              affine[axis][0] * x +
              affine[axis][1] * y +
              affine[axis][2] * z +
              affine[axis][3]
            }).to_json(),
          )
        }
        faces.push({ "cell_index": cell_index, "world_corners": corners })
      }
      surfaces.push({
        "interval_index": index,
        "birth": interval.birth,
        "death": match interval.death {
          Some(value) => value.to_json()
          None => Json::null()
        },
        "faces": faces,
      })
    }
  }
  {
    "schema_version": 1,
    "kind": "volume_h2_world_surfaces",
    "affine_voxel_xyz_to_world": affine,
    "surfaces": surfaces,
    "interpretation": "birth-time representative faces mapped through NIfTI affine; no spatial resampling performed",
  }
}
