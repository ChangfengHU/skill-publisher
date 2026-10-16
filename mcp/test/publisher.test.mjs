import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {DatabaseSync} from 'node:sqlite';
import {execFileSync} from 'node:child_process';
import {unzipSync,strFromU8} from 'fflate';
import {validateSkill,createPublisher,sha,installer} from '../src/publisher.mjs';
import worker,{TOOLS} from '../src/worker.mjs';
const input={requestId:'cloud-fixture-publish-001',skill:'fixture-cloud-skill',version:'1.0.0',files:{'SKILL.md':'---\nname: fixture-cloud-skill\ndescription: Fixture publishing workflow\n---\nRead references/example.md.\n','references/example.md':'Complete attachment.\n'}};
function fixture(t,{failUpload=false}={}){
 const raw=new DatabaseSync(':memory:');raw.exec(fs.readFileSync(new URL('../migration.sql',import.meta.url),'utf8'));t.after(()=>raw.close());
 const DB={prepare(sql){return {bind(...values){return {async first(){return raw.prepare(sql).get(...values)||null;},async run(){raw.prepare(sql).run(...values);return {success:true};}};}};}};
 const calls=[],stored=new Map();const env={DB,MCP_TOKEN:'fixture-owner-mcp-token-000',UPLOAD_TOKEN:'fixture-private-upload-token-000'};
 const fetchImpl=async(url,options={})=>{
  calls.push({url,method:options.method||'GET'});
  if(url==='https://upload-r2.vyibc.com'){
   assert.equal(options.headers.Authorization,'Bearer '+env.UPLOAD_TOKEN);assert.equal(options.redirect,'manual');if(failUpload)return new Response(null,{status:403});
   const f=options.body,path=f.get('path'),name=f.get('name');assert.equal(f.get('domain'),'https://skill.vyibc.com');const target='https://skill.vyibc.com/'+(path?path+'/':'')+name;stored.set(target,new Uint8Array(await f.get('file').arrayBuffer()));return Response.json({image_url:target});
  }
  assert.ok(url.startsWith('https://skill.vyibc.com/'),'no Hub or other service call allowed');return stored.has(url)?new Response(stored.get(url)):new Response(null,{status:404});
 };
 return {raw,env,calls,stored,api:createPublisher(env,{fetchImpl,now:()=>new Date('2026-10-16T22:00:00Z')})};
}

test('validation retains all files and refuses missing frontmatter, traversal, binary and secrets',async()=>{
 const valid=await validateSkill(input);assert.equal(valid.fileCount,2);assert.equal(valid.files['references/example.md'],'Complete attachment.\n');
 for(const files of [{...input.files,'../escape':'bad'},{...input.files,'.env':'bad'},{...input.files,'binary':{base64:'AA=='}},{...input.files,'secret':'Bearer secret-token-material-must-be-rejected-000'},{'SKILL.md':'bad'}])await assert.rejects(validateSkill({...input,files}));
 await assert.rejects(validateSkill({...input,files:{'SKILL.md':input.files['SKILL.md'].replace('fixture-cloud-skill','wrong')}}),/identity/);
});
test('phase one uploads and verifies two artifacts, leaves Hub untouched, and replays without uploads',async t=>{
 const f=fixture(t);const dry=await f.api.run('validate_skill',input);assert.equal(dry.hubRegistration,'not_requested');assert.equal(f.calls.length,0);assert.equal(f.raw.prepare('SELECT COUNT(*) n FROM publish_jobs').get().n,0);
 const result=await f.api.run('publish_skill',input);assert.equal(result.status,'published');assert.equal(result.hubRegistration,'not_requested');assert.equal(f.calls.length,4);
 const receipt=result.receipt,archive=f.stored.get(receipt.zip_url);assert.equal(await sha(archive),receipt.zip_sha256);const unpacked=unzipSync(archive);assert.equal(strFromU8(unpacked[input.skill+'/references/example.md']),input.files['references/example.md']);assert.equal(Object.keys(unpacked).length,2);
 execFileSync('bash',['-n'],{input:strFromU8(f.stored.get(receipt.script_url)),stdio:'pipe'});
 assert.match(receipt.script_url,/^https:\/\/skill\.vyibc\.com\/install-fixture-cloud-skill\.sh$/);assert.match(receipt.zip_url,/fixture-cloud-skill-20261016220000\.zip$/);
 assert.equal(JSON.stringify(result).includes(f.env.UPLOAD_TOKEN),false);assert.equal(JSON.stringify(result).includes(f.env.MCP_TOKEN),false);
 assert.equal((await f.api.run('publish_skill',input)).idempotent,true);assert.equal(f.calls.length,4);
 assert.deepEqual((await f.api.run('get_publish_job',{requestId:input.requestId})).receipt,receipt);
 await assert.rejects(f.api.run('publish_skill',{...input,files:{...input.files,'references/example.md':'changed'}}),/request_id_conflict/);assert.equal(f.calls.length,4);
 await assert.rejects(f.api.run('publish_skill',{...input,requestId:'another-publish-001'}),/already_reserved/);
});
test('failed or uncertain publication stays durable and cannot silently reupload',async t=>{
 const f=fixture(t,{failUpload:true});const result=await f.api.run('publish_skill',input);assert.equal(result.status,'failed');assert.equal(result.error,'artifact_publication_unverified');assert.equal(f.calls.length,1);
 const replay=await f.api.run('publish_skill',input);assert.equal(replay.status,'failed');assert.equal(replay.idempotent,true);assert.equal(f.calls.length,1);
});
test('worker authenticates discovery and keeps creation separate from directory registration',async t=>{
 const f=fixture(t);const call=(method,params,headers={})=>worker.fetch(new Request('https://publisher.example/mcp',{method:'POST',headers:{'content-type':'application/json',Authorization:'Bearer '+f.env.MCP_TOKEN,...headers},body:JSON.stringify({jsonrpc:'2.0',id:1,method,params})}),f.env);
 assert.equal((await call('tools/list',{}, {Authorization:'Bearer wrong'})).status,401);
 assert.equal((await call('tools/list',{}, {origin:'https://evil.example'})).status,403);
 assert.equal((await (await call('initialize',{protocolVersion:'2025-03-26'})).json()).result.serverInfo.name,'vyibc-skill-publisher');
 const tools=(await(await call('tools/list',{})).json()).result.tools;assert.equal(tools.length,3);assert.ok(tools.every(x=>!x.name.includes('register')));
 const validated=await(await call('tools/call',{name:TOOLS[0].name,arguments:input})).json();assert.equal(validated.result.structuredContent.hubRegistration,'not_requested');assert.equal(f.calls.length,0);
 const malformed=await(await call('tools/call',{name:TOOLS[0].name,arguments:{}})).json();assert.equal(malformed.result.isError,true);
});
test('installer refuses untrusted origins and injected skill names',()=>{
 assert.throws(()=>installer({skill:'bad;id',zip_url:'https://skill.vyibc.com/s.zip',zip_sha256:'a'.repeat(64)}));
 assert.throws(()=>installer({skill:'good-skill',zip_url:'https://evil.example/s.zip',zip_sha256:'a'.repeat(64)}));
});
