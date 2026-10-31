import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {pathToFileURL} from 'node:url';
export function checkReport(folder){
 const base=fs.realpathSync(folder),m=JSON.parse(fs.readFileSync(path.join(base,'run-manifest.json'),'utf8'));
 if(m.schema_version!==1||m.project!=='MoonTopoLens'||!Array.isArray(m.artifacts))throw Error('Unsupported report manifest');
 const seen=new Set();for(const a of m.artifacts){if(typeof a.path!=='string'||a.path.includes('\\')||a.path.split('/').some(s=>!s||s==='.'||s==='..')||path.isAbsolute(a.path)||seen.has(a.path))throw Error('Unsafe or duplicate artifact path');seen.add(a.path);
  const file=fs.realpathSync(path.join(base,a.path));if(!file.startsWith(base+path.sep))throw Error('Artifact escapes report directory');const bytes=fs.readFileSync(file);if(bytes.length!==a.bytes||crypto.createHash('sha256').update(bytes).digest('hex')!==a.sha256)throw Error('Artifact changed or incomplete: '+a.path);
 }
 return m;
}
if(process.argv[1]&&import.meta.url===pathToFileURL(process.argv[1]).href){const m=checkReport(process.argv[2]);console.log(`报告完整性核验通过：${m.artifacts.length} 个文件，MoonTopoLens ${m.project_version}。此检查不证明算法或输入数据正确。`);}
