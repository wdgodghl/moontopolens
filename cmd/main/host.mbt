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
extern "js" fn read_binary_input(path : String) -> FixedArray[Int] =
  #|(path) => {
  #|  const fs = require("node:fs");
  #|  try {
  #|    const stat = fs.statSync(path);
  #|    if (!stat.isFile() || stat.size > 1000000) return [];
  #|    return Array.from(fs.readFileSync(path));
  #|  } catch (_) { return []; }
  #|}

// Only allow children of the manifest's real directory, even across symlinks.

///|
extern "js" fn read_batch_text(manifest : String, relative : String) -> String =
  #|(manifest, relative) => {
  #|  const fs = require("node:fs"), path = require("node:path");
  #|  try {
  #|    if (!relative || path.isAbsolute(relative) || relative.includes("\\") || relative.includes(":") || relative.split("/").some(s => !s || s === "." || s === "..")) return "";
  #|    const base = fs.realpathSync(path.dirname(path.resolve(manifest)));
  #|    const target = fs.realpathSync(path.resolve(base, relative));
  #|    if (!target.startsWith(base + path.sep)) return "";
  #|    const stat = fs.statSync(target);
  #|    if (!stat.isFile() || stat.size > 1000000) return "";
  #|    return fs.readFileSync(target, "utf8");
  #|  } catch (_) { return ""; }
  #|}

///|
extern "js" fn read_batch_binary(
  manifest : String,
  relative : String,
) -> FixedArray[Int] =
  #|(manifest, relative) => {
  #|  const fs = require("node:fs"), path = require("node:path");
  #|  try {
  #|    if (!relative || path.isAbsolute(relative) || relative.includes("\\") || relative.includes(":") || relative.split("/").some(s => !s || s === "." || s === "..")) return [];
  #|    const base = fs.realpathSync(path.dirname(path.resolve(manifest)));
  #|    const target = fs.realpathSync(path.resolve(base, relative));
  #|    if (!target.startsWith(base + path.sep)) return [];
  #|    const stat = fs.statSync(target);
  #|    if (!stat.isFile() || stat.size > 1000000) return [];
  #|    return Array.from(fs.readFileSync(target));
  #|  } catch (_) { return []; }
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
