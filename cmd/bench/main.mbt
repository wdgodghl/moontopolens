// A small reproducible MoonBit-core benchmark; Node only supplies time/RSS.

///|
fn main {
  let n = benchmark_size()
  let sparse = benchmark_sparse()
  if n < 4 || n > (if sparse { 128 } else { 38 }) {
    println("benchmark size out of supported range")
    return
  }
  let points = if sparse {
    Array::makei(n, fn(i) {
      let group = (i / 4).to_double() * 10.0
      [group + (i % 2).to_double() * 0.2, (i % 4 / 2).to_double() * 0.2]
    })
  } else {
    Array::makei(n, fn(i) {
      [(i * 7 % 31).to_double() / 31.0, (i * i * 11 % 37).to_double() / 37.0]
    })
  }
  let start = clock_ms()
  try {
    let result = @topo.analyze(
      @topo.rips(
        points,
        threshold=if sparse { 0.21 } else { 2.0 },
        max_cells=10000,
      ),
      representatives=benchmark_representatives(),
    )
    let elapsed = clock_ms() - start
    let report : Json = {
      "point_count": n,
      "distribution": if sparse {
        "sparse_groups"
      } else {
        "dense"
      },
      "cell_count": result.filtration.cells.length(),
      "interval_count": result.intervals.length(),
      "elapsed_ms": elapsed,
      "rss_mib_after": rss_mib(),
      "heap_mib_after": heap_mib(),
      "peak_rss_mib": peak_rss_mib(),
      "representatives_computed": result.representatives_computed,
      "reduction_entries": result.reduction_entries,
      "diagram": result.intervals.map(fn(i) { (i.dimension, i.birth, i.death) }),
    }
    println(report.stringify())
  } catch {
    error => println(error.message())
  }
}
