// Thin Node host adapter: arguments and filesystem only; all analysis is MoonBit.

///|
extern "js" fn argument_count() -> Int32 =
  #|() => process.argv.length - 2

///|
extern "js" fn argument(index : Int32) -> String =
  #|(i) => process.argv[i + 2] || ""

///|
extern "js" fn read_input(path : String) -> String =
  #|(path) => globalThis.__moontopolensHost.read(path, 'text')

///|
extern "js" fn read_binary_input(path : String) -> FixedArray[Int32] =
  #|(path) => globalThis.__moontopolensHost.read(path, 'binary')

///|
extern "js" fn read_nifti_input(path : String) -> FixedArray[Int32] =
  #|(path) => globalThis.__moontopolensHost.read(path, 'nifti')

// Only allow children of the manifest's real directory, even across symlinks.

///|
extern "js" fn read_batch_text(manifest : String, relative : String) -> String =
  #|(manifest,relative) => globalThis.__moontopolensHost.child(manifest,relative,'text')

///|
extern "js" fn read_batch_binary(
  manifest : String,
  relative : String,
) -> FixedArray[Int32] =
  #|(manifest,relative) => globalThis.__moontopolensHost.child(manifest,relative,'binary')

///|
extern "js" fn print_error(message : String) -> Unit =
  #|(message) => globalThis.__moontopolensHost.error(message)

///|
extern "js" fn new_output(path : String) -> Bool =
  #|(path) => globalThis.__moontopolensHost.directory(path)

///|
extern "js" fn save_output(
  dir : String,
  name : String,
  content : String,
) -> Bool =
  #|(dir,name,content) => globalThis.__moontopolensHost.write(dir,name,content)

