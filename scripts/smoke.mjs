import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { spawnSync } from 'node:child_process';

const temporary = fs.mkdtempSync(path.join(os.tmpdir(), 'moontopolens-smoke-'));
function cli(args, code = 0) {
  const result = spawnSync('moon', ['run', '--target', 'js', 'cmd/main', '--', ...args], {
    encoding: 'utf8', timeout: 60000, windowsHide: true,
  });
  assert.equal(result.error, undefined);
  assert.equal(result.status, code, `${args.join(' ')}\n${result.stderr}`);
  return result.stdout;
}
function betti(report, dimension, scale) {
  return report.intervals.filter(i => i.dimension === dimension && i.birth <= scale && (i.death === null || scale < i.death)).length;
}
for (const name of ['square', 'rectangle', 'clusters', 'ring-grid', 'periodic-series', 'matrix']) {
  const output = path.join(temporary, name);
  const report = JSON.parse(cli(['analyze', `examples/${name}.json`, '--out', output]));
  assert.equal(report.schema_version, 1);
  assert.deepEqual(JSON.parse(fs.readFileSync(path.join(output, 'report.json'), 'utf8')), report);
  for (const svg of ['barcode.svg', 'diagram.svg']) {
    const text = fs.readFileSync(path.join(output, svg), 'utf8');
    assert.ok(text.startsWith('<svg') && text.endsWith('</svg>'));
    assert.ok(!/NaN|Infinity/.test(text));
  }
  if (name === 'square') {
    assert.equal(betti(report, 1, 1), 1);
    assert.equal(betti(report, 1, Math.SQRT2), 0);
  }
  if (name === 'clusters') assert.equal(betti(report, 0, 0.5), 2);
  if (name === 'ring-grid') {
    assert.equal(betti(report, 1, 0), 1);
    assert.equal(betti(report, 1, 1), 0);
  }
  if (name === 'periodic-series') assert.equal(betti(report, 1, 1.5), 1);
  cli(['analyze', `examples/${name}.json`, '--out', output], 2);
}
const same = JSON.parse(cli(['compare', 'examples/square.json', 'examples/square.json']));
assert.ok(same.distances.every(x => x.bottleneck === 0));
const changed = JSON.parse(cli(['compare', 'examples/square.json', 'examples/rectangle.json']));
assert.ok(changed.distances.find(x => x.dimension === 1).bottleneck > 0);
cli(['analyze', path.join(temporary, 'missing.json')], 2);
cli(['compare'], 2);
cli(['unknown'], 2);
assert.ok(cli(['--help']).includes('MoonTopoLens'));
console.log('CLI smoke passed: six scenarios, exports, comparisons, help and error paths.');
