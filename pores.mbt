///|
fn pore_neighbors(i : Int32, w : Int32, h : Int32, d : Int32) -> Array[Int32] {
  let x = i % w
  let y = i / w % h
  let z = i / (w * h)
  [
    if x > 0 {
      i - 1
    } else {
      -1
    },
    if x + 1 < w {
      i + 1
    } else {
      -1
    },
    if y > 0 {
      i - w
    } else {
      -1
    },
    if y + 1 < h {
      i + w
    } else {
      -1
    },
    if z > 0 {
      i - w * h
    } else {
      -1
    },
    if z + 1 < d {
      i + w * h
    } else {
      -1
    },
  ]
}

///|
/// Exact separable min-plus distance to axis-aligned solid voxel boxes.
fn pore_distances(
  mask : Array[Bool],
  w : Int32,
  h : Int32,
  d : Int32,
  spacing : Array[Double],
) -> Array[Double] {
  let mut distance = mask.map(fn(pore) { if pore { 1.0e100 } else { 0.0 } })
  for axis = 0; axis < 3; axis = axis + 1 {
    let length = [w, h, d][axis]
    let stride = [1, w, w * h][axis]
    let next = Array::make(mask.length(), 1.0e100)
    for i = 0; i < mask.length(); i = i + 1 {
      let coordinate = i / stride % length
      let begin = i - coordinate * stride
      for j = 0; j < length; j = j + 1 {
        let delta = maximum(0.0, (coordinate - j).abs().to_double() - 0.5) *
          spacing[axis]
        let candidate = distance[begin + j * stride] + delta * delta
        if candidate < next[i] {
          next[i] = candidate
        }
      }
    }
    distance = next
  }
  distance.map(fn(v) { if v >= 1.0e99 { 1.0e100 } else { v.sqrt() } })
}

///|
fn pore_labels(
  mask : Array[Bool],
  w : Int32,
  h : Int32,
  d : Int32,
) -> (Array[Int32], Array[Array[Int32]]) raise TopologyError {
  let labels = Array::make(mask.length(), 0)
  let components : Array[Array[Int32]] = []
  for start = 0; start < mask.length(); start = start + 1 {
    if !mask[start] || labels[start] != 0 {
      continue
    }
    if components.length() >= 1024 {
      raise TopologyError("pore segmentation exceeds 1024 components")
    }
    let queue = [start]
    labels[start] = components.length() + 1
    let mut head = 0
    while head < queue.length() {
      let i = queue[head]
      head += 1
      for j in pore_neighbors(i, w, h, d) {
        if j >= 0 && mask[j] && labels[j] == 0 {
          labels[j] = labels[start]
          queue.push(j)
        }
      }
    }
    components.push(queue)
  }
  (labels, components)
}

///|
fn pore_spans(
  cells : Array[Int32],
  w : Int32,
  h : Int32,
  d : Int32,
) -> Array[Bool] {
  let faces = Array::make(6, false)
  for i in cells {
    let x = i % w
    let y = i / w % h
    let z = i / (w * h)
    if x == 0 {
      faces[0] = true
    }
    if x == w - 1 {
      faces[1] = true
    }
    if y == 0 {
      faces[2] = true
    }
    if y == h - 1 {
      faces[3] = true
    }
    if z == 0 {
      faces[4] = true
    }
    if z == d - 1 {
      faces[5] = true
    }
  }
  faces
}

