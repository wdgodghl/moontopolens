///|
/// One single-linkage join. Leaves use ids 0..n-1; joins use ids n onward.
pub struct BatchClusterMerge {
  left : Int
  right : Int
  distance : Double
  members : Array[String]
} derive(@debug.Debug)

///|
pub extend BatchClusterMerge with @debug.Debug::{to_repr}

///|
/// A forest is returned when some pairs have no finite, comparable distance.
pub struct BatchClustering {
  names : Array[String]
  dimension : Int
  merges : Array[BatchClusterMerge]
  roots : Array[Int]
  groups : Array[Array[String]]
  omitted_pairs : Int
} derive(@debug.Debug)

///|
pub extend BatchClustering with @debug.Debug::{to_repr}

///|
priv struct BatchClusterEdge {
  a : Int
  b : Int
  distance : Double
}

///|
fn batch_cluster_root(parent : Array[Int], index : Int) -> Int {
  let mut root = index
  while parent[root] != root {
    root = parent[root]
  }
  root
}

///|
/// Deterministic single-linkage clustering over comparable finite distances.
/// Missing distances never become zero or an arbitrary large replacement.
pub fn batch_clustering(
  matrix : BatchDistanceMatrix,
  dimension : Int,
) -> BatchClustering raise TopologyError {
  if dimension != 0 && dimension != 1 {
    raise TopologyError("clustering dimension must be 0 or 1")
  }
  let n = matrix.names.length()
  if n < 1 || n > 8 {
    raise TopologyError("clustering requires 1..8 cases")
  }
  let rows = if dimension == 0 { matrix.h0 } else { matrix.h1 }
  let edges : Array[BatchClusterEdge] = []
  let mut omitted_pairs = 0
  for i = 0; i < n; i = i + 1 {
    for j = i + 1; j < n; j = j + 1 {
      match rows[i][j] {
        Some(distance) =>
          if matrix.conditions_aligned[i][j] &&
            finite(distance) &&
            distance >= 0.0 {
            edges.push({ a: i, b: j, distance, })
          } else {
            omitted_pairs += 1
          }
        None => omitted_pairs += 1
      }
    }
  }
  edges.sort_by(fn(a, b) {
    if a.distance < b.distance {
      -1
    } else if a.distance > b.distance {
      1
    } else if a.a != b.a {
      a.a - b.a
    } else {
      a.b - b.b
    }
  })
  let parent = Array::makei(n, fn(i) { i })
  let node = Array::makei(n, fn(i) { i })
  let members = Array::makei(n, fn(i) { [i] })
  let merges : Array[BatchClusterMerge] = []
  for edge in edges {
    let a = batch_cluster_root(parent, edge.a)
    let b = batch_cluster_root(parent, edge.b)
    if a == b {
      continue
    }
    let left = node[a]
    let right = node[b]
    let joined = members[a] + members[b]
    joined.sort()
    let names = joined.map(fn(index) { matrix.names[index] })
    merges.push({ left, right, distance: edge.distance, members: names, })
    // The smaller original leaf is the stable representative of a component.
    let keep = if a < b { a } else { b }
    let drop = if a < b { b } else { a }
    parent[drop] = keep
    node[keep] = n + merges.length() - 1
    members[keep] = joined
  }
  let roots : Array[Int] = []
  let groups : Array[Array[String]] = []
  for i = 0; i < n; i = i + 1 {
    if parent[i] == i {
      roots.push(node[i])
      groups.push(members[i].map(fn(index) { matrix.names[index] }))
    }
  }
  {
    names: matrix.names.copy(),
    dimension,
    merges,
    roots,
    groups,
    omitted_pairs,
  }
}

///|
pub fn batch_clustering_json(clustering : BatchClustering) -> Json {
  let joins : Array[Json] = []
  for index, merge in clustering.merges {
    joins.push({
      "id": clustering.names.length() + index,
      "left": merge.left,
      "right": merge.right,
      "distance": merge.distance,
      "members": merge.members,
    })
  }
  let suggested_cut = batch_clustering_suggested_cut(clustering)
  let suggested_groups = match suggested_cut {
    Some(cut) =>
      batch_clustering_groups(clustering, cut) catch {
        _ => clustering.groups
      }
    None => clustering.groups
  }
  {
    "schema_version": 1,
    "method": "single_linkage",
    "metric": "bottleneck",
    "dimension": clustering.dimension,
    "names": clustering.names,
    "merges": joins,
    "roots": clustering.roots,
    "groups": clustering.groups,
    "suggested_cut": match suggested_cut {
      Some(value) => value.to_json()
      None => Json::null()
    },
    "suggested_groups": suggested_groups,
    "omitted_pairs": clustering.omitted_pairs,
    "note": "Only finite pairs with matching filtration kind and cutoff are used. suggested_cut is the midpoint of the largest observed merge-distance gap, not a statistical claim. Matching metadata does not prove that units or semantics agree. A disconnected forest is not forced into one group.",
  }
}

