///|
/// Parsed Netpbm PGM image. Pixel values stay in the original 0..maxval scale.
pub struct PgmImage {
  grid : Array[Array[Double]]
  max_value : Int
  encoding : String
} derive(@debug.Debug)

///|
pub extend PgmImage with @debug.Debug::{to_repr}

///|
fn pgm_space(value : Int) -> Bool {
  value == 32 ||
  value == 9 ||
  value == 10 ||
  value == 13 ||
  value == 11 ||
  value == 12
}

///|
fn pgm_token(
  data : Array[Int],
  start : Int,
) -> (String, Int) raise TopologyError {
  let mut i = start
  while i < data.length() {
    if pgm_space(data[i]) {
      i += 1
      continue
    }
    if data[i] == 35 {
      while i < data.length() && data[i] != 10 && data[i] != 13 {
        i += 1
      }
      continue
    }
    break
  }
  let mut token = ""
  while i < data.length() && !pgm_space(data[i]) && data[i] != 35 {
    if data[i] < 33 || data[i] > 126 || token.length() >= 32 {
      raise TopologyError("PGM token must be bounded ASCII")
    }
    token += data[i].unsafe_to_char().to_string()
    i += 1
  }
  if token == "" {
    raise TopologyError("PGM file ends before all required values")
  }
  (token, i)
}

///|
fn pgm_number(
  token : String,
  label : String,
  upper : Int,
) -> Int raise TopologyError {
  let mut value = 0
  for digit in token {
    let code = digit.to_int()
    if code < 48 || code > 57 {
      raise TopologyError(label + " must be unsigned decimal")
    }
    value = value * 10 + code - 48
    if value > upper {
      raise TopologyError(label + " exceeds supported range")
    }
  }
  value
}

///|
/// Read exactly one plain P2 or raw P5 grayscale image, including 16-bit P5.
/// Reject trailing images, malformed rasters and dimensions beyond 64x64.
pub fn parse_pgm(data : Array[Int]) -> PgmImage raise TopologyError {
  if data.length() < 7 || data.length() > 1000000 {
    raise TopologyError("PGM input must contain 7..1000000 bytes")
  }
  for byte in data {
    if byte < 0 || byte > 255 {
      raise TopologyError("PGM bytes must be in 0..255")
    }
  }
  let (magic, after_magic) = pgm_token(data, 0)
  if magic != "P2" && magic != "P5" {
    raise TopologyError("expected P2 or P5 grayscale PGM")
  }
  let (width_text, after_width) = pgm_token(data, after_magic)
  let (height_text, after_height) = pgm_token(data, after_width)
  let (max_text, after_max) = pgm_token(data, after_height)
  let width = pgm_number(width_text, "PGM width", 64)
  let height = pgm_number(height_text, "PGM height", 64)
  let max_value = pgm_number(max_text, "PGM max value", 65535)
  if width == 0 || height == 0 || max_value == 0 {
    raise TopologyError("PGM width, height and max value must be positive")
  }
  let grid = Array::makei(height, fn(_) { Array::make(width, 0.0) })
  if magic == "P2" {
    let mut cursor = after_max
    for row = 0; row < height; row = row + 1 {
      for col = 0; col < width; col = col + 1 {
        let (token, next) = pgm_token(data, cursor)
        grid[row][col] = pgm_number(token, "PGM pixel", max_value).to_double()
        cursor = next
      }
    }
    let mut i = cursor
    while i < data.length() {
      if pgm_space(data[i]) {
        i += 1
        continue
      }
      if data[i] == 35 {
        while i < data.length() && data[i] != 10 && data[i] != 13 {
          i += 1
        }
        continue
      }
      raise TopologyError("PGM file contains extra pixels or another image")
    }
  } else {
    if after_max >= data.length() || !pgm_space(data[after_max]) {
      raise TopologyError(
        "P5 header requires one whitespace separator before raster",
      )
    }
    let mut offset = after_max + 1
    if data[after_max] == 13 && offset < data.length() && data[offset] == 10 {
      offset += 1
    }
    let bytes_per_pixel = if max_value < 256 { 1 } else { 2 }
    if data.length() - offset != width * height * bytes_per_pixel {
      raise TopologyError("P5 raster length does not match image dimensions")
    }
    for row = 0; row < height; row = row + 1 {
      for col = 0; col < width; col = col + 1 {
        let value = if bytes_per_pixel == 1 {
          data[offset]
        } else {
          data[offset] * 256 + data[offset + 1]
        }
        if value > max_value {
          raise TopologyError("P5 pixel exceeds max value")
        }
        grid[row][col] = value.to_double()
        offset += bytes_per_pixel
      }
    }
  }
  { grid, max_value, encoding: magic, }
}