///|
/// Cell-centered segmentation, distinct from the vertex lower-star H2 model.
pub fn pore_study(text : String) -> Json raise TopologyError {
  let f = research_object(text, "pores", [
    "volume", "threshold", "polarity", "spacing", "origin", "unit", "radii",
  ])
  let volume : Array[Array[Array[Double]]] = @json.from_json(
    required_field(f, "volume"),
  ) catch {
    _ => raise TopologyError("invalid pore volume")
  }
  let d = volume.length()
  if d < 1 || d > 64 {
    raise TopologyError("pore depth must be 1..64")
  }
  let h = volume[0].length()
  if h < 1 || h > 64 {
    raise TopologyError("pore height must be 1..64")
  }
  let w = volume[0][0].length()
  if w < 1 || w > 64 {
    raise TopologyError("pore width must be 1..64")
  }
  let spacing = research_numbers(f, "spacing", [1.0, 1.0, 1.0])
  let origin = research_numbers(f, "origin", [0.0, 0.0, 0.0])
  if spacing.length() != 3 || origin.length() != 3 {
    raise TopologyError("spacing and origin require three values")
  }
  for v in spacing {
    if v < 1.0e-6 || v > 1.0e6 {
      raise TopologyError("spacing must be 1e-6..1e6")
    }
  }
  for v in origin {
    if v.abs() > 1.0e12 {
      raise TopologyError("origin out of range")
    }
  }
  let unit = research_string(f, "unit", "voxel")
  if unit == "" || unit.length() > 80 {
    raise TopologyError("invalid pore unit")
  }
  let threshold = research_number(f, "threshold", 0.5)
  let polarity = research_string(f, "polarity", "high")
  if polarity != "high" && polarity != "low" {
    raise TopologyError("polarity must be high or low")
  }
  let mask : Array[Bool] = []
  for plane in volume {
    if plane.length() != h {
      raise TopologyError("inconsistent pore height")
    }
    for row in plane {
      if row.length() != w {
        raise TopologyError("inconsistent pore width")
      }
      for v in row {
        if !finite(v) || v.abs() > 1.0e100 {
          raise TopologyError("invalid pore intensity")
        }
        mask.push(
          if polarity == "high" {
            v >= threshold
          } else {
            v <= threshold
          },
        )
      }
    }
  }
  let (labels, components) = pore_labels(mask, w, h, d)
  let distances = pore_distances(mask, w, h, d, spacing)
  let ball = Array::make(mask.length(), 0.0)
  let voxel_volume = spacing[0] * spacing[1] * spacing[2]
  let face_area = [
    spacing[1] * spacing[2],
    spacing[1] * spacing[2],
    spacing[0] * spacing[2],
    spacing[0] * spacing[2],
    spacing[0] * spacing[1],
    spacing[0] * spacing[1],
  ]
  let regions : Array[Json] = []
  let mut pore_count = 0
  let mut open_count = 0
  let mut enclosed_count = 0
  let mut face_count = 0
  for r, cells in components {
    pore_count += cells.length()
    let faces = pore_spans(cells, w, h, d)
    let open = faces.contains(true)
    if open {
      open_count += 1
    } else {
      enclosed_count += 1
    }
    let lower = [w, h, d]
    let upper = [0, 0, 0]
    let centroid = [0.0, 0.0, 0.0]
    let mut interface_area = 0.0
    let mut crop_area = 0.0
    let mut radius = 0.0
    let mut center = cells[0]
    for i in cells {
      let xyz = [i % w, i / w % h, i / (w * h)]
      let mut clearance = distances[i]
      for axis = 0; axis < 3; axis = axis + 1 {
        let p = xyz[axis]
        if p < lower[axis] {
          lower[axis] = p
        }
        if p > upper[axis] {
          upper[axis] = p
        }
        centroid[axis] += (origin[axis] + p.to_double() * spacing[axis]) /
          cells.length().to_double()
        let edge_distance = maximum(
          0.0,
          (minimum_int(p, [w, h, d][axis] - 1 - p).to_double() + 0.5) *
          spacing[axis],
        )
        if edge_distance < clearance {
          clearance = edge_distance
        }
      }
      ball[i] = clearance
      if clearance > radius {
        radius = clearance
        center = i
      }
      for axis, j in pore_neighbors(i, w, h, d) {
        if j < 0 {
          crop_area += face_area[axis]
          face_count += 1
        } else if !mask[j] {
          interface_area += face_area[axis]
          face_count += 1
        }
      }
    }
    regions.push({
      "label": r + 1,
      "voxel_count": cells.length(),
      "volume": cells.length().to_double() * voxel_volume,
      "centroid": centroid,
      "bbox_index_min": lower,
      "bbox_index_max": upper,
      "bbox_world_min": Array::makei(3, fn(a) {
        origin[a] + (lower[a].to_double() - 0.5) * spacing[a]
      }),
      "bbox_world_max": Array::makei(3, fn(a) {
        origin[a] + (upper[a].to_double() + 0.5) * spacing[a]
      }),
      "touches_crop": open,
      "boundary_faces": faces,
      "spans_xyz": [
        faces[0] && faces[1],
        faces[2] && faces[3],
        faces[4] && faces[5],
      ],
      "solid_interface_area": interface_area,
      "crop_cap_area": crop_area,
      "contained_ball_radius_at_voxel_center": radius,
      "ball_center_index": center,
    })
  }
  let radii = research_numbers(f, "radii", [0.0])
  if radii.length() < 1 || radii.length() > 8 {
    raise TopologyError("use 1..8 clearance radii")
  }
  let has_solid = mask.contains(false)
  let connectivity : Array[Json] = []
  for radius in radii {
    if radius < 0.0 || radius > 1.0e9 {
      raise TopologyError("invalid clearance radius")
    }
    let selected = Array::makei(mask.length(), fn(i) {
      mask[i] && (radius == 0.0 || (has_solid && distances[i] >= radius))
    })
    let (_, parts) = pore_labels(selected, w, h, d)
    let spans = [false, false, false]
    for cells in parts {
      let faces = pore_spans(cells, w, h, d)
      for axis = 0; axis < 3; axis = axis + 1 {
        if faces[axis * 2] && faces[axis * 2 + 1] {
          spans[axis] = true
        }
      }
    }
    connectivity.push({
      "radius": radius,
      "available": radius == 0.0 || has_solid,
      "component_count": parts.length(),
      "spans_xyz": spans,
    })
  }
  {
    "kind": "pores",
    "request": f.to_json(),
    "shape_xyz": [w, h, d],
    "spacing": spacing,
    "origin": origin,
    "unit": unit,
    "threshold": threshold,
    "polarity": polarity,
    "voxel_volume": voxel_volume,
    "pore_fraction": pore_count.to_double() / mask.length().to_double(),
    "pore_volume": pore_count.to_double() * voxel_volume,
    "open_components": open_count,
    "enclosed_components": enclosed_count,
    "rows": regions,
    "labels": labels,
    "solid_clearance": Array::makei(mask.length(), fn(i) {
      if !mask[i] || distances[i] >= 1.0e99 {
        Json::null()
      } else {
        distances[i].to_json()
      }
    }),
    "contained_ball_radius": ball,
    "clearance_connectivity": connectivity,
    "surface_faces": face_count,
    "interpretation": "cell-centered thresholded voxels with 6-neighbor void connectivity; origin is voxel (0,0,0) center; enclosed components are segmentation regions, not automatically H2 intervals; exact distances from voxel centers to observed axis-aligned solid boxes; contained balls also bounded by crop, centers restricted to voxel centers; clearance paths use observed solids only and cropped exterior is unknown; not a permeability estimate",
  }
}

