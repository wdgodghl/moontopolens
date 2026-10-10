// A small reproducible MoonBit-core benchmark; Node only supplies time/RSS.

///|
fn main {
  let n = benchmark_size()
  if n < 4 || n > 28 {
    println("benchmark size must be 4..28")
    return
  }
  let points = Array::makei(n, fn(i) {
    [(i * 7 % 31).to_double() / 31.0, (i * i * 11 % 37).to_double() / 37.0]
  })
  let start = clock_ms()
  try {
    let result = @topo.analyze(@topo.rips(points, threshold=2.0))
    let elapsed = clock_ms() - start
    let report : Json = {
      "point_count": n,
      "cell_count": result.filtration.cells.length(),
      "interval_count": result.intervals.length(),
      "elapsed_ms": elapsed,
      "rss_mib_after": rss_mib(),
      "heap_mib_after": heap_mib(),
    }
    println(report.stringify())
  } catch {
    error => println(error.message())
  }
}
