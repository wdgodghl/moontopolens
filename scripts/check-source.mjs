import fs from 'node:fs';
import path from 'node:path';
import { execFileSync } from 'node:child_process';

const text = execFileSync('moonc', ['-v'], { encoding: 'utf8' });
const match = text.match(/v?(\d+)\.(\d+)\.(\d+)/);
if (!match) throw new Error('Could not determine moonc version');
const version = match.slice(1).map(Number);
const minimum = [0, 10, 14];
let comparison = 0;
for (let i = 0; i < 3 && comparison === 0; i++) comparison = version[i] - minimum[i];
if (comparison < 0) throw new Error('moonc >= 0.10.14 is required');

function sources(dir) {
  return fs.readdirSync(dir, { withFileTypes: true }).flatMap(entry => {
    const file = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      if (entry.name.startsWith('.') || entry.name === '_build' || entry.name.startsWith('out')) return [];
      return sources(file);
    }
    if (!entry.name.endsWith('.mbt') || /_(?:wb)?test\.mbt$/.test(entry.name) || entry.name === 'host.mbt') return [];
    return [file];
  });
}

let nonempty = 0;
let substantive = 0;
for (const file of sources('.')) {
  const lines = fs.readFileSync(file, 'utf8').split(/\r?\n/).map(x => x.trim());
  const code = lines.filter(x => x !== '' && !x.startsWith('//') && !x.startsWith('#|'));
  nonempty += code.length;
  substantive += code.filter(x => !/^[{}()[\],;]+$/.test(x)).length;
}
console.log(`moonc ${version.join('.')}; non-test MoonBit lines: ${nonempty}; excluding punctuation-only lines: ${substantive}`);
console.log('Counts exclude host FFI and tests. These are repository metrics, not the organizer\'s review verdict.');
if (substantive < 400) throw new Error('Insufficient substantive MoonBit source lines');