///|
pub fn pore_surface_obj(report : Json) -> String raise TopologyError {
  let f = batch_object(report, "pore report")
  let shape : Array[Int32] = @json.from_json(required_field(f, "shape_xyz")) catch {
    _ => raise TopologyError("invalid pore shape")
  }
  let labels : Array[Int32] = @json.from_json(required_field(f, "labels")) catch {
    _ => raise TopologyError("invalid labels")
  }
  let spacing = research_numbers(f, "spacing", [])
  let origin = research_numbers(f, "origin", [])
  if shape.length() != 3 || spacing.length() != 3 || origin.length() != 3 {
    raise TopologyError("invalid pore geometry")
  }
  let w = shape[0]
  let h = shape[1]
  let d = shape[2]
  if w < 1 ||
    h < 1 ||
    d < 1 ||
    w > 64 ||
    h > 64 ||
    d > 64 ||
    labels.length() != w * h * d {
    raise TopologyError("invalid pore geometry size")
  }
  for v in spacing {
    if v <= 0.0 || v > 1.0e6 {
      raise TopologyError("invalid surface spacing")
    }
  }
  let offsets : Array[Array[Array[Double]]] = [
    [[-0.5, -0.5, -0.5], [-0.5, -0.5, 0.5], [-0.5, 0.5, 0.5], [-0.5, 0.5, -0.5]],
    [[0.5, -0.5, -0.5], [0.5, 0.5, -0.5], [0.5, 0.5, 0.5], [0.5, -0.5, 0.5]],
    [[-0.5, -0.5, -0.5], [0.5, -0.5, -0.5], [0.5, -0.5, 0.5], [-0.5, -0.5, 0.5]],
    [[-0.5, 0.5, -0.5], [-0.5, 0.5, 0.5], [0.5, 0.5, 0.5], [0.5, 0.5, -0.5]],
    [[-0.5, -0.5, -0.5], [-0.5, 0.5, -0.5], [0.5, 0.5, -0.5], [0.5, -0.5, -0.5]],
    [[-0.5, -0.5, 0.5], [0.5, -0.5, 0.5], [0.5, 0.5, 0.5], [-0.5, 0.5, 0.5]],
  ]
  let mut text = "# MoonTopoLens voxel pore surface; duplicated face vertices; world coordinates\n"
  let mut faces = 0
  for i, label in labels {
    if label <= 0 {
      continue
    }
    let xyz = [i % w, i / w % h, i / (w * h)]
    for axis, j in pore_neighbors(i, w, h, d) {
      if j >= 0 && labels[j] > 0 {
        continue
      }
      if faces >= 20000 {
        raise TopologyError(
          "OBJ export exceeds 20000 faces; report and labels remain available through library",
        )
      }
      text += "g pore_\{label}\n"
      for corner in offsets[axis] {
        let p = Array::makei(3, fn(a) {
          origin[a] + (xyz[a].to_double() + corner[a]) * spacing[a]
        })
        text += "v \{p[0]} \{p[1]} \{p[2]}\n"
      }
      let base = faces * 4 + 1
      text += "f \{base} \{base+1} \{base+2}\nf \{base} \{base+2} \{base+3}\n"
      faces += 1
    }
  }
  text
}

