///|
/// Reverse the grayscale ordering while preserving the original max value.
/// This lets bright foreground enter a lower-star filtration first.
pub fn invert_pgm(image : PgmImage) -> PgmImage {
  let maximum = image.max_value.to_double()
  let grid = image.grid.map(fn(row) { row.map(fn(value) { maximum - value }) })
  { grid, max_value: image.max_value, encoding: image.encoding, }
}

///|
/// Otsu cutoff in the image's original integer scale. For equal maxima,
/// choose the smallest cutoff; a constant image uses its sole gray value.
/// The cutoff is computed on the supplied image, after any requested inversion.
pub fn otsu_threshold(image : PgmImage) -> Double {
  let histogram = Array::make(image.max_value + 1, 0)
  let mut pixels = 0
  let mut weighted_sum = 0.0
  let mut first = image.max_value
  let mut last = 0
  for row in image.grid {
    for value in row {
      let gray = value.to_int()
      histogram[gray] += 1
      pixels += 1
      weighted_sum += value
      if gray < first {
        first = gray
      }
      if gray > last {
        last = gray
      }
    }
  }
  if first == last {
    return first.to_double()
  }
  let mut below = 0
  let mut below_sum = 0.0
  let mut best = -1.0
  let mut cutoff = first
  for gray = first; gray < last; gray = gray + 1 {
    below += histogram[gray]
    below_sum += gray.to_double() * histogram[gray].to_double()
    if below == 0 || below == pixels {
      continue
    }
    let numerator = weighted_sum * below.to_double() -
      below_sum * pixels.to_double()
    let score = numerator *
      numerator /
      (below.to_double() * (pixels - below).to_double())
    if score > best {
      best = score
      cutoff = gray
    }
  }
  cutoff.to_double()
}
