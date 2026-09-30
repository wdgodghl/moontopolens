///|
test "Otsu selects the first optimal split for separated grayscale levels" {
  let image = @moontopolens.parse_pgm(
    "P2 3 3 255 0 0 0 0 255 0 0 0 0".to_array().map(fn(c) { c.to_int() }),
  )
  assert_eq(@moontopolens.otsu_threshold(image), 0.0)
  let result = @moontopolens.analyze(
    @moontopolens.cubical_grid(
      image.grid,
      threshold=@moontopolens.otsu_threshold(image),
    ),
  )
  assert_eq(@moontopolens.betti(result, 1, 0.0), 1)
}

///|
test "inverted bright foreground reproduces dark ring filtration" {
  let bright = @moontopolens.parse_pgm(
    "P2 3 3 255 255 255 255 255 0 255 255 255 255"
    .to_array()
    .map(fn(c) { c.to_int() }),
  )
  let dark = @moontopolens.invert_pgm(bright)
  assert_eq(dark.max_value, 255)
  assert_eq(dark.grid[1][1], 255.0)
  assert_eq(dark.grid[0][0], 0.0)
  assert_eq(@moontopolens.otsu_threshold(dark), 0.0)
  let result = @moontopolens.analyze(
    @moontopolens.cubical_grid(dark.grid, threshold=0.0),
  )
  assert_eq(@moontopolens.betti(result, 1, 0.0), 1)
}

///|
test "Otsu on constant image returns sole level" {
  let image = @moontopolens.parse_pgm(
    "P2 2 2 15 7 7 7 7".to_array().map(fn(c) { c.to_int() }),
  )
  assert_eq(@moontopolens.otsu_threshold(image), 7.0)
}

///|
test "Otsu preserves 16-bit grayscale scale" {
  let image = @moontopolens.parse_pgm([
    80, 53, 10, 50, 32, 49, 10, 49, 48, 50, 51, 10, 0, 1, 3, 255,
  ])
  assert_eq(@moontopolens.otsu_threshold(image), 1.0)
}