///|
pub fn pore_compare(left : Json, right : Json) -> Json raise TopologyError {
  let a = batch_object(left, "left pore report")
  let b = batch_object(right, "right pore report")
  for key in ["shape_xyz", "spacing", "origin", "unit"] {
    if required_field(a, key) != required_field(b, key) {
      raise TopologyError(
        "pore overlap comparison requires the same world grid and units",
      )
    }
  }
  let la : Array[Int32] = @json.from_json(required_field(a, "labels")) catch {
    _ => raise TopologyError("invalid left labels")
  }
  let lb : Array[Int32] = @json.from_json(required_field(b, "labels")) catch {
    _ => raise TopologyError("invalid right labels")
  }
  if la.length() != lb.length() || la.length() > 262144 {
    raise TopologyError("invalid pore label lengths")
  }
  let overlaps : Map[String, Int32] = Map([])
  let counts_a : Map[Int32, Int32] = Map([])
  let counts_b : Map[Int32, Int32] = Map([])
  let outgoing : Map[Int32, Array[Int32]] = Map([])
  let incoming : Map[Int32, Array[Int32]] = Map([])
  for i, x in la {
    let y = lb[i]
    if x > 0 {
      counts_a[x] = counts_a.get(x).unwrap_or(0) + 1
    }
    if y > 0 {
      counts_b[y] = counts_b.get(y).unwrap_or(0) + 1
    }
    if x > 0 && y > 0 {
      let key = "\{x}:\{y}"
      overlaps[key] = overlaps.get(key).unwrap_or(0) + 1
      if !outgoing.contains(x) {
        outgoing[x] = []
      }
      if !incoming.contains(y) {
        incoming[y] = []
      }
      if !outgoing[x].contains(y) {
        outgoing[x].push(y)
      }
      if !incoming[y].contains(x) {
        incoming[y].push(x)
      }
    }
  }
  let rows : Array[Json] = []
  let keys = overlaps.keys().to_array()
  keys.sort()
  for key in keys {
    let parts = key.split(":").to_array()
    let x : Int32 = @json.from_json(@json.parse(parts[0].to_owned())) catch {
      _ => raise TopologyError("invalid overlap")
    }
    let y : Int32 = @json.from_json(@json.parse(parts[1].to_owned())) catch {
      _ => raise TopologyError("invalid overlap")
    }
    let intersection = overlaps[key]
    rows.push({
      "left_label": x,
      "right_label": y,
      "intersection_voxels": intersection,
      "iou": intersection.to_double() /
      (counts_a[x] + counts_b[y] - intersection).to_double(),
      "split_candidate": outgoing[x].length() > 1,
      "merge_candidate": incoming[y].length() > 1,
    })
  }
  let disappeared = counts_a
    .keys()
    .to_array()
    .filter(fn(x) { !outgoing.contains(x) })
  disappeared.sort()
  let appeared = counts_b
    .keys()
    .to_array()
    .filter(fn(x) { !incoming.contains(x) })
  appeared.sort()
  {
    "kind": "pore_compare",
    "rows": rows,
    "disappeared_labels": disappeared,
    "appeared_labels": appeared,
    "pore_volume_change": number_field(b, "pore_volume") -
    number_field(a, "pore_volume"),
    "pore_fraction_change": number_field(b, "pore_fraction") -
    number_field(a, "pore_fraction"),
    "interpretation": "spatial label overlap on an identical declared world grid; split/merge candidates are overlap relations, not persistent-homology tracks or physical identity proofs",
  }
}

