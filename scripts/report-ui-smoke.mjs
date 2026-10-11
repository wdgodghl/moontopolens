import assert from 'node:assert/strict';
import vm from 'node:vm';

// A small DOM test double exercises generated interaction logic without adding
// a browser dependency. It does not validate visual layout or browser rendering.
class Element {
  constructor(tag) {
    this.tag = tag; this.children = []; this.attributes = {};
    this.listeners = {}; this.style = { setProperty(name, value) { this[name] = value; } }; this.textContent = ''; this.value = ''; this.checked = false;
  }
  setAttribute(name, value) { this.attributes[name] = value; }
  append(...nodes) { this.children.push(...nodes); }
  replaceChildren(...nodes) { this.children = [...nodes]; }
  addEventListener(event, handler) { this.listeners[event] = handler; }
  fire(event, detail) { assert.ok(this.listeners[event], `No listener for ${event}`); this.listeners[event](detail); }
}

export function verifyStudyUI(html, report) {
  const data = html.match(/<script id="data" type="application\/json">([\s\S]*?)<\/script>/);
  const source = html.match(/<\/script><script>([\s\S]*?)<\/script><\/body>/);
  assert.ok(data && source, 'Study data and script must be embedded');
  assert.deepEqual(JSON.parse(data[1]), report);
  assert.ok(!/<script[^>]+src=|<link[^>]+href=/.test(html));
  const elements = new Map([...html.matchAll(/\bid="([^"]+)"/g)].map(match => [match[1], new Element('element')]));
  elements.get('data').textContent = data[1];
  const document = {
    getElementById(id) { assert.ok(elements.has(id), `Unknown element ${id}`); return elements.get(id); },
    createElement(tag) { return new Element(tag); },
  };
  vm.runInNewContext(source[1], { document }, { timeout: 10000 });
  assert.equal(elements.get('rows').children.length, report.frames.length);
  assert.equal(elements.get('recommendations').children.length, report.transitions.length + report.tracks.length);
  if (report.kind === 'topology_sequence') {
    assert.equal(elements.get('track-timeline').children.length, report.tracks.length + 1);
    assert.equal(elements.get('change-chart').children.length, report.transitions.length);
    assert.equal(elements.get('sequence-visuals').hidden, false);
  }
  assert.ok(elements.get('interpretation').textContent.includes('diagram'));
}

export function verifyReportUI(html, report, name) {
  const data = html.match(/<script id="topology-data" type="application\/json">([\s\S]*?)<\/script>/);
  const source = html.match(/<\/script><script>([\s\S]*?)<\/script><\/body>/);
  assert.ok(data && source, 'Embedded data and interaction script must be present');
  assert.deepEqual(JSON.parse(data[1]), report);
  assert.ok(!/<script[^>]+src=|<link[^>]+href=/.test(html), 'Offline report must not require external assets');
  const elements = new Map([...html.matchAll(/\bid="([^"]+)"/g)].map(match => [match[1], new Element('element')]));
  elements.get('topology-data').textContent = data[1];
  elements.get('scale').value = '1000';
  elements.get('dimension').value = '1';
  elements.get('minimum').value = '0';
  const document = {
    getElementById(id) { assert.ok(elements.has(id), `Unknown element ${id}`); return elements.get(id); },
    createElement(tag) { return new Element(tag); },
    createElementNS(_ns, tag) { return new Element(tag); },
  };
  const api = vm.runInNewContext(source[1] + '\n({fmt,counts,DATA,renderTable})', { document }, { timeout: 10000 });
  assert.equal(api.fmt(1000), '1000');
  assert.equal(api.fmt(0), '0');
  const alive = report.intervals.filter(i => i.dimension === 0 && i.birth <= report.cutoff && (i.death === null || i.death > report.cutoff)).length;
  assert.equal(elements.get('h0').textContent, String(alive));
  const activeFaces = report.kind === 'cubical' ? report.cells.filter(c => c.dimension === 2 && c.value <= report.cutoff).length : 0;
  assert.equal(elements.get('geometry').children.filter(n => n.tag === 'polygon').length, activeFaces);
  const curves = elements.get('curve').children.filter(n => n.tag === 'polyline');
  assert.equal(curves.length, report.homology_dimension + 1);
  const start = report.cells.reduce((low,c) => Math.min(low,c.value), report.cutoff);
  for (let d = 0; d < 2; d++) {
    const top = Math.max(1,...report.betti_events.flatMap(p => [p.h0,p.h1]));
    const expected = report.betti_events.flatMap((p,i) => {
      const x = report.cutoff === start ? 970 : 50 + (p.scale - start)/(report.cutoff - start)*920;
      const value = d ? p.h1 : p.h0;
      const previous = i ? (d ? report.betti_events[i-1].h1 : report.betti_events[i-1].h0) : value;
      return i ? [`${x},${210-previous/top*180}`,`${x},${210-value/top*180}`] : [`${x},${210-value/top*180}`];
    }).join(' ');
    assert.equal(curves[d].attributes.points, expected, 'Curve must retain every exact event at its actual scale');
  }
  if (name === 'matrix') assert.ok(elements.get('geometry').children.some(n => n.textContent.includes('无几何坐标')));
  if (name === 'square' || name === 'ring-grid' || name === 'two-holes-grid' || name === 'short-loop-grid') {
    elements.get('scale').value = name === 'square' ? '500' : name === 'short-loop-grid' ? '4' : '0';
    elements.get('scale').fire('input');
    assert.equal(elements.get('h1').textContent, name === 'two-holes-grid' ? '2' : '1');
    if (name === 'ring-grid') assert.equal(elements.get('geometry').children.filter(n => n.tag === 'polygon').length, 0);
    const first = elements.get('interval-table').children[0];
    assert.ok(first, 'A loop row should be available');
    first.children[0].children[0].fire('click');
    assert.ok(elements.get('geometry').children.some(n => n.attributes.stroke === '#fb923c'), 'Selecting an alive loop highlights its representative');
    elements.get('minimum').value = '999';
    elements.get('minimum').fire('input');
    assert.equal(elements.get('interval-table').children.length, 0);
  }
  elements.get('dimension').value = 'all';
  elements.get('minimum').value = '0';
  elements.get('dimension').fire('input');
  const template = api.DATA.intervals[0];
  assert.ok(template);
  for (let i = 0; i < 120; i++) api.DATA.intervals.push({ ...template });
  api.renderTable();
  assert.equal(elements.get('interval-table').children.length, 50);
  assert.equal(elements.get('previous-page').disabled, true);
  assert.equal(elements.get('next-page').disabled, false);
  elements.get('next-page').fire('click');
  assert.equal(elements.get('interval-table').children.length, 50);
  assert.equal(elements.get('previous-page').disabled, false);
  elements.get('minimum').value = '999';
  elements.get('minimum').fire('input');
  assert.equal(elements.get('interval-table').children.length, 0);
  assert.equal(elements.get('page-status').textContent, '第 1 / 1 页');
  function check(element) {
    for (const [key, value] of Object.entries(element.attributes)) {
      if (['points', 'x', 'y', 'x1', 'y1', 'x2', 'y2', 'cx', 'cy'].includes(key)) assert.ok(!/NaN|Infinity/.test(value));
    }
    for (const child of element.children) check(child);
  }
  check(elements.get('geometry')); check(elements.get('curve'));
}

export function verifyVolumeUI(html, report) {
  const data = html.match(/<script id="volume-data" type="application\/json">([\s\S]*?)<\/script>/);
  const surfaceData = html.match(/<script id="surface-data" type="application\/json">([\s\S]*?)<\/script>/);
  const source = html.match(/<\/script><script>([\s\S]*?)<\/script><\/body>/);
  assert.ok(data && surfaceData && source, 'Volume data and script must be embedded');
  assert.deepEqual(JSON.parse(data[1]), report);
  const surfaces = JSON.parse(surfaceData[1]);
  assert.ok(!/<script[^>]+src=|<link[^>]+href=/.test(html));
  assert.ok(html.includes('href="#explorer"') && html.includes('aria-live="polite"'));
  const elements = new Map([...html.matchAll(/\bid="([^"]+)"/g)].map(match => [match[1], new Element('element')]));
  elements.get('volume-data').textContent = data[1];
  elements.get('surface-data').textContent = surfaceData[1];
  elements.get('scale').value = '1000';
  elements.get('layer').value = '0';
  const document = {
    getElementById(id) { assert.ok(elements.has(id)); return elements.get(id); },
    createElement(tag) { return new Element(tag); },
    createElementNS(_ns, tag) { return new Element(tag); },
  };
  vm.runInNewContext(source[1], { document }, { timeout: 10000 });
  assert.equal(elements.get('layer').children.length, 3);
  assert.equal(elements.get('slice').children.length, 9);
  assert.equal(elements.get('h2').textContent, '0');
  elements.get('scale').value = '0';
  elements.get('layer').value = '1';
  elements.get('scale').fire('input');
  assert.equal(elements.get('h2').textContent, '1');
  assert.equal(elements.get('slice').children.filter(cell => cell.attributes.fill === '#2dd4bf').length, 8);
  assert.ok(elements.get('slice-note').textContent.includes('当前进入 8 个'));
  const h2Index = report.intervals.findIndex(interval => interval.dimension === 2);
  elements.get('feature').value = String(h2Index);
  elements.get('feature').fire('input');
  assert.ok(elements.get('slice').children.some(cell => cell.attributes.fill === '#fb923c'));
  assert.equal(elements.get('surface').children.length, surfaces.surfaces[0].face_count);
  elements.get('yaw').value = '90';
  elements.get('yaw').fire('input');
  assert.equal(elements.get('surface').children.length, surfaces.surfaces[0].face_count);
  const face = elements.get('surface').children[0];
  assert.equal(face.attributes.role, 'button');
  assert.equal(face.attributes.tabindex, '0');
  face.fire('click');
  assert.ok(Number(elements.get('layer').value) >= 0);
  let prevented = false;
  face.fire('keydown', { key: 'Enter', preventDefault() { prevented = true; } });
  assert.equal(prevented, true);
}

export function verifyVolumeSequenceUI(html, report) {
  const data = html.match(/<script id="data" type="application\/json">([\s\S]*?)<\/script>/);
  const source = html.match(/<\/script><script>([\s\S]*?)<\/script><\/body>/);
  assert.ok(data && source);
  assert.deepEqual(JSON.parse(data[1]), report);
  const tables = new Map(['frames', 'transitions', 'tracks'].map(name => [name, new Element('tbody')]));
  const document = {
    getElementById(id) { assert.equal(id, 'data'); return { textContent: data[1] }; },
    createElement(tag) { return new Element(tag); },
    querySelector(selector) { const name = selector.match(/^#(frames|transitions|tracks) tbody$/)?.[1]; assert.ok(name); return tables.get(name); },
  };
  vm.runInNewContext(source[1], { document }, { timeout: 10000 });
  assert.equal(tables.get('frames').children.length, report.frames.length);
  assert.equal(tables.get('transitions').children.length, report.transitions.length);
  assert.equal(tables.get('tracks').children.length, report.tracks.length);
}

export function verifyComparisonUI(html, report) {
  const data = html.match(/<script id="comparison-data" type="application\/json">([\s\S]*?)<\/script>/);
  const source = html.match(/<\/script><script>([\s\S]*?)<\/script><\/main>/);
  assert.ok(data && source);
  assert.deepEqual(JSON.parse(data[1]), report);
  assert.ok(!/<script[^>]+src=|<link[^>]+href=/.test(html));
  const elements = new Map([...html.matchAll(/\bid="([^"]+)"/g)].map(m => [m[1], new Element('element')]));
  elements.get('comparison-data').textContent = data[1];
  elements.get('dimension').value = 'all';
  const document = {
    getElementById(id) { assert.ok(elements.has(id)); return elements.get(id); },
    createElement(tag) { return new Element(tag); },
  };
  vm.runInNewContext(source[1], { document }, { timeout: 10000 });
  assert.equal(elements.get('matches').children.length, Math.min(200, report.distances.reduce((n,d)=>n+d.matches.length,0)));
  for (const dimension of report.distances.map(d => String(d.dimension))) {
    elements.get('dimension').value = dimension;
    elements.get('dimension').fire('input');
    assert.equal(elements.get('matches').children.length, Math.min(200, report.distances[Number(dimension)].matches.length));
    elements.get('diagonal-only').checked = true;
    elements.get('diagonal-only').fire('input');
    const expected = report.distances[Number(dimension)].matches.filter(m=>m.kind==='diagonal'||m.kind==='unmatched_censored').length;
    assert.equal(elements.get('matches').children.length, Math.min(200,expected));
    elements.get('diagonal-only').checked = false;
  }
  if (report.distances.some(d=>d.bottleneck===null)) assert.ok(elements.get('distances').textContent.includes('无有限匹配'));
  if (!report.cutoffs_equal || !report.complex_kinds_equal) assert.ok(elements.get('comparability').textContent.includes('不同'));
}
