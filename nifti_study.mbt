///|
/// NIfTI-1 scalar volumes together with the voxel-index to world affine.
/// No resampling or medical-space reorientation is performed.
pub struct NiftiStudy {
  volumes : Array[Array[Array[Array[Double]]]]
  affine : Array[Array[Double]]
  spatial_units : Int
  temporal_units : Int
  time_step : Double
  time_offset : Double
  transform_source : String
} derive(@debug.Debug)

///|
pub extend NiftiStudy with @debug.Debug::{to_repr}

///|
fn nifti_affine(
  bytes : Array[Int],
  little : Bool,
) -> (Array[Array[Double]], String) raise TopologyError {
  let qform = nifti_u16(bytes, 252, little)
  let sform = nifti_u16(bytes, 254, little)
  if sform > 0 {
    let rows = Array::makei(3, fn(i) {
      Array::makei(4, fn(j) { nifti_f32(bytes, 280 + i * 16 + j * 4, little) })
    })
    for row in rows {
      for value in row {
        if !finite(value) {
          raise TopologyError("non-finite NIfTI sform affine")
        }
      }
    }
    return (rows, "sform")
  }
  let dx = nifti_f32(bytes, 80, little)
  let dy = nifti_f32(bytes, 84, little)
  let dz = nifti_f32(bytes, 88, little)
  if !finite(dx) ||
    !finite(dy) ||
    !finite(dz) ||
    dx <= 0.0 ||
    dy <= 0.0 ||
    dz <= 0.0 {
    raise TopologyError("NIfTI voxel spacing must be positive and finite")
  }
  let qfac = if nifti_f32(bytes, 76, little) < 0.0 { -1.0 } else { 1.0 }
  if qform > 0 {
    let mut b = nifti_f32(bytes, 256, little)
    let mut c = nifti_f32(bytes, 260, little)
    let mut d = nifti_f32(bytes, 264, little)
    let x = nifti_f32(bytes, 268, little)
    let y = nifti_f32(bytes, 272, little)
    let z = nifti_f32(bytes, 276, little)
    if !finite(b) ||
      !finite(c) ||
      !finite(d) ||
      !finite(x) ||
      !finite(y) ||
      !finite(z) {
      raise TopologyError("non-finite NIfTI qform")
    }
    let mut a2 = 1.0 - (b * b + c * c + d * d)
    if a2 < 0.0 {
      let length = (b * b + c * c + d * d).sqrt()
      if length == 0.0 {
        raise TopologyError("invalid NIfTI quaternion")
      }
      b = b / length
      c = c / length
      d = d / length
      a2 = 0.0
    }
    let a = a2.sqrt()
    let dz = dz * qfac
    return (
      [
        [
          (a * a + b * b - c * c - d * d) * dx,
          2.0 * (b * c - a * d) * dy,
          2.0 * (b * d + a * c) * dz,
          x,
        ],
        [
          2.0 * (b * c + a * d) * dx,
          (a * a + c * c - b * b - d * d) * dy,
          2.0 * (c * d - a * b) * dz,
          y,
        ],
        [
          2.0 * (b * d - a * c) * dx,
          2.0 * (c * d + a * b) * dy,
          (a * a + d * d - b * b - c * c) * dz,
          z,
        ],
      ],
      "qform",
    )
  }
  ([[dx, 0.0, 0.0, 0.0], [0.0, dy, 0.0, 0.0], [0.0, 0.0, dz, 0.0]], "pixdim")
}