///|
/// A simple exploratory cut at the largest gap between distinct join heights.
/// This is undefined when no join exists and has no statistical interpretation.
pub fn batch_clustering_suggested_cut(clustering : BatchClustering) -> Double? {
  if clustering.merges.is_empty() {
    return None
  }
  let mut cut = clustering.merges[0].distance
  let mut gap = 0.0
  for i = 1; i < clustering.merges.length(); i = i + 1 {
    let previous = clustering.merges[i - 1].distance
    let next = clustering.merges[i].distance
    if next - previous > gap {
      gap = next - previous
      cut = (previous + next) / 2.0
    }
  }
  Some(cut)
}

///|
/// Return the connected groups after all single-linkage joins up to `cut`.
pub fn batch_clustering_groups(
  clustering : BatchClustering,
  cut : Double,
) -> Array[Array[String]] raise TopologyError {
  if !finite(cut) || cut < 0.0 {
    raise TopologyError("clustering cut must be finite and nonnegative")
  }
  let n = clustering.names.length()
  let labels = Array::makei(n, fn(i) { i })
  for merge in clustering.merges {
    if merge.distance > cut {
      break
    }
    let mut first = n
    for i, name in clustering.names {
      if merge.members.contains(name) && i < first {
        first = i
      }
    }
    if first < n {
      for i, name in clustering.names {
        if merge.members.contains(name) {
          labels[i] = first
        }
      }
    }
  }
  let positions : Map[Int, Int] = Map([])
  let groups : Array[Array[String]] = []
  for i, name in clustering.names {
    match positions.get(labels[i]) {
      Some(index) => groups[index].push(name)
      None => {
        positions[labels[i]] = groups.length()
        groups.push([name])
      }
    }
  }
  groups
}

///|
pub fn batch_clustering_csv(clustering : BatchClustering) -> String {
  let mut csv = "id,left,right,distance,members\n"
  for index, merge in clustering.merges {
    csv += "\{clustering.names.length() + index},\{merge.left},\{merge.right},\{merge.distance},\{merge.members.join("|")}\n"
  }
  csv
}

///|
/// Offline dendrogram. Separate roots visibly remain separate when distances
/// are missing; the vertical axis uses the original bottleneck units.
pub fn batch_clustering_svg(clustering : BatchClustering) -> String {
  let n = clustering.names.length()
  let width = if n * 100 > 640 { n * 100 } else { 640 }
  let base = 240.0
  let mut greatest = 0.0
  for merge in clustering.merges {
    if merge.distance > greatest {
      greatest = merge.distance
    }
  }
  if greatest == 0.0 {
    greatest = 1.0
  }
  let xs = Array::makei(n + clustering.merges.length(), fn(i) {
    70.0 +
    i.to_double() *
    (width - 140).to_double() /
    (if n > 1 { n - 1 } else { 1 }).to_double()
  })
  let ys = Array::make(n + clustering.merges.length(), base)
  let mut svg = "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"\{width}\" height=\"300\" viewBox=\"0 0 \{width} 300\"><rect width=\"100%\" height=\"100%\" fill=\"#0b1120\"/><g fill=\"none\" stroke=\"#38bdf8\" stroke-width=\"2\">"
  for index, merge in clustering.merges {
    let id = n + index
    let y = base - 180.0 * merge.distance / greatest
    let x1 = xs[merge.left]
    let x2 = xs[merge.right]
    xs[id] = (x1 + x2) / 2.0
    ys[id] = y
    svg += "<path d=\"M\{x1} \{ys[merge.left]}V\{y}H\{x2}V\{ys[merge.right]}\"/>"
  }
  svg += "</g>"
  match batch_clustering_suggested_cut(clustering) {
    Some(cut) => {
      let y = base - 180.0 * cut / greatest
      svg += "<line x1=\"40\" x2=\"\{width - 40}\" y1=\"\{y}\" y2=\"\{y}\" stroke=\"#f59e0b\" stroke-dasharray=\"5 5\"/><text x=\"45\" y=\"\{y - 5.0}\" fill=\"#fbbf24\" font-family=\"sans-serif\" font-size=\"11\">建议截断 \{cut}</text>"
    }
    None => ()
  }
  svg += "<g fill=\"#e2e8f0\" font-family=\"sans-serif\" font-size=\"13\" text-anchor=\"middle\">"
  for i, name in clustering.names {
    svg += "<text x=\"\{xs[i]}\" y=\"265\">\{matrix_html_escape(name)}</text>"
  }
  svg +
  "</g><text x=\"18\" y=\"25\" fill=\"#94a3b8\" font-family=\"sans-serif\" font-size=\"13\">H\{clustering.dimension} · 单链接 · \{clustering.groups.length()} 个独立分组 · \{clustering.omitted_pairs} 对不可比较</text></svg>"
}
