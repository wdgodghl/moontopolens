///|
/// Exact right-continuous Betti counts at filtration event scales.
pub struct BettiEvent {
  scale : Double
  h0 : Int
  h1 : Int
} derive(@debug.Debug)

///|
pub extend BettiEvent with @debug.Debug::{to_repr}

///|
/// Aggregate births and deaths at the same scale before recording counts.
/// Includes the first cell scale and cutoff, even when no count changes there.
pub fn betti_events(analysis : Analysis) -> Array[BettiEvent] {
  let cutoff = analysis.filtration.cutoff
  let start = if analysis.filtration.cells.is_empty() {
    cutoff
  } else {
    analysis.filtration.cells[0].value
  }
  let deltas : Array[(Double, Int, Int)] = [(start, 0, 0), (cutoff, 0, 0)]
  for interval in analysis.intervals {
    if interval.dimension > 1 || interval.dimension < 0 {
      continue
    }
    let h0 = if interval.dimension == 0 { 1 } else { 0 }
    let h1 = if interval.dimension == 1 { 1 } else { 0 }
    deltas.push((interval.birth, h0, h1))
    if interval.death is Some(death) {
      deltas.push((death, -h0, -h1))
    }
  }
  deltas.sort_by(fn(a, b) {
    if a.0 < b.0 {
      -1
    } else if a.0 > b.0 {
      1
    } else {
      0
    }
  })
  let result : Array[BettiEvent] = []
  let mut h0 = 0
  let mut h1 = 0
  let mut i = 0
  while i < deltas.length() {
    let scale = deltas[i].0
    while i < deltas.length() && deltas[i].0 == scale {
      h0 += deltas[i].1
      h1 += deltas[i].2
      i += 1
    }
    result.push({ scale, h0, h1, })
  }
  result
}

///|
pub fn betti_events_json(analysis : Analysis) -> Json {
  Json::array(
    betti_events(analysis).map(fn(event) {
      { "scale": event.scale, "h0": event.h0, "h1": event.h1 }
    }),
  )
}

///|
/// Event rows, unlike uniform samples, retain arbitrarily short intervals.
pub fn betti_events_csv(analysis : Analysis) -> String {
  let mut text = "scale,H0,H1\n"
  for event in betti_events(analysis) {
    text += "\{event.scale},\{event.h0},\{event.h1}\n"
  }
  text
}
