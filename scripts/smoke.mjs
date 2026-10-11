import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { deflateSync, gzipSync } from 'node:zlib';
import { verifyReportUI, verifyComparisonUI, verifyStudyUI, verifyVolumeUI, verifyVolumeSequenceUI } from './report-ui-smoke.mjs';

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
for (const name of ['square', 'rectangle', 'clusters', 'ring-grid', 'two-holes-grid', 'periodic-series', 'matrix', 'short-loop-grid']) {
  const output = path.join(temporary, name);
  const report = JSON.parse(cli(['analyze', `examples/${name}.json`, '--out', output]));
  assert.equal(report.schema_version, 1);
  assert.equal(report.summary.length, 2);
  const concise = JSON.parse(cli(['summary', `examples/${name}.json`]));
  assert.deepEqual(concise.summary, report.summary);
  assert.equal(concise.cutoff, report.cutoff);
  assert.deepEqual(JSON.parse(fs.readFileSync(path.join(output, 'report.json'), 'utf8')), report);
  const views = JSON.parse(fs.readFileSync(path.join(output, 'recommendations.json'), 'utf8'));
  assert.equal(views.schema_version, 1);
  assert.equal(views.recommendations.at(-1).reason, 'final_cutoff');
  assert.equal(views.recommendations.at(-1).scale, report.cutoff);
  const viewRows = fs.readFileSync(path.join(output, 'recommendations.csv'), 'utf8').trim().split('\n');
  assert.equal(viewRows.length, views.recommendations.length + 1);
  for (const view of views.recommendations) {
    assert.equal(view.h0, betti(report, 0, view.scale));
    assert.equal(view.h1, betti(report, 1, view.scale));
    if (view.interval_index !== null) {
      const interval = report.intervals[view.interval_index];
      assert.equal(interval.dimension, 1);
      assert.ok(interval.birth <= view.scale);
      assert.ok(interval.death === null || view.scale < interval.death);
      assert.equal(view.censored, interval.death === null);
    }
  }
  for (const svg of ['barcode.svg', 'diagram.svg']) {
    const text = fs.readFileSync(path.join(output, svg), 'utf8');
    assert.ok(text.startsWith('<svg') && text.endsWith('</svg>'));
    assert.ok(!/NaN|Infinity/.test(text));
  }
  const intervals = fs.readFileSync(path.join(output, 'intervals.csv'), 'utf8').trim().split('\n');
  assert.equal(intervals.length, report.intervals.length + 1);
  const curve = fs.readFileSync(path.join(output, 'betti.csv'), 'utf8').trim().split('\n');
  assert.equal(curve.length, 102);
  const events = fs.readFileSync(path.join(output, 'betti-events.csv'), 'utf8').trim().split('\n');
  assert.equal(events.length, report.betti_events.length + 1);
  for (let i = 0; i < report.betti_events.length; i++) {
    const event = report.betti_events[i];
    assert.deepEqual(events[i + 1].split(',').map(Number), [event.scale, event.h0, event.h1]);
    assert.equal(event.h0, betti(report, 0, event.scale));
    assert.equal(event.h1, betti(report, 1, event.scale));
    if (i) assert.ok(event.scale > report.betti_events[i - 1].scale);
    const snapshot = JSON.parse(cli(['slice', `examples/${name}.json`, String(event.scale)]));
    assert.equal(snapshot.components.length, event.h0);
    assert.equal(snapshot.h0, event.h0);
    assert.equal(snapshot.h1, event.h1);
    const vertices = report.cells.filter(c => c.dimension === 0 && c.value <= event.scale).map(c => c.vertices[0]).sort((a,b)=>a-b);
    assert.deepEqual(snapshot.components.flat().sort((a,b)=>a-b), vertices);
    assert.ok(snapshot.components.every(group => group.length > 0 && group.every((v,j) => !j || v > group[j - 1])));
  }
  verifyReportUI(fs.readFileSync(path.join(output, 'report.html'), 'utf8'), report, name);
  if (name === 'square') {
    assert.equal(betti(report, 1, 1), 1);
    assert.equal(betti(report, 1, Math.SQRT2), 0);
  }
  if (name === 'clusters') {
    assert.equal(betti(report, 0, 0.5), 2);
    assert.equal(views.recommendations[0].reason, 'h0_before_merges');
    assert.ok(views.recommendations[0].h0 > views.recommendations.at(-1).h0);
  }
  if (name === 'ring-grid') {
    assert.equal(betti(report, 1, 0), 1);
    assert.equal(betti(report, 1, 1), 0);
    assert.equal(views.recommendations[0].scale, 0.5);
  }
  if (name === 'periodic-series') assert.equal(betti(report, 1, 1.5), 1);
  if (name === 'short-loop-grid') {
    assert.equal(betti(report, 1, 0.004), 1);
    assert.equal(betti(report, 1, 0.005), 0);
    assert.ok(curve.slice(1).every(row => Number(row.split(',')[2]) === 0));
  }
  cli(['analyze', `examples/${name}.json`, '--out', output], 2);
}
const recommendationOut = path.join(temporary, 'recommend-ring');
const sweepOut = path.join(temporary, 'periodic-sweep');
const sweep = JSON.parse(cli(['sweep', 'examples/periodic-sweep.json', '--out', sweepOut]));
assert.equal(sweep.kind, 'series_sweep');
assert.equal(sweep.case_count, 4);
assert.deepEqual(sweep.cases.map(c => [c.dimension, c.lag]), [[2, 1], [2, 2], [3, 1], [3, 2]]);
assert.deepEqual(sweep.landscape.grid.length, 101);
assert.ok(sweep.cases.every(c => c.h1_landscape_vector.length === 303));
assert.ok(sweep.cases.every(c => c.h1_alive_at_cutoff === c.h1_at_cutoff));
assert.ok(Array.isArray(sweep.recommended_parameters));
assert.ok(sweep.recommended_parameters.every((c,i) => c.rank === i + 1 && c.finite_h1_count > 0));
assert.ok(fs.readFileSync(path.join(sweepOut, 'sweep.html'), 'utf8').includes('时间序列参数扫描'));
assert.deepEqual(JSON.parse(fs.readFileSync(path.join(sweepOut, 'sweep.json'), 'utf8')), sweep);
const sweepSummary = fs.readFileSync(path.join(sweepOut, 'sweep-summary.csv'), 'utf8').trim().split('\n');
const sweepVectors = fs.readFileSync(path.join(sweepOut, 'sweep-landscape.csv'), 'utf8').trim().split('\n');
assert.equal(sweepSummary.length, 5);
assert.equal(sweepVectors.length, 5);
for (let i = 0; i < sweep.cases.length; i++) {
  const item = sweep.cases[i];
  assert.deepEqual(sweepSummary[i + 1].split(',').map(Number), [item.dimension, item.lag, item.stride, item.point_count, item.cell_count, item.h1_finite_count, item.h1_alive_at_cutoff, item.longest_h1_observed_lifetime, item.h1_at_cutoff]);
  assert.deepEqual(sweepVectors[i + 1].split(',').map(Number), [item.dimension, item.lag, item.stride, ...item.h1_landscape_vector]);
}
assert.deepEqual(JSON.parse(cli(['sweep', 'examples/periodic-sweep.json'])), sweep);
cli(['sweep', 'examples/periodic-sweep.json', '--out', sweepOut], 2);
const recommended = JSON.parse(cli(['recommend', 'examples/ring-grid.json', '--out', recommendationOut]));
assert.equal(recommended.recommendations[0].scale, 0.5);
assert.equal(recommended.recommendations[0].reason, 'h1_finite');
assert.deepEqual(JSON.parse(fs.readFileSync(path.join(recommendationOut, 'recommendations.json'), 'utf8')), recommended);
assert.ok(fs.readFileSync(path.join(recommendationOut, 'recommendations.csv'), 'utf8').includes('h1_finite'));
assert.deepEqual(JSON.parse(cli(['recommend', 'examples/ring-grid.json'])), recommended);
cli(['recommend', 'examples/ring-grid.json', '--out', recommendationOut], 2);
const censoredRecommendation = JSON.parse(cli(['recommend', 'examples/square.json']));
assert.ok(censoredRecommendation.recommendations.find(x => x.reason === 'h1_finite'));
const landscapeOut = path.join(temporary, 'landscape');
const landscape = JSON.parse(cli(['landscape', 'examples/two-holes-grid.json', '1', '0', '1', '--out', landscapeOut]));
assert.equal(landscape.vector.length, 303);
assert.equal(landscape.censored_intervals_excluded, 0);
assert.deepEqual(JSON.parse(fs.readFileSync(path.join(landscapeOut, 'landscape.json'), 'utf8')), landscape);
const landscapeRows = fs.readFileSync(path.join(landscapeOut, 'landscape.csv'), 'utf8').trim().split('\n');
assert.equal(landscapeRows.length, 102);
for (let i = 0; i < 101; i++) {
  const height = Math.max(0, Math.min(landscape.grid[i], 1 - landscape.grid[i]));
  assert.deepEqual(landscapeRows[i + 1].split(',').map(Number), [landscape.grid[i], height, height, 0]);
  assert.equal(landscape.values[0][i], height);
  assert.equal(landscape.values[1][i], height);
  assert.equal(landscape.values[2][i], 0);
}
assert.deepEqual(landscape.vector, landscape.values.flat());
cli(['landscape', 'examples/two-holes-grid.json', '1', '0', '1', '--out', landscapeOut], 2);
cli(['landscape', 'examples/square.json', '2', '0', '1'], 2);
cli(['landscape', 'examples/square.json', '1', '1', '0'], 2);
cli(['landscape', 'examples/square.json', '1', 'oops', '1'], 2);
cli(['landscape'], 2);
cli(['slice', 'examples/square.json', '999'], 2);
cli(['slice', 'examples/square.json', 'null'], 2);
cli(['slice'], 2);
const same = JSON.parse(cli(['compare', 'examples/square.json', 'examples/square.json']));
assert.ok(same.distances.every(x => x.bottleneck === 0));
const changed = JSON.parse(cli(['compare', 'examples/square.json', 'examples/rectangle.json']));
assert.ok(changed.distances.find(x => x.dimension === 1).bottleneck > 0);
assert.equal(changed.cutoffs_equal, false);
for (const [left,right] of [['square','square'],['square','rectangle'],['clusters','square']]) {
  const output = path.join(temporary, `compare-${left}-${right}`);
  const report = JSON.parse(cli(['compare',`examples/${left}.json`,`examples/${right}.json`,'--out',output]));
  assert.deepEqual(JSON.parse(fs.readFileSync(path.join(output,'comparison.json'),'utf8')),report);
  verifyComparisonUI(fs.readFileSync(path.join(output,'comparison.html'),'utf8'),report);
  const rows = fs.readFileSync(path.join(output,'matches.csv'),'utf8').trim().split('\n');
  assert.equal(rows.length,1+report.distances.reduce((n,d)=>n+d.matches.length,0));
  let row = 1;
  for (const d of report.distances) {
    for (const m of d.matches) {
      assert.deepEqual(rows[row++].split(','),[String(d.dimension),m.left===null?'':String(m.left.index),m.right===null?'':String(m.right.index),m.kind,m.cost===null?'':String(m.cost)]);
    }
    if(d.bottleneck!==null) assert.equal(Math.max(0,...d.matches.map(m=>m.cost)),d.bottleneck);
  }
  for (const file of ['left-diagram.svg','right-diagram.svg']) assert.ok(fs.readFileSync(path.join(output,file),'utf8').startsWith('<svg'));
  cli(['compare',`examples/${left}.json`,`examples/${right}.json`,'--out',output],2);
}
const square = JSON.parse(cli(['analyze','examples/square.json']));
const loopIndex = square.intervals.findIndex(i=>i.dimension===1);
const sliceOutput = path.join(temporary,'slice-square');
const slice = JSON.parse(cli(['slice','examples/square.json','1','--out',sliceOutput,'--interval',String(loopIndex)]));
assert.equal(slice.h1,1);
assert.deepEqual(JSON.parse(fs.readFileSync(path.join(sliceOutput,'slice.json'),'utf8')),slice);
const svg = fs.readFileSync(path.join(sliceOutput,'slice.svg'),'utf8');
assert.ok(svg.includes('stroke="#fb923c"') && !/NaN|Infinity/.test(svg));
assert.ok(!svg.includes('<polygon'));
cli(['slice','examples/square.json','1','--out',sliceOutput],2);
const gridOpenOut = path.join(temporary, 'slice-ring-open');
const gridFilledOut = path.join(temporary, 'slice-ring-filled');
cli(['slice','examples/ring-grid.json','0','--out',gridOpenOut]);
cli(['slice','examples/ring-grid.json','1','--out',gridFilledOut]);
assert.equal((fs.readFileSync(path.join(gridOpenOut,'slice.svg'),'utf8').match(/<polygon/g) ?? []).length, 0);
assert.equal((fs.readFileSync(path.join(gridFilledOut,'slice.svg'),'utf8').match(/<polygon/g) ?? []).length, 4);
const matrixOutput = path.join(temporary,'slice-matrix');
cli(['slice','examples/matrix.json','0','--out',matrixOutput]);
assert.ok(!fs.existsSync(path.join(matrixOutput,'slice.svg')));
for (const [scale,index] of [['2',String(loopIndex)],['1','-1'],['1','0.5'],['1','9999']]) {
  const invalidOut = path.join(temporary,`invalid-slice-${scale}-${index}`);
  cli(['slice','examples/square.json',scale,'--out',invalidOut,'--interval',index],2);
  assert.ok(!fs.existsSync(invalidOut));
}
cli(['compare','examples/square.json','examples/square.json','--bad','unused'],2);
const imageOut = path.join(temporary, 'ring-image');
const image = JSON.parse(cli(['image', 'examples/ring-image.pgm', '1', '--out', imageOut]));
const grid = JSON.parse(cli(['analyze', 'examples/ring-grid.json']));
assert.deepEqual(image.intervals, grid.intervals);
assert.equal(betti(image, 1, 0), 1);
assert.equal(betti(image, 1, 1), 0);
assert.equal(JSON.parse(fs.readFileSync(path.join(imageOut, 'image-info.json'), 'utf8')).max_value, 1);
assert.ok(fs.readFileSync(path.join(imageOut, 'report.html'), 'utf8').includes('<html'));
const pngOut = path.join(temporary, 'ring-png');
const pngReport = JSON.parse(cli(['image', 'examples/ring-image.png', 'auto', '--out', pngOut]));
assert.equal(betti(pngReport, 1, 0), 1);
assert.equal(JSON.parse(fs.readFileSync(path.join(pngOut, 'image-info.json'), 'utf8')).source_format, 'PNG');
function pngChunk(type, payload) {
  const body = Buffer.concat([Buffer.from(type), payload]);
  let crc = 0xffffffff;
  for (const byte of body) {
    crc ^= byte;
    for (let i = 0; i < 8; i++) crc = (crc & 1) ? (0xedb88320 ^ (crc >>> 1)) : (crc >>> 1);
  }
  const length = Buffer.alloc(4), checksum = Buffer.alloc(4);
  length.writeUInt32BE(payload.length); checksum.writeUInt32BE((crc ^ 0xffffffff) >>> 0);
  return Buffer.concat([length, body, checksum]);
}
function pngWithFilter(color, filter) {
  const channels = color === 0 ? 1 : color === 4 ? 2 : 4;
  const lines = [];
  let previous = Buffer.alloc(3 * channels);
  for (let y = 0; y < 3; y++) {
    const row = Buffer.from(Array.from({length:3}, (_,x) => {
      const value = x === 1 && y === 1 ? 255 : 0;
      return color === 0 ? [value] : color === 4 ? [value,255] : [value,value,value,255];
    }).flat());
    const encoded = Buffer.alloc(row.length);
    for (let i = 0; i < row.length; i++) {
      const left = i >= channels ? row[i-channels] : 0;
      const up = previous[i];
      const corner = i >= channels ? previous[i-channels] : 0;
      let predicted = 0;
      if (filter === 1) predicted = left;
      if (filter === 2) predicted = up;
      if (filter === 3) predicted = Math.floor((left + up) / 2);
      if (filter === 4) {
        const p = left + up - corner, a = Math.abs(p-left), b = Math.abs(p-up), c = Math.abs(p-corner);
        predicted = a <= b && a <= c ? left : b <= c ? up : corner;
      }
      encoded[i] = (row[i] - predicted) & 255;
    }
    lines.push(Buffer.from([filter]), encoded);
    previous = row;
  }
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(3,0); ihdr.writeUInt32BE(3,4); ihdr[8]=8; ihdr[9]=color;
  return Buffer.concat([Buffer.from([137,80,78,71,13,10,26,10]),pngChunk('IHDR',ihdr),pngChunk('IDAT',deflateSync(Buffer.concat(lines))),pngChunk('IEND',Buffer.alloc(0))]);
}
for (const [color, filter] of [[0,1],[4,2],[6,3],[6,4]]) {
  const filename = path.join(temporary, `ring-${color}-${filter}.png`);
  fs.writeFileSync(filename, pngWithFilter(color, filter));
  const report = JSON.parse(cli(['image', filename, 'auto']));
  assert.equal(betti(report, 1, 0), 1);
}
const corruptPng = path.join(temporary, 'corrupt.png');
const pngBytes = fs.readFileSync('examples/ring-image.png');
pngBytes[pngBytes.length - 5] ^= 1;
fs.writeFileSync(corruptPng, pngBytes);
cli(['image', corruptPng, 'auto'], 2);
assert.equal(JSON.parse(fs.readFileSync(path.join(imageOut, 'recommendations.json'), 'utf8')).recommendations[0].scale, 0.5);
const autoOut = path.join(temporary, 'bright-ring');
const automatic = JSON.parse(cli(['image', 'examples/bright-ring.pgm', 'auto', '--invert', '--out', autoOut]));
assert.equal(automatic.cutoff, 0);
assert.equal(betti(automatic, 1, 0), 1);
const autoInfo = JSON.parse(fs.readFileSync(path.join(autoOut, 'image-info.json'), 'utf8'));
assert.equal(autoInfo.cutoff_mode, 'auto_otsu');
assert.equal(autoInfo.inverted, true);
assert.equal(autoInfo.max_value, 255);
const autoWithoutOutput = JSON.parse(cli(['image', 'examples/bright-ring.pgm', 'auto', '--invert']));
assert.deepEqual(autoWithoutOutput.intervals, automatic.intervals);
assert.deepEqual(JSON.parse(cli(['image', 'examples/bright-ring.pgm', '0', '--invert'])).intervals, automatic.intervals);
const unchangedBright = JSON.parse(cli(['image', 'examples/bright-ring.pgm', 'auto']));
assert.notDeepEqual(unchangedBright.intervals, automatic.intervals);
cli(['image', 'examples/ring-image.pgm', '1', '--out', imageOut], 2);
const rawPgm = path.join(temporary, 'raw.pgm');
fs.writeFileSync(rawPgm, Buffer.from('P5\n2 1\n1023\n\x00\x01\x03\xff', 'latin1'));
const rawReport = JSON.parse(cli(['image', rawPgm, '1023']));
assert.equal(rawReport.vertex_count, 2);
const malformedPgm = path.join(temporary, 'malformed.pgm');
fs.writeFileSync(malformedPgm, 'P2 1 1 1 2');
cli(['image', malformedPgm, '1'], 2);
cli(['image', 'examples/ring-image.pgm', 'null'], 2);
cli(['image', 'examples/bright-ring.pgm', 'auto', '--out', path.join(temporary, 'bad-auto'), '--invert'], 2);
const batchOut = path.join(temporary, 'batch');
const batch = JSON.parse(cli(['batch', 'examples/batch-study.json', '--out', batchOut]));
assert.equal(batch.case_count, 6);
assert.equal(batch.comparison_count, 3);
assert.equal(batch.all_pairs, true);
assert.equal(batch.distance_matrix, 'distance-matrix.json');
assert.deepEqual(JSON.parse(fs.readFileSync(path.join(batchOut, 'batch.json'), 'utf8')), batch);
const distanceMatrix = JSON.parse(fs.readFileSync(path.join(batchOut, batch.distance_matrix), 'utf8'));
assert.deepEqual(distanceMatrix.names, batch.cases.map(x => x.name));
for (let i = 0; i < distanceMatrix.names.length; i++) {
  assert.equal(distanceMatrix.h0[i][i], 0);
  assert.equal(distanceMatrix.h1[i][i], 0);
  for (let j = 0; j < distanceMatrix.names.length; j++) {
    assert.equal(distanceMatrix.h0[i][j], distanceMatrix.h0[j][i]);
    assert.equal(distanceMatrix.h1[i][j], distanceMatrix.h1[j][i]);
    assert.equal(distanceMatrix.conditions_aligned[i][j], distanceMatrix.conditions_aligned[j][i]);
  }
}
const squareIndex = distanceMatrix.names.indexOf('square');
const rectangleIndex = distanceMatrix.names.indexOf('rectangle');
assert.equal(distanceMatrix.h1[squareIndex][rectangleIndex], changed.distances.find(x => x.dimension === 1).bottleneck);
assert.equal(distanceMatrix.conditions_aligned[squareIndex][rectangleIndex], false);
const imageIndex = distanceMatrix.names.indexOf('ring-image');
const gridIndex = distanceMatrix.names.indexOf('ring-grid');
assert.equal(distanceMatrix.h0[imageIndex][gridIndex], 0);
assert.equal(distanceMatrix.h1[imageIndex][gridIndex], 0);
const h0Csv = fs.readFileSync(path.join(batchOut, 'distance-h0.csv'), 'utf8').trim().split('\n');
const h1Csv = fs.readFileSync(path.join(batchOut, 'distance-h1.csv'), 'utf8').trim().split('\n');
assert.equal(h0Csv.length, 1 + batch.case_count);
assert.equal(h1Csv.length, 1 + batch.case_count);
const heatmap = fs.readFileSync(path.join(batchOut, 'distance-heatmap.html'), 'utf8');
assert.ok(heatmap.includes('H0 瓶颈距离') && heatmap.includes('H1 瓶颈距离'));
assert.ok(heatmap.includes('class="cell caution"'));
assert.ok(!heatmap.includes('<script') && !heatmap.includes('https://'));
for (const item of batch.cases) {
  const report = JSON.parse(fs.readFileSync(path.join(batchOut, item.report), 'utf8'));
  assert.equal(report.schema_version, 1);
  assert.ok(fs.existsSync(path.join(batchOut, 'cases', item.name, 'report.html')));
  assert.ok(fs.existsSync(path.join(batchOut, 'cases', item.name, 'recommendations.json')));
}
for (const item of batch.comparisons) {
  const report = JSON.parse(fs.readFileSync(path.join(batchOut, item.report), 'utf8'));
  assert.equal(report.distances.length, 2);
  assert.ok(fs.existsSync(path.join(batchOut, 'comparisons', item.name, 'matches.csv')));
}
assert.deepEqual(JSON.parse(fs.readFileSync(path.join(batchOut, 'cases', 'ring-image', 'report.json'), 'utf8')).intervals, image.intervals);
assert.ok(JSON.parse(fs.readFileSync(path.join(batchOut, 'comparisons', 'image-vs-grid', 'comparison.json'), 'utf8')).distances.every(x => x.bottleneck === 0));
assert.deepEqual(JSON.parse(fs.readFileSync(path.join(batchOut, 'cases', 'bright-ring', 'report.json'), 'utf8')).intervals, automatic.intervals);
assert.ok(JSON.parse(fs.readFileSync(path.join(batchOut, 'comparisons', 'bright-vs-grid', 'comparison.json'), 'utf8')).distances.every(x => x.bottleneck === 0));
cli(['batch', 'examples/batch-study.json', '--out', batchOut], 2);
const noMatrixManifest = path.join(temporary, 'no-matrix.json');
fs.writeFileSync(noMatrixManifest, JSON.stringify({cases:[{name:'one',input:'one.json'}]}));
fs.copyFileSync('examples/square.json', path.join(temporary, 'one.json'));
const noMatrixOut = path.join(temporary, 'no-matrix');
const noMatrix = JSON.parse(cli(['batch', noMatrixManifest, '--out', noMatrixOut]));
assert.equal(noMatrix.all_pairs, false);
assert.equal(noMatrix.distance_matrix, null);
assert.ok(!fs.existsSync(path.join(noMatrixOut, 'distance-matrix.json')));
const badManifest = path.join(temporary, 'bad-manifest.json');
fs.writeFileSync(badManifest, JSON.stringify({cases:[{name:'escape',input:'../outside.json'}]}));
const rejectedOut = path.join(temporary, 'rejected-batch');
cli(['batch', badManifest, '--out', rejectedOut], 2);
assert.ok(!fs.existsSync(rejectedOut));
cli(['batch', 'examples/batch-study.json'], 2);
const clusterOut = path.join(temporary, 'cluster-study');
const clusterIndex = JSON.parse(cli(['batch', 'examples/batch-cluster-study.json', '--out', clusterOut]));
assert.equal(clusterIndex.case_count, 4);
for (const degree of [0, 1]) {
  const cluster = JSON.parse(fs.readFileSync(path.join(clusterOut, `cluster-h${degree}.json`), 'utf8'));
  assert.equal(typeof cluster.suggested_cut, 'number');
  assert.equal(cluster.suggested_groups.length, 2);
  assert.ok(fs.readFileSync(path.join(clusterOut, `cluster-h${degree}.svg`), 'utf8').startsWith('<svg'));
}
const stabilityOut = path.join(temporary, 'stability');
const stability = JSON.parse(cli(['stability', 'examples/square.json', '0.02', '--out', stabilityOut]));
assert.equal(stability.kind, 'point_stability');
assert.equal(stability.cases.length, 8);
assert.ok(fs.readFileSync(path.join(stabilityOut, 'stability.html'), 'utf8').includes('点云稳定性分析'));
const sequenceOut = path.join(temporary, 'evolving-loop');
const sequence = JSON.parse(cli(['sequence', 'examples/evolving-loop.json', '--out', sequenceOut]));
assert.equal(sequence.kind, 'topology_sequence');
assert.equal(sequence.frame_count, 3);
assert.equal(sequence.track_count, 1);
assert.deepEqual(sequence.transitions.map(item => [item.continued_h1, item.disappeared_h1]), [[1, 0], [0, 1]]);
assert.equal(sequence.tracks[0].observations.length, 2);
assert.deepEqual(JSON.parse(fs.readFileSync(path.join(sequenceOut, 'sequence.json'), 'utf8')), sequence);
assert.equal(fs.readFileSync(path.join(sequenceOut, 'frames.csv'), 'utf8').trim().split('\n').length, 4);
assert.equal(fs.readFileSync(path.join(sequenceOut, 'transitions.csv'), 'utf8').trim().split('\n').length, 3);
assert.equal(fs.readFileSync(path.join(sequenceOut, 'tracks.csv'), 'utf8').trim().split('\n').length, 3);
const sequenceHtml = fs.readFileSync(path.join(sequenceOut, 'sequence.html'), 'utf8');
assert.ok(sequenceHtml.includes('多帧拓扑变化追踪'));
verifyStudyUI(sequenceHtml, sequence);
cli(['sequence', 'examples/evolving-loop.json', '--out', sequenceOut], 2);
const h2Out = path.join(temporary, 'octahedron-h2');
const h2Report = JSON.parse(cli(['analyze', 'examples/octahedron-h2.json', '--out', h2Out]));
assert.equal(h2Report.homology_dimension, 2);
assert.deepEqual(h2Report.intervals.filter(x => x.dimension === 2).map(x => [x.birth, x.death]), [[1, 2]]);
assert.ok(fs.readFileSync(path.join(h2Out, 'betti-events.csv'), 'utf8').startsWith('scale,H0,H1,H2'));
assert.ok(fs.readFileSync(path.join(h2Out, 'report.html'), 'utf8').includes('H2 空腔'));
const h2ComparisonOut = path.join(temporary, 'h2-comparison');
const h2Comparison = JSON.parse(cli(['compare', 'examples/octahedron-h2.json', 'examples/octahedron-h2-tight.json', '--out', h2ComparisonOut]));
assert.equal(h2Comparison.distances.length, 3);
assert.equal(h2Comparison.distances[2].dimension, 2);
assert.equal(h2Comparison.distances[2].bottleneck, null);
assert.ok(fs.readFileSync(path.join(h2ComparisonOut, 'matches.csv'), 'utf8').includes('\n2,'));
verifyComparisonUI(fs.readFileSync(path.join(h2ComparisonOut, 'comparison.html'), 'utf8'), h2Comparison);
const h2BatchOut = path.join(temporary, 'h2-batch');
const h2Batch = JSON.parse(cli(['batch', 'examples/batch-h2-study.json', '--out', h2BatchOut]));
assert.equal(h2Batch.clustering_h2, 'cluster-h2.json');
const h2Matrix = JSON.parse(fs.readFileSync(path.join(h2BatchOut, 'distance-matrix.json'), 'utf8'));
assert.deepEqual(h2Matrix.h2_analyzed, [true, true, true, false]);
assert.equal(h2Matrix.h2[0][1], 0);
assert.equal(h2Matrix.h2[0][2], null);
assert.equal(h2Matrix.h2[3][3], null);
assert.ok(fs.readFileSync(path.join(h2BatchOut, 'distance-h2.csv'), 'utf8').includes('octahedron,0,0'));
assert.ok(fs.readFileSync(path.join(h2BatchOut, 'distance-heatmap.html'), 'utf8').includes('H2 瓶颈距离'));
assert.ok(fs.readFileSync(path.join(h2BatchOut, 'cluster-h2.svg'), 'utf8').startsWith('<svg'));
assert.equal(JSON.parse(fs.readFileSync(path.join(h2BatchOut, 'comparisons', 'same-h2', 'comparison.json'), 'utf8')).distances.length, 3);
assert.equal(JSON.parse(fs.readFileSync(path.join(h2BatchOut, 'comparisons', 'mixed-dimension', 'comparison.json'), 'utf8')).distances.length, 2);
const volumeOut = path.join(temporary, 'hollow-volume');
const volumeReport = JSON.parse(cli(['analyze', 'examples/hollow-volume.json', '--out', volumeOut]));
assert.equal(volumeReport.kind, 'cubical_volume');
assert.equal(volumeReport.homology_dimension, 2);
assert.equal(volumeReport.cell_count, 125);
assert.equal(betti(volumeReport, 2, 0), 1);
assert.equal(betti(volumeReport, 2, 1), 0);
assert.deepEqual(volumeReport.intervals.filter(x => x.dimension === 2).map(x => [x.birth, x.death]), [[0, 1]]);
const volumeHtml = fs.readFileSync(path.join(volumeOut, 'volume-slices.html'), 'utf8');
verifyVolumeUI(volumeHtml, volumeReport);
const surfaces = JSON.parse(fs.readFileSync(path.join(volumeOut, 'volume-surfaces.json'), 'utf8'));
assert.equal(surfaces.kind, 'volume_h2_representatives');
assert.equal(surfaces.surfaces.length, 1);
assert.ok(surfaces.surfaces[0].face_count > 0);
const evolutionOut = path.join(temporary, 'volume-evolution');
const evolution = JSON.parse(cli(['volume-sequence', 'examples/volume-evolution.json', '--out', evolutionOut]));
assert.deepEqual(evolution.frames.map(frame => frame.h2_at_cutoff), [0, 0, 0]);
assert.deepEqual(evolution.transitions.map(change => [change.disappeared_h2, change.appeared_h2]), [[1, 0], [0, 1]]);
assert.equal(evolution.tracks.length, 2);
verifyVolumeSequenceUI(fs.readFileSync(path.join(evolutionOut, 'volume-sequence.html'), 'utf8'), evolution);
const fieldOut = path.join(temporary, 'volume-stability');
const field = JSON.parse(cli(['field-stability', 'examples/hollow-volume.json', '0', '--out', fieldOut]));
assert.equal(field.source_kind, 'volume');
assert.equal(field.cases.length, 6);
assert.ok(field.cases.every(row => row.bottleneck_by_dimension.every(distance => distance === 0)));
for (const image of ['examples/ring-image.pgm', 'examples/ring-image.png']) {
  const imageField = JSON.parse(cli(['field-stability', image, '1', '0']));
  assert.equal(imageField.source_kind, 'grid');
  assert.ok(imageField.cases.every(row => row.bottleneck_by_dimension.every(distance => distance === 0)));
}
const nii = Buffer.alloc(360);
nii.writeInt32LE(348, 0);
nii.writeInt16LE(3, 40);
for (let offset = 42; offset <= 46; offset += 2) nii.writeInt16LE(2, offset);
nii.writeInt16LE(1, 48);
nii.writeInt16LE(2, 70);
nii.writeInt16LE(8, 72);
nii.writeFloatLE(352, 108);
nii.write('n+1\0', 344, 'ascii');
for (let i = 0; i < 8; i++) nii[352 + i] = i;
const niiPath = path.join(temporary, 'sample.nii');
const gzPath = path.join(temporary, 'sample.nii.gz');
fs.writeFileSync(niiPath, nii);
fs.writeFileSync(gzPath, gzipSync(nii));
for (const pathName of [niiPath, gzPath]) {
  const result = JSON.parse(cli(['volume', pathName, '7']));
  assert.equal(result.kind, 'cubical_volume');
  assert.equal(result.homology_dimension, 2);
  assert.equal(result.vertex_count, 8);
}
cli(['volume', niiPath, 'bad'], 2);
verifyReportUI(fs.readFileSync(path.join(volumeOut, 'report.html'), 'utf8'), volumeReport, 'volume');
const volumeSliceOut = path.join(temporary, 'volume-scale-zero');
const volumeSlice = JSON.parse(cli(['slice', 'examples/hollow-volume.json', '0', '--out', volumeSliceOut]));
assert.equal(volumeSlice.h2, 1);
assert.equal(volumeSlice.active_cells_by_dimension.length, 4);
assert.ok(!fs.existsSync(path.join(volumeSliceOut, 'slice.svg')));
const volumeBatchOut = path.join(temporary, 'volume-batch');
const volumeBatch = JSON.parse(cli(['batch', 'examples/batch-volume-study.json', '--out', volumeBatchOut]));
assert.equal(volumeBatch.case_count, 2);
const volumeMatrix = JSON.parse(fs.readFileSync(path.join(volumeBatchOut, 'distance-matrix.json'), 'utf8'));
assert.deepEqual(volumeMatrix.h2_analyzed, [true, true]);
assert.equal(volumeMatrix.h2[0][1], 0.5);
assert.ok(fs.existsSync(path.join(volumeBatchOut, 'cases', 'hollow', 'volume-slices.html')));
assert.equal(JSON.parse(fs.readFileSync(path.join(volumeBatchOut, 'comparisons', 'cavity-change', 'comparison.json'), 'utf8')).distances[2].bottleneck, 0.5);
const pngBatchOut = path.join(temporary, 'png-batch');
const pngBatch = JSON.parse(cli(['batch', 'examples/batch-png-study.json', '--out', pngBatchOut]));
assert.equal(pngBatch.case_count, 2);
assert.equal(JSON.parse(fs.readFileSync(path.join(pngBatchOut, 'cases', 'png-ring', 'image-info.json'), 'utf8')).source_format, 'PNG');
cli(['slice','examples/square.json','1','--bad','unused'],2);
cli(['analyze', path.join(temporary, 'missing.json')], 2);
cli(['compare'], 2);
cli(['summary'], 2);
cli(['recommend'], 2);
cli(['sweep'], 2);
cli(['sequence'], 2);
cli(['unknown'], 2);
assert.ok(cli(['--help']).includes('MoonTopoLens'));
console.log('CLI smoke passed: core scenarios, H2, PNG/PGM import, batch clustering, stability, temporal tracking, parameter ranking, offline reports, exports and error paths.');
