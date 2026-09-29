///|
test "P2 parser accepts comments whitespace and preserves pixel scale" {
  let text = "P2\n# sample\n3 3\n15\n0 0 0\n0 15 0\n0 0 0 # trailing\n"
  let image = @moontopolens.parse_pgm(text.to_array().map(fn(c) { c.to_int() }))
  assert_eq(image.encoding, "P2")
  assert_eq(image.max_value, 15)
  assert_eq(image.grid, [[0.0, 0.0, 0.0], [0.0, 15.0, 0.0], [0.0, 0.0, 0.0]])
  let result = @moontopolens.analyze(
    @moontopolens.cubical_grid(image.grid, threshold=15.0),
  )
  assert_eq(@moontopolens.betti(result, 1, 0.0), 1)
  assert_eq(@moontopolens.betti(result, 1, 15.0), 0)
}

///|
test "P5 parser accepts raster whitespace byte and 16-bit big-endian pixels" {
  let one = @moontopolens.parse_pgm([
    80, 53, 10, 50, 32, 49, 10, 50, 53, 53, 10, 32, 255,
  ])
  assert_eq(one.encoding, "P5")
  assert_eq(one.grid, [[32.0, 255.0]])
  let two = @moontopolens.parse_pgm([
    80, 53, 13, 10, 50, 32, 49, 13, 10, 49, 48, 50, 51, 13, 10, 0, 1, 3, 255,
  ])
  assert_eq(two.max_value, 1023)
  assert_eq(two.grid, [[1.0, 1023.0]])
}

///|
test "PGM rejects malformed dimensions values and trailing images" {
  for
    text in [
      "P2 0 1 255 0", "P2 65 1 1 0", "P2 1 1 0 0", "P2 1 1 1 2", "P2 1 1 1", "P2 1 1 1 0 0",
      "P3 1 1 1 0", "P2 1 x 1 0",
    ] {
    let invalid = try {
      ignore(@moontopolens.parse_pgm(text.to_array().map(fn(c) { c.to_int() })))
      false
    } catch {
      _ => true
    }
    assert_true(invalid)
  }
  for
    bytes in [
      [80, 53, 10, 49, 32, 49, 10, 50, 53, 53, 10],
      [80, 53, 10, 49, 32, 49, 10, 49, 10, 2],
      [80, 53, 10, 49, 32, 49, 10, 49, 10, 0, 1],
    ] {
    let invalid = try {
      ignore(@moontopolens.parse_pgm(bytes))
      false
    } catch {
      _ => true
    }
    assert_true(invalid)
  }
}
