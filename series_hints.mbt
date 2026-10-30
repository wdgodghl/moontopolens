///|
/// Exploratory delay suggestions from the observed series. Correlation uses
/// paired samples at each lag; mutual information uses fixed equal-width bins
/// over the complete series, so values are comparable across lags.
pub fn series_lag_hints(text : String) -> (Json, String) raise TopologyError {
  if text.length() > 1000000 {
    raise TopologyError("series hints request exceeds one million characters")
  }
  let value = @json.parse(text) catch {
    _ => raise TopologyError("invalid series hints JSON")
  }
  let object = match value {
    Object(fields) => fields
    _ => raise TopologyError("series hints request must be an object")
  }
  let kind : String = @json.from_json(required_field(object, "kind")) catch {
    _ => raise TopologyError("kind must be a string")
  }
  if kind != "series_hints" {
    raise TopologyError("kind must be series_hints")
  }
  for field in object.keys() {
    if !["kind", "series", "max_lag", "bins"].contains(field) {
      raise TopologyError("unknown series hints field: " + field)
    }
  }
  let series : Array[Double] = @json.from_json(required_field(object, "series")) catch {
    _ => raise TopologyError("series must be an array of numbers")
  }
  if series.length() < 8 || series.length() > 10000 {
    raise TopologyError("series hints require 8..10000 samples")
  }
  let mut minimum = series[0]
  let mut maximum_value = series[0]
  for sample in series {
    if !finite(sample) || sample.abs() > 1.0e100 {
      raise TopologyError("time samples must be finite and bounded")
    }
    if sample < minimum {
      minimum = sample
    }
    if sample > maximum_value {
      maximum_value = sample
    }
  }
  if minimum == maximum_value {
    raise TopologyError("constant series has no identifiable delay")
  }
  let default_lag = if series.length() / 2 < 32 {
    series.length() / 2
  } else {
    32
  }
  let max_lag = integer_field(object, "max_lag", default_lag)
  if max_lag < 2 || max_lag > 128 || max_lag > series.length() / 2 {
    raise TopologyError(
      "max_lag must be 2..128 and no more than half the sample count",
    )
  }
  let bins = integer_field(object, "bins", 8)
  if bins < 2 || bins > 32 {
    raise TopologyError("bins must be 2..32")
  }
  let labels : Array[Int32] = []
  for sample in series {
    let scaled = (sample - minimum) / (maximum_value - minimum)
    let mut label = (scaled * bins.to_double()).to_int()
    if label >= bins {
      label = bins - 1
    }
    labels.push(label)
  }
  let correlations : Array[Double] = []
  let informations : Array[Double] = []
  let rows : Array[Json] = []
  let mut csv = "lag,pair_count,autocorrelation,mutual_information_nats\n"
  for lag = 1; lag <= max_lag; lag = lag + 1 {
    let count = series.length() - lag
    let mut left_sum = 0.0
    let mut right_sum = 0.0
    let left_counts = Array::make(bins, 0)
    let right_counts = Array::make(bins, 0)
    let joint = Array::make(bins * bins, 0)
    for i = 0; i < count; i = i + 1 {
      left_sum += series[i]
      right_sum += series[i + lag]
      let a = labels[i]
      let b = labels[i + lag]
      left_counts[a] += 1
      right_counts[b] += 1
      joint[a * bins + b] += 1
    }
    let left_mean = left_sum / count.to_double()
    let right_mean = right_sum / count.to_double()
    let mut covariance = 0.0
    let mut left_variance = 0.0
    let mut right_variance = 0.0
    for i = 0; i < count; i = i + 1 {
      let a = series[i] - left_mean
      let b = series[i + lag] - right_mean
      covariance += a * b
      left_variance += a * a
      right_variance += b * b
    }
    let raw_correlation = if left_variance == 0.0 || right_variance == 0.0 {
      0.0
    } else {
      covariance / left_variance.sqrt() / right_variance.sqrt()
    }
    let correlation = if raw_correlation > 1.0 {
      1.0
    } else if raw_correlation < -1.0 {
      -1.0
    } else {
      raw_correlation
    }
    let mut information = 0.0
    for a = 0; a < bins; a = a + 1 {
      for b = 0; b < bins; b = b + 1 {
        let frequency = joint[a * bins + b]
        if frequency > 0 {
          let ratio = frequency.to_double() *
            count.to_double() /
            (left_counts[a].to_double() * right_counts[b].to_double())
          information += frequency.to_double() /
            count.to_double() *
            @math.ln(ratio)
        }
      }
    }
    correlations.push(correlation)
    informations.push(information)
    rows.push({
      "lag": lag,
      "pair_count": count,
      "autocorrelation": correlation,
      "mutual_information_nats": information,
    })
    csv += "\{lag},\{count},\{correlation},\{information}\n"
  }
  let mut correlation_lag = 0
  let correlation_limit = 1.0 / 2.718281828459045
  for i = 0; i < correlations.length(); i = i + 1 {
    if correlations[i] <= correlation_limit {
      correlation_lag = i + 1
      break
    }
  }
  let mut information_lag = 0
  for i = 1; i + 1 < informations.length(); i = i + 1 {
    if informations[i] < informations[i - 1] &&
      informations[i] <= informations[i + 1] {
      information_lag = i + 1
      break
    }
  }
  let hints : Array[Json] = []
  if correlation_lag > 0 {
    hints.push({
      "lag": correlation_lag,
      "method": "first autocorrelation at or below 1/e",
      "value": correlations[correlation_lag - 1],
    })
  }
  if information_lag > 0 {
    hints.push({
      "lag": information_lag,
      "method": "first strict local minimum of binned mutual information",
      "value": informations[information_lag - 1],
    })
  }
  (
    {
      "schema_version": 1,
      "kind": "series_hints",
      "sample_count": series.length(),
      "max_lag": max_lag,
      "bins": bins,
      "rows": rows,
      "suggestions": hints,
      "interpretation": "exploratory delay candidates only; no period inference or embedding-dimension guarantee; an empty suggestion list means no crossing or local minimum in the scanned range",
    },
    csv,
  )
}
