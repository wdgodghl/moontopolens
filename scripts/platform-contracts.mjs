import {execFileSync} from 'node:child_process';
const moon=tasks=>{for(const args of tasks)execFileSync('moon',args,{stdio:'inherit',windowsHide:true});};
const node=file=>execFileSync(process.execPath,[file],{stdio:'inherit',windowsHide:true});
// One failing child ends the step on PowerShell as well as Unix shells.
moon([['version','--all'],['build','--target','js'],['test','--target','js'],['test','--target','wasm-gc']]);
execFileSync(process.execPath,['scripts/sync-contracts.mjs','--check'],{stdio:'inherit',windowsHide:true});
for(const file of ['scripts/host-failures.mjs','scripts/platform-smoke.mjs','scripts/verify-docs.mjs'])node(file);
