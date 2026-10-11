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
      for cell_index in interval.representative {
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
