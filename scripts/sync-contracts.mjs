import fs from 'node:fs';
const c=JSON.parse(fs.readFileSync('contracts/capabilities.json','utf8')),q=JSON.stringify;
const help='MoonTopoLens — 有界数据的拓扑计算、比较与解释\n数据入口：csv-preview / csv-points / csv-series / image / volume\n分析与解释：analyze / summary / slice / compare / landscape / shortest\n研究工作流：signal-csv / signal-study / reliability / cohort / pores\n其他命令与完整参数：\n'+Object.values(c.commands).map(s=>s.split('\n')[0]).join('\n')+'\n使用 COMMAND --help 查看单个命令。输出目录必须尚不存在。';
let mbt='// Generated from contracts/capabilities.json by scripts/sync-contracts.mjs.\n';
mbt+='///|\npub fn cli_help() -> String { '+q(help)+' }\n';
mbt+='///|\npub fn command_help(command : String) -> String? {\n  match command {\n';
for(const [k,v]of Object.entries(c.commands))mbt+='    '+q(k)+' => Some('+q(v+'\nCLI 输入最大 '+c.cli_input_bytes+' 字节；核心库支持 JS/Wasm GC，文件命令使用 Node.js。')+')\n';
mbt+='    _ => None\n  }\n}\n';
for(const [k,v]of Object.entries(c.limits))mbt+='///|\nlet boundary_'+k+' : Int32 = '+v+'\n';
mbt+='///|\npub fn project_version() -> String { '+q(c.project_version)+' }\n';
let doc='# 能力边界与运行条件\n\n此表由 contracts/capabilities.json 生成，CLI 帮助和核心上限常量使用同一份定义。\n\n| 入口 | 接受范围 | 结果边界 |\n| --- | --- | --- |\n'+c.capabilities.map(x=>`| ${x.kind} | ${x.bounds} | ${x.meaning} |`).join('\n')+'\n\nCLI 文件限制按 UTF-8 文件字节计；库 JSON/CSV 字符串限制按字符计，两者不等同。点数上限不保证细胞预算、匹配预算或运行内存一定够用。达到预算时明确失败，不自动降低精度。\n\n## 可检查与需声明的条件\n\n程序检查格式、尺寸、数值、已计算维度和部分观察条件。单位、独立采样、组间交换性、实验采样方案、材料配准与真实标签的可信性不能从格式验证中证明。普通 compare 允许数学图比较；种类或截止不同时会标明，不能据此认定具有领域可比性。\n\n## 四种结果状态\n\n- observed：已计算，并区分截止前死亡与截止时仍存活。\n- not_computed：未计算该维度或代表链，不代表没有特征。\n- empty：在声明条件下没有相应结果，不代表所有参数下都不存在。\n- unavailable：距离或指标不可得，应查看相邻原因；不以 0 代替。\n\n## 研究工作流\n\n重采样重复率与经验分位数不代表真实概率或正式覆盖率。均值景观带只在明确 IID 独立采样假设和共同观察条件下覆盖固定 31 点网格；不覆盖单个区间或连续曲线。分组检验的 max-statistic 校正在联合可交换的完整零假设下解释。信号分数只表示相对基准变化；材料中心采样内切球不是连续全局最大球，净空连通不是渗透率。详情见 [研究条件](research-workflows.md)。\n';
// Compare normalized formatting, since the official MoonBit formatter owns layout.
const normalize=s=>s.replace(/\s+/g,'').replace(/,([)}])/g,'$1');
for(const [p,s]of [['capabilities.mbt',mbt],['docs/capabilities.md',doc]]){
 if(process.argv.includes('--check')){if(!fs.existsSync(p)||normalize(fs.readFileSync(p,'utf8'))!==normalize(s))throw Error('Contract drift: '+p);}else fs.writeFileSync(p,s);
}
console.log(process.argv.includes('--check')?'Capability documentation and help match the catalog.':'Capability documentation and help generated.');
