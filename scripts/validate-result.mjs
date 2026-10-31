import fs from 'node:fs';
import {pathToFileURL} from 'node:url';
const schema=JSON.parse(fs.readFileSync(new URL('../contracts/result.schema.json',import.meta.url),'utf8'));
// Validator for the deliberately small JSON Schema vocabulary used by this file.
function validate(s,v,at='$'){
 const fail=m=>{throw Error(at+': '+m);};
 if(s.const!==undefined&&JSON.stringify(v)!==JSON.stringify(s.const))fail('unexpected constant');
 if(s.enum&&!s.enum.some(x=>JSON.stringify(x)===JSON.stringify(v)))fail('value outside enum');
 if(s.type){const types=Array.isArray(s.type)?s.type:[s.type];if(!types.some(t=>t==='null'?v===null:t==='array'?Array.isArray(v):t==='object'?v!==null&&typeof v==='object'&&!Array.isArray(v):t==='integer'?Number.isInteger(v):t==='number'?typeof v==='number'&&Number.isFinite(v):typeof v===t))fail('wrong type');}
 for(const k of s.required||[])if(!v||!Object.hasOwn(v,k))fail('missing '+k);
 if(s.properties&&v&&typeof v==='object')for(const [k,rule]of Object.entries(s.properties))if(Object.hasOwn(v,k))validate(rule,v[k],at+'.'+k);
 if(s.items&&Array.isArray(v))v.forEach((x,i)=>validate(s.items,x,at+'['+i+']'));
 if(s.oneOf){let count=0;for(const rule of s.oneOf)try{validate(rule,v,at);count++;}catch(_){}if(count!==1)fail('expected one report family');}
}
export function validateResult(value){validate(schema,value);return value;}
if(process.argv[1]&&import.meta.url===pathToFileURL(process.argv[1]).href){validateResult(JSON.parse(fs.readFileSync(process.argv[2],'utf8')));console.log('Schema-1 result contract verified.');}
