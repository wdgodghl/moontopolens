///|
fn main {
  try {
    let cloud = @topo.circle_points(12, 1.0)
    let result = @topo.analyze(@topo.rips(cloud, threshold=2.0))
    println(@topo.report_json(result).stringify())
  } catch {
    error => println(error.message())
  }
}
