// Timing and process-memory instrumentation only; topology stays in MoonBit.

///|
extern "js" fn benchmark_size() -> Int =
  #|() => Number(process.argv[2]) || 0

///|
extern "js" fn benchmark_sparse() -> Bool =
  #|() => process.argv[3] === "sparse"

///|
extern "js" fn benchmark_representatives() -> Bool =
  #|() => process.argv[4] !== "intervals"

///|
extern "js" fn peak_rss_mib() -> Double =
  #|() => process.resourceUsage().maxRSS / 1024

///|
extern "js" fn clock_ms() -> Double =
  #|() => performance.now()

///|
extern "js" fn rss_mib() -> Double =
  #|() => process.memoryUsage().rss / 1048576

///|
extern "js" fn heap_mib() -> Double =
  #|() => process.memoryUsage().heapUsed / 1048576