///|
extern "js" fn initialize_host() -> Unit =
  #|() => {
  #| const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),zlib=require('node:zlib');
  #| const roots=[],inputs=[];let detail='',failed=false;
  #| const explain=(error,action)=>{
  #|  const code=error.code||'IO_ERROR';
  #|  const hints={ENOENT:'路径不存在；检查输入文件或输出父目录。',EACCES:'没有读写权限；选择有权限的文件或目录。',EPERM:'操作被系统拒绝；检查权限及文件占用。',EEXIST:'目标已经存在；请选择新的输出目录，原结果未覆盖。',ENOSPC:'磁盘空间不足；清理空间后重新运行。',ENOTDIR:'路径中的某一项不是目录。',EISDIR:'输入是目录；请选择文件。',UNSUPPORTED_INPUT:'仅接受普通文件；不读取管道、设备或其他特殊文件。',EMPTY_INPUT:'输入文件为空；提供包含数据的文件。',INPUT_TOO_LARGE:'输入超过 1000000 字节限制；显式选择合适的数据子集。',INVALID_UTF8:'输入不是有效 UTF-8 文本；请转换编码后重试。',INVALID_GZIP:'NIfTI gzip 损坏、截断或解压后超过 1000000 字节；检查源文件及大小。'};
  #|  detail=`[${code}] ${action}：${hints[code]||'操作失败，请检查路径、磁盘及文件权限。'}${Number.isFinite(error.actual)?'（实际 '+error.actual+' 字节）':''}`;return detail;
  #| };
  #| const fail=(code,actual)=>{const e=new Error(code);e.code=code;e.actual=actual;throw e;};
  #| const occupied=target=>{try{fs.lstatSync(target);return true;}catch(e){if(e.code==='ENOENT')return false;throw e;}};
  #| const locate=target=>roots.find(r=>target===r.target||target.startsWith(r.target+path.sep));
  #| const staged=(r,target)=>path.join(r.stage,path.relative(r.target,target));
  #| const clean=()=>{for(const r of roots){if(path.dirname(r.stage)===r.parent&&path.basename(r.stage).startsWith('.moontopolens-')){try{fs.rmSync(r.stage,{recursive:true,force:true});}catch(_){}}}};
  #| const host={
  #|  read(file,mode){detail='';try{
  #|   const stat=fs.statSync(file);if(!stat.isFile())fail(stat.isDirectory()?'EISDIR':'UNSUPPORTED_INPUT');if(stat.size===0)fail('EMPTY_INPUT');if(stat.size>1000000)fail('INPUT_TOO_LARGE',stat.size);
  #|   let bytes=fs.readFileSync(file);if(bytes.length>1000000)fail('INPUT_TOO_LARGE',bytes.length);
  #|   inputs.push({index:inputs.length,bytes:bytes.length,sha256:crypto.createHash('sha256').update(bytes).digest('hex')});
  #|   if(mode==='nifti'&&file.toLowerCase().endsWith('.nii.gz')){try{bytes=zlib.gunzipSync(bytes,{maxOutputLength:1000000});}catch(_){fail('INVALID_GZIP');}}
  #|   if(mode!=='text')return Array.from(bytes);
  #|   try{return new TextDecoder('utf-8',{fatal:true}).decode(bytes);}catch(_){fail('INVALID_UTF8');}
  #|  }catch(e){explain(e,'读取输入 '+JSON.stringify(path.basename(file)));return mode==='text'?'':[];}},
  #|  child(manifest,relative,mode){try{
  #|   if(!relative||path.isAbsolute(relative)||relative.includes('\\')||relative.includes(':')||relative.split('/').some(s=>!s||s==='.'||s==='..'))fail('EPERM');
  #|   const base=fs.realpathSync(path.dirname(path.resolve(manifest))),target=fs.realpathSync(path.join(base,relative));
  #|   if(!target.startsWith(base+path.sep))fail('EPERM');return host.read(target,mode);
  #|  }catch(e){explain(e,'读取清单子文件 '+JSON.stringify(relative));return mode==='text'?'':[];}},
  #|  error(message){failed=true;process.stderr.write((detail||message)+'\n');process.exitCode=2;clean();},
  #|  directory(dir){try{
  #|   const target=path.resolve(dir),existing=locate(target);
  #|   if(existing){fs.mkdirSync(staged(existing,target));return true;}
  #|   if(occupied(target))fail('EEXIST');
  #|   const parent=path.dirname(target);if(!fs.statSync(parent).isDirectory())fail('ENOTDIR');
  #|   const stage=fs.mkdtempSync(path.join(parent,'.moontopolens-'));roots.push({target,parent,stage,files:[]});return true;
  #|  }catch(e){explain(e,'创建报告目录');return false;}},
  #|  write(dir,name,content){try{
  #|   const target=path.resolve(dir),r=locate(target);if(!r)fail('ENOENT');
  #|   if(name.includes('\\')||path.basename(name)!==name||name==='.'||name==='..')fail('EPERM');
  #|   const file=path.join(staged(r,target),name),relative=path.relative(r.stage,file).split(path.sep).join('/');
  #|   fs.writeFileSync(file,content,{encoding:'utf8',flag:'wx'});r.files.push({path:relative,bytes:Buffer.byteLength(content),sha256:crypto.createHash('sha256').update(content).digest('hex')});return true;
  #|  }catch(e){explain(e,'写出报告');return false;}}
  #| };
  #| globalThis.__moontopolensHost=host;
  #| process.on('exit',code=>{
  #|  if(failed||code!==0||process.exitCode){clean();return;}
  #|  try{for(const r of roots){
  #|   const manifest={schema_version:1,project:'MoonTopoLens',project_version:'0.20.8',node:process.versions.node,inputs,artifacts:r.files.slice().sort((a,b)=>a.path.localeCompare(b.path))};
  #|   fs.writeFileSync(path.join(r.stage,'run-manifest.json'),JSON.stringify(manifest,null,2)+'\n',{flag:'wx'});
  #|   if(occupied(r.target))fail('EEXIST');fs.renameSync(r.stage,r.target);
  #|  }}catch(e){process.stderr.write(explain(e,'交付完整报告')+'\n');process.exitCode=2;clean();}
  #| });
  #|}
