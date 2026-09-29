///|
test "offline report escapes script terminators in public data" {
  let f = rips([[0.0]], threshold=1.0)
  f.cells[0] = {
    key: "</script><script>alert(1)</script>",
    dimension: 0,
    value: 0.0,
    boundary: [],
    vertices: [0],
  }
  let html = html_report(analyze(f))
  assert_true(html.contains("\\u003c/script>"))
  assert_true(!html.contains("</script><script>alert(1)"))
}
