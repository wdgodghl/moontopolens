///|
/// A viewing scale derived from one observed H1 interval or the final cutoff.
/// The interval index refers to Analysis.intervals and may be passed to slice.
pub struct ScaleRecommendation {
  scale : Double
  interval_index : Int32?
  reason : String
  observed_lifetime : Double?
  censored : Bool
} derive(@debug.Debug)

///|
pub extend ScaleRecommendation with @debug.Debug::{to_repr}

///|
/// Rank H1 classes by observed lifetime, then select a scale within each
/// interval. For alive classes, the observed lifetime is only a lower bound.
/// If there are no loops, include an exact pre-merge H0 event when components
/// do merge. The final cutoff is always appended as a baseline view.
pub fn recommend_scales(
  analysis : Analysis,
  max_loops~ : Int32 = 5,
) -> Array[ScaleRecommendation] raise TopologyError {
  if max_loops < 1 || max_loops > 10 {
    raise TopologyError("scale recommendations require 1..10 loop suggestions")
  }
  let indices : Array[Int32] = []
  for i = 0; i < analysis.intervals.length(); i = i + 1 {
    if analysis.intervals[i].dimension == 1 {
      indices.push(i)
    }
  }
  indices.sort_by(fn(i, j) {
    let a = observed_lifetime(analysis, analysis.intervals[i])
    let b = observed_lifetime(analysis, analysis.intervals[j])
    if a > b {
      -1
    } else if a < b {
      1
    } else {
      i - j
    }
  })
  let result : Array[ScaleRecommendation] = []
  for i = 0; i < indices.length() && result.length() < max_loops; i = i + 1 {
    let index = indices[i]
    let interval = analysis.intervals[index]
    let censored = interval.death is None
    let end = match interval.death {
      Some(death) => death
      None => analysis.filtration.cutoff
    }
    let middle = interval.birth + (end - interval.birth) / 2.0
    let scale = if middle >= end { interval.birth } else { middle }
    result.push({
      scale,
      interval_index: Some(index),
      reason: if censored {
        "h1_alive_at_cutoff"
      } else {
        "h1_finite"
      },
      observed_lifetime: Some(observed_lifetime(analysis, interval)),
      censored,
    })
  }
  if result.is_empty() {
    let mut best_scale = analysis.filtration.cutoff
    let mut best_h0 = betti(analysis, 0, analysis.filtration.cutoff)
    let final_h0 = best_h0
    for event in betti_events(analysis) {
      if event.scale < analysis.filtration.cutoff && event.h0 > best_h0 {
        best_h0 = event.h0
        best_scale = event.scale
      }
    }
    if best_h0 > final_h0 && best_h0 > 1 {
      result.push({
        scale: best_scale,
        interval_index: None,
        reason: "h0_before_merges",
        observed_lifetime: None,
        censored: false,
      })
    }
  }
  result.push({
    scale: analysis.filtration.cutoff,
    interval_index: None,
    reason: "final_cutoff",
    observed_lifetime: None,
    censored: false,
  })
  result
}

///|
fn recommendation_number(value : Double?) -> Json {
  match value {
    Some(number) => number.to_json()
    None => Json::null()
  }
}

///|
fn recommendation_index(value : Int32?) -> Json {
  match value {
    Some(index) => index.to_json()
    None => Json::null()
  }
}

///|
/// Structured explanation with the exact scale and Betti counts for each view.
pub fn recommendations_json(
  analysis : Analysis,
  max_loops~ : Int32 = 5,
) -> Json raise TopologyError {
  let suggestions : Array[Json] = []
  for item in recommend_scales(analysis, max_loops~) {
    suggestions.push({
      "scale": item.scale,
      "interval_index": recommendation_index(item.interval_index),
      "reason": item.reason,
      "observed_lifetime": recommendation_number(item.observed_lifetime),
      "censored": item.censored,
      "h0": betti(analysis, 0, item.scale),
      "h1": betti(analysis, 1, item.scale),
    })
  }
  {
    "schema_version": 1,
    "cutoff": analysis.filtration.cutoff,
    "recommendations": suggestions,
    "method": "H1 classes ranked by observed lifetime; view at interval midpoint, falling back to birth if needed; without H1 choose an exact pre-merge H0 event when available; append final cutoff",
    "censoring_note": "alive at cutoff means only an observed lower bound, not infinite persistence",
    "interpretation_note": "viewing suggestions only; not an optimal filtration threshold or a physical diagnosis",
  }
}

///|
pub fn recommendations_csv(
  analysis : Analysis,
  max_loops~ : Int32 = 5,
) -> String raise TopologyError {
  let mut text = "rank,scale,interval_index,reason,observed_lifetime,censored,H0,H1\n"
  let suggestions = recommend_scales(analysis, max_loops~)
  for i, item in suggestions {
    let index = match item.interval_index {
      Some(value) => value.to_string()
      None => ""
    }
    let lifetime = match item.observed_lifetime {
      Some(value) => value.to_string()
      None => ""
    }
    text += "\{i + 1},\{item.scale},\{index},\{item.reason},\{lifetime},\{item.censored},\{betti(analysis, 0, item.scale)},\{betti(analysis, 1, item.scale)}\n"
  }
  text
}
