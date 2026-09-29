// Thin Node host adapter: arguments and filesystem only; all analysis is MoonBit.

///|
extern "js" fn argument_count() -> Int =
  #|() => process.argv.length - 2

///|
extern "js" fn argument(index : Int) -> String =
  #|(i) => process.argv[i + 2] || ""

///|
extern "js" fn read_input(path : String) -> String =
  #|(path) => {
  #|  const fs = require("node:fs");
  #|  try {
  #|    const stat = fs.statSync(path);
  #|    if (!stat.isFile() || stat.size > 1000000) return "";
  #|    return fs.readFileSync(path, "utf8");
  #|  } catch (_) { return ""; }
  #|}

///|
extern "js" fn print_error(message : String) -> Unit =
  #|(message) => { process.stderr.write(message + "\n"); process.exitCode = 2; }

// Create a new directory rather than overwriting an earlier report.

///|
extern "js" fn new_output(path : String) -> Bool =
  #|(path) => { try { require("node:fs").mkdirSync(path); return true; } catch (_) { return false; } }

///|
extern "js" fn save_output(
  dir : String,
  name : String,
  content : String,
) -> Bool =
  #|(dir, name, content) => {
  #|  try {
  #|    require("node:fs").writeFileSync(require("node:path").join(dir, name), content, {encoding: "utf8", flag: "wx"});
  #|    return true;
  #|  } catch (_) { return false; }
  #|}