///|
/// Axis-aligned positive NIfTI geometry; rotated/sheared/flipped grids require resampling first.
pub fn pore_nifti_request(
  study : NiftiStudy,
  config : String,
) -> Json raise TopologyError {
  let f = research_object(config, "pores", ["threshold", "polarity", "radii"]).copy()
  if study.volumes.length() != 1 {
    raise TopologyError("pore NIfTI input must contain one frame")
  }
  if study.affine.length() != 3 ||
    study.affine.any(fn(row) {
      row.length() != 4 || row.any(fn(v) { !finite(v) })
    }) {
    raise TopologyError("invalid NIfTI affine shape or values")
  }
  let spacing : Array[Double] = []
  let origin : Array[Double] = []
  for i = 0; i < 3; i = i + 1 {
    for j = 0; j < 3; j = j + 1 {
      if i != j && study.affine[i][j].abs() > 1.0e-10 {
        raise TopologyError(
          "pore NIfTI requires positive axis-aligned geometry; resample rotated or sheared input first",
        )
      }
    }
    if study.affine[i][i] <= 0.0 {
      raise TopologyError(
        "pore NIfTI requires positive voxel axes; reorient flipped input first",
      )
    }
    spacing.push(study.affine[i][i])
    origin.push(study.affine[i][3])
  }
  let unit = match study.spatial_units {
    1 => "m"
    2 => "mm"
    3 => "um"
    _ => "NIfTI_unit_unspecified"
  }
  f.set("volume", study.volumes[0].to_json())
  f.set("spacing", spacing.to_json())
  f.set("origin", origin.to_json())
  f.set("unit", unit.to_json())
  f.to_json()
}