///|
/// Parse bounded NIfTI-1 .nii bytes with one to eight 3D time frames.
/// The original byte order, slope and intercept are honored per frame.
pub fn parse_nifti1_study(bytes : Array[Int]) -> NiftiStudy raise TopologyError {
  if bytes.length() < 352 || bytes.length() > 1000000 {
    raise TopologyError("NIfTI-1 study must be 352 bytes to 1 MB")
  }
  for byte in bytes {
    if byte < 0 || byte > 255 {
      raise TopologyError("NIfTI bytes must be in [0,255]")
    }
  }
  let little = if nifti_u32(bytes, 0, true) == 348 {
    true
  } else if nifti_u32(bytes, 0, false) == 348 {
    false
  } else {
    raise TopologyError("expected NIfTI-1 348-byte header")
  }
  if bytes[344] != 110 ||
    bytes[345] != 43 ||
    bytes[346] != 49 ||
    bytes[347] != 0 {
    raise TopologyError("NIfTI-1 single-file n+1 magic required")
  }
  let dimension_count = nifti_u16(bytes, 40, little)
  if dimension_count != 3 && dimension_count != 4 {
    raise TopologyError("NIfTI study requires three or four dimensions")
  }
  let frame_count = if dimension_count == 4 {
    nifti_u16(bytes, 48, little)
  } else {
    1
  }
  if frame_count < 1 || frame_count > 8 {
    raise TopologyError("NIfTI study supports one to eight frames")
  }
  let width = nifti_u16(bytes, 42, little)
  let height = nifti_u16(bytes, 44, little)
  let depth = nifti_u16(bytes, 46, little)
  if width < 2 ||
    width > 32 ||
    height < 2 ||
    height > 32 ||
    depth < 2 ||
    depth > 32 {
    raise TopologyError("NIfTI study dimensions must each be 2..32")
  }
  let datatype = nifti_u16(bytes, 70, little)
  let bytes_per_value = match datatype {
    2 => 1
    4 => 2
    8 | 16 => 4
    _ =>
      raise TopologyError(
        "NIfTI study datatype must be uint8/int16/int32/float32",
      )
  }
  if nifti_u16(bytes, 72, little) != bytes_per_value * 8 {
    raise TopologyError("NIfTI study bitpix mismatch")
  }
  let offset_value = nifti_f32(bytes, 108, little)
  if !finite(offset_value) ||
    offset_value < 352.0 ||
    offset_value > 1000000.0 ||
    offset_value != @math.floor(offset_value) {
    raise TopologyError("invalid NIfTI study voxel offset")
  }
  let offset = offset_value.to_int()
  let frame_bytes = width * height * depth * bytes_per_value
  if offset + frame_count * frame_bytes > bytes.length() {
    raise TopologyError("truncated NIfTI study data")
  }
  let (affine, transform_source) = nifti_affine(bytes, little)
  let units = bytes[123]
  let time_step = nifti_f32(bytes, 92, little)
  let time_offset = nifti_f32(bytes, 136, little)
  if !finite(time_step) || !finite(time_offset) {
    raise TopologyError("non-finite NIfTI time metadata")
  }
  let volumes : Array[Array[Array[Array[Double]]]] = []
  for frame = 0; frame < frame_count; frame = frame + 1 {
    let single = Array::make(offset + frame_bytes, 0)
    for i = 0; i < offset; i = i + 1 {
      single[i] = bytes[i]
    }
    for i = 0; i < frame_bytes; i = i + 1 {
      single[offset + i] = bytes[offset + frame * frame_bytes + i]
    }
    if little {
      single[40] = 3
      single[41] = 0
      single[48] = 1
      single[49] = 0
    } else {
      single[40] = 0
      single[41] = 3
      single[48] = 0
      single[49] = 1
    }
    volumes.push(parse_nifti1(single))
  }
  {
    volumes,
    affine,
    spatial_units: units % 8,
    temporal_units: units / 8 % 8,
    time_step,
    time_offset,
    transform_source,
  }
}

///|
pub fn nifti_study_metadata(study : NiftiStudy) -> Json {
  {
    "schema_version": 1,
    "kind": "nifti_study_metadata",
    "frame_count": study.volumes.length(),
    "shape_zyx": [
      study.volumes[0].length(),
      study.volumes[0][0].length(),
      study.volumes[0][0][0].length(),
    ],
    "affine_voxel_xyz_to_world": study.affine,
    "spatial_units_code": study.spatial_units,
    "temporal_units_code": study.temporal_units,
    "time_step": study.time_step,
    "time_offset": study.time_offset,
    "transform_source": study.transform_source,
    "interpretation": "voxel indices are used for topology; affine reports physical coordinates without reorientation or resampling",
  }
}
