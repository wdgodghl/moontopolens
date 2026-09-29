///|
/// Observed lifetime; for a censored class this is only a lower bound.
pub fn observed_lifetime(analysis : Analysis, interval : Interval) -> Double {
  let end = match interval.death {
    Some(value) => value
    None => analysis.filtration.cutoff
  }
  maximum(0.0, end - interval.birth)
}

///|
/// Select and rank intervals by observed lifetime without modifying the result.
/// Undead intervals use cutoff-birth; ranking is not proof of infinite lifetime.
pub fn ranked_intervals(
  analysis : Analysis,
  dimension~ : Int,
  min_lifetime? : Double = 0.0,
  include_alive? : Bool = true,
) -> Array[Interval] raise TopologyError {
  if dimension < 0 ||
    dimension > 1 ||
    !finite(min_lifetime) ||
    min_lifetime < 0.0 {
    raise TopologyError(
      "interval selection requires dimension 0/1 and nonnegative finite minimum lifetime",
    )
  }
  let result = analysis.intervals.filter(fn(interval) {
    interval.dimension == dimension &&
    (include_alive || interval.death is Some(_)) &&
    observed_lifetime(analysis, interval) >= min_lifetime
  })
  result.sort_by(fn(a, b) {
    let da = observed_lifetime(analysis, a)
    let db = observed_lifetime(analysis, b)
    if da > db {
      -1
    } else if da < db {
      1
    } else {
      a.birth_cell - b.birth_cell
    }
  })
  result
}

///|
/// Per-dimension counts, finite lifetimes, finite persistence entropy and
/// Betti numbers at cutoff. Censored intervals never enter finite entropy.
pub fn summary_json(analysis : Analysis) -> Json {
  let summaries : Array[Json] = []
  for dimension = 0; dimension < 2; dimension = dimension + 1 {
    let mut finite_count = 0
    let mut alive_count = 0
    let mut finite_total = 0.0
    let mut observed_total = 0.0
    let mut longest = 0.0
    for interval in analysis.intervals {
      if interval.dimension != dimension {
        continue
      }
      let life = observed_lifetime(analysis, interval)
      observed_total += life
      match interval.death {
        None => alive_count += 1
        Some(_) => {
          finite_count += 1
          finite_total += life
          longest = maximum(longest, life)
        }
      }
    }
    let mut entropy = 0.0
    if finite_total > 0.0 {
      for interval in analysis.intervals {
        if interval.dimension != dimension || interval.death is None {
          continue
        }
        let p = observed_lifetime(analysis, interval) / finite_total
        if p > 0.0 {
          entropy -= p * @math.ln(p)
        }
      }
    }
    let longest_finite : Json = if finite_count == 0 {
      Json::null()
    } else {
      longest.to_json()
    }
    summaries.push({
      "dimension": dimension,
      "finite_count": finite_count,
      "alive_at_cutoff": alive_count,
      "total_finite_lifetime": finite_total,
      "total_observed_lifetime": observed_total,
      "longest_finite_lifetime": longest_finite,
      "finite_persistence_entropy": entropy,
    })
  }
  Json::array(summaries)
}

///|
/// Numeric CSV with complete intervals and a semicolon-separated chain column.
pub fn intervals_csv(analysis : Analysis) -> String {
  let mut text = "index,dimension,birth,death,alive_at_cutoff,observed_lifetime,representative_cells\n"
  for i = 0; i < analysis.intervals.length(); i = i + 1 {
    let interval = analysis.intervals[i]
    let death = match interval.death {
      None => ""
      Some(d) => d.to_string()
    }
    let mut chain = ""
    for j = 0; j < interval.representative.length(); j = j + 1 {
      if j > 0 {
        chain += ";"
      }
      chain += interval.representative[j].to_string()
    }
    text += "\{i},\{interval.dimension},\{interval.birth},\{death},\{interval.death is None},\{observed_lifetime(analysis, interval)},\{chain}\n"
  }
  text
}

///|
/// Uniform samples over the filtration's observed range, including cutoff.
pub fn betti_csv(
  analysis : Analysis,
  samples? : Int = 101,
) -> String raise TopologyError {
  if samples < 2 || samples > 1001 {
    raise TopologyError("Betti CSV requires 2..1001 samples")
  }
  let mut start = analysis.filtration.cutoff
  for cell in analysis.filtration.cells {
    if cell.value < start {
      start = cell.value
    }
  }
  let mut text = "scale,H0,H1\n"
  for i = 0; i < samples; i = i + 1 {
    let scale = if i == samples - 1 {
      analysis.filtration.cutoff
    } else {
      start +
      (analysis.filtration.cutoff - start) *
      i.to_double() /
      (samples - 1).to_double()
    }
    text += "\{scale},\{betti(analysis, 0, scale)},\{betti(analysis, 1, scale)}\n"
  }
  text
}
