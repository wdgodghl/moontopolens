///|
fn nifti_u16(bytes : Array[Int], at : Int, little : Bool) -> Int {
  if little {
    bytes[at] | (bytes[at + 1] << 8)
  } else {
    (bytes[at] << 8) | bytes[at + 1]
  }
}

///|
fn nifti_u32(bytes : Array[Int], at : Int, little : Bool) -> Int {
  if little {
    bytes[at] |
    (bytes[at + 1] << 8) |
    (bytes[at + 2] << 16) |
    (bytes[at + 3] << 24)
  } else {
    (bytes[at] << 24) |
    (bytes[at + 1] << 16) |
    (bytes[at + 2] << 8) |
    bytes[at + 3]
  }
}

///|
fn nifti_f32(bytes : Array[Int], at : Int, little : Bool) -> Double {
  Float::reinterpret_from_int(nifti_u32(bytes, at, little)).to_double()
}

///|
/// Read a bounded, uncompressed NIfTI-1 single-file 3D image. Supports
/// uint8, int16, int32 and float32 scalar voxels in either byte order.
/// Returned volume is indexed [z][y][x], matching cubical_volume.
pub fn parse_nifti1(
  bytes : Array[Int],
) -> Array[Array[Array[Double]]] raise TopologyError {
  if bytes.length() < 352 || bytes.length() > 1000000 {
    raise TopologyError("NIfTI-1 file must be between 352 bytes and 1 MB")
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
  if nifti_u16(bytes, 40, little) != 3 || nifti_u16(bytes, 48, little) != 1 {
    raise TopologyError("NIfTI importer requires a single 3D volume")
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
    raise TopologyError("NIfTI dimensions must each be between 2 and 32")
  }
  let datatype = nifti_u16(bytes, 70, little)
  let bytes_per_value = match datatype {
    2 => 1
    4 => 2
    8 | 16 => 4
    _ =>
      raise TopologyError(
        "NIfTI datatype must be uint8, int16, int32 or float32",
      )
  }
  if nifti_u16(bytes, 72, little) != bytes_per_value * 8 {
    raise TopologyError("NIfTI bitpix does not match datatype")
  }
  let offset_value = nifti_f32(bytes, 108, little)
  if !finite(offset_value) ||
    offset_value < 352.0 ||
    offset_value > 1000000.0 ||
    offset_value != @math.floor(offset_value) {
    raise TopologyError("invalid NIfTI voxel offset")
  }
  let offset = offset_value.to_int()
  let sample_count = width * height * depth
  if offset + sample_count * bytes_per_value > bytes.length() {
    raise TopologyError("truncated NIfTI voxel data")
  }
  let slope = nifti_f32(bytes, 112, little)
  let intercept = nifti_f32(bytes, 116, little)
  if !finite(slope) || !finite(intercept) {
    raise TopologyError("invalid NIfTI scaling")
  }
  let volume : Array[Array[Array[Double]]] = []
  for z = 0; z < depth; z = z + 1 {
    let layer : Array[Array[Double]] = []
    for y = 0; y < height; y = y + 1 {
      let row : Array[Double] = []
      for x = 0; x < width; x = x + 1 {
        let at = offset + ((z * height + y) * width + x) * bytes_per_value
        let raw = match datatype {
          2 => bytes[at].to_double()
          4 => {
            let bits = nifti_u16(bytes, at, little)
            (if bits >= 32768 { bits - 65536 } else { bits }).to_double()
          }
          8 => nifti_u32(bytes, at, little).to_double()
          16 => nifti_f32(bytes, at, little)
          _ => 0.0
        }
        let value = if slope == 0.0 { raw } else { raw * slope + intercept }
        if !finite(value) || value.abs() > 1.0e100 {
          raise TopologyError("non-finite NIfTI voxel value")
        }
        row.push(value)
      }
      layer.push(row)
    }
    volume.push(layer)
  }
  volume
}
