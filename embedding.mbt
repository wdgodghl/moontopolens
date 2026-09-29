/// Sliding-window delay embedding: row i is [x_i, x_(i+lag), ...].
/// No normalization or resampling is applied implicitly.
pub fn delay_embed(series : Array[Double], dimension~ : Int, lag~ : Int, stride? : Int = 1) -> Array[Array[Double]] raise TopologyError {
  if dimension < 1 || dimension > 32 || lag < 1 || lag > 10000 || stride < 1 || stride > 10000 {
    raise TopologyError("embedding requires dimension 1..32 and lag/stride 1..10000")
  }
  if series.length() > 10000 { raise TopologyError("at most 10000 time samples are supported") }
  for value in series {
    if !finite(value) || value.abs() > 1.0e100 { raise TopologyError("time samples must be finite and bounded") }
  }
  let span = (dimension - 1) * lag
  if span >= series.length() { raise TopologyError("series too short for requested embedding") }
  let count = (series.length() - 1 - span) / stride + 1
  if count > 128 { raise TopologyError("embedding exceeds 128 points; increase stride") }
  Array::makei(count, fn(i) {
    Array::makei(dimension, fn(k) { series[i * stride + k * lag] })
  })
}
