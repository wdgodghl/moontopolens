// Timing and process-memory instrumentation only; topology stays in MoonBit.

///|
extern "js" fn benchmark_size() -> Int =
  #|() => Number(process.argv[2]) || 0

///|
extern "js" fn clock_ms() -> Double =
  #|() => performance.now()

///|
extern "js" fn rss_mib() -> Double =
  #|() => process.memoryUsage().rss / 1048576

///|
extern "js" fn heap_mib() -> Double =
  #|() => process.memoryUsage().heapUsed / 1048576
