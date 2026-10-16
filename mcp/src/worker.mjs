import {createPublisher,sha} from './publisher.mjs';
const common={skill:{type:'string',pattern:'^[a-z][a-z0-9-]{1,63}$'},version:{type:'string',pattern:'^(0|[1-9]\\d{0,3})\\.(0|[1-9]\\d{0,3})\\.(0|[1-9]\\d{0,3})$'},files:{type:'object',minProperties:1,maxProperties:100,additionalProperties:{type:'string'},description:'Complete UTF-8 Skill files keyed by relative path; SKILL.md required. No credentials, binary files, hidden paths or local server paths.'}};
const requestId={type:'string',pattern:'^[a-z0-9][a-z0-9-]{7,99}$'};
export const TOOLS=[
 {name:'vyibc-skill-publisher_validate_skill',description:'Validate the complete supplied Skill tree, frontmatter, bounds and secret exclusion. Return content digest without uploading or registering in any capability directory.',inputSchema:{type:'object',additionalProperties:false,required:['skill','version','files'],properties:common},annotations:{readOnlyHint:true,idempotentHint:true,destructiveHint:false,openWorldHint:false}},
 {name:'vyibc-skill-publisher_publish_skill',description:'Publish an owner-authorized UTF-8 Skill tree as a complete ZIP and verified install command through the existing skill.vyibc.com uploader. Stable requestId is durable and never reuploads after uncertain failure. Updates this Skill name’s installer alias. Does NOT register in Fleet/Hub/Harness; registration is a separate second phase.',inputSchema:{type:'object',additionalProperties:false,required:['requestId','skill','version','files'],properties:{...common,requestId}},annotations:{readOnlyHint:false,idempotentHint:true,destructiveHint:true,openWorldHint:true}},
 {name:'vyibc-skill-publisher_get_publish_job',description:'Read an owner publication receipt by stable requestId. published means artifacts were uploaded and byte-verified, not that they were registered in a capability square. Failed/publishing jobs are not automatically retried.',inputSchema:{type:'object',additionalProperties:false,required:['requestId'],properties:{requestId}},annotations:{readOnlyHint:true,idempotentHint:true,destructiveHint:false,openWorldHint:false}}
];
const json=(body,status=200,headers={})=>Response.json(body,{status,headers:{'cache-control':'no-store','x-content-type-options':'nosniff',...headers}});
const error=(id,code,message,status=200)=>json({jsonrpc:'2.0',id,error:{code,message}},status);
async function read(request){const chunks=[];let length=0;for await(const chunk of request.body||[]){length+=chunk.length;if(length>900000)throw Error('request_too_large');chunks.push(chunk);}const bytes=new Uint8Array(length);let n=0;for(const chunk of chunks){bytes.set(chunk,n);n+=chunk.length;}return JSON.parse(new TextDecoder('utf-8',{fatal:true}).decode(bytes));}
export default {async fetch(request,env){
 const url=new URL(request.url);
 if(request.method==='GET'&&url.pathname==='/healthz')return json({ok:true,service:'vyibc-skill-publisher',version:'1.0.0',stage:'artifact-publication',hubRegistration:'not_requested'});
 if(url.pathname!=='/mcp')return json({error:'not_found'},404);
 if(url.search)return json({error:'unexpected_query'},400);
 if(request.headers.get('origin')&&request.headers.get('origin')!==url.origin)return json({error:'origin_rejected'},403);
 const supplied=request.headers.get('authorization')||'';
 if(!env.MCP_TOKEN||await sha(supplied)!==await sha('Bearer '+env.MCP_TOKEN))return json({error:'unauthorized'},401);
 if(request.method!=='POST')return json({error:'method_not_allowed'},405,{allow:'POST'});
 if(!request.headers.get('content-type')?.toLowerCase().startsWith('application/json'))return json({error:'json_required'},415);
 let input;try{input=await read(request);}catch(e){return error(null,-32700,e.message==='request_too_large'?e.message:'parse_error',e.message==='request_too_large'?413:400);}
 if(!input||typeof input!=='object'||Array.isArray(input)||input.jsonrpc!=='2.0'||typeof input.method!=='string'||input.id!==undefined&&!['string','number'].includes(typeof input.id))return error(null,-32600,'invalid_request',400);
 if(input.id===undefined)return input.method.startsWith('notifications/')?new Response(null,{status:202}):error(null,-32600,'request_id_required',400);
 const ok=result=>json({jsonrpc:'2.0',id:input.id,result});
 if(input.method==='initialize')return ok({protocolVersion:['2025-03-26','2025-06-18','2025-11-25'].includes(input.params?.protocolVersion)?input.params.protocolVersion:'2025-03-26',serverInfo:{name:'vyibc-skill-publisher',version:'1.0.0'},capabilities:{tools:{listChanged:false}},instructions:'Phase 1 publishes artifacts only. Call the separate Hub admission MCP in phase 2 after the user authorizes registration. Do not send secrets in files or arguments; authentication belongs in the connection configuration.'});
 if(input.method==='ping')return ok({});
 if(input.method==='tools/list')return ok({tools:TOOLS});
 if(input.method!=='tools/call')return error(input.id,-32601,'method_not_found');
 const tool=TOOLS.find(t=>t.name===input.params?.name);if(!tool)return error(input.id,-32602,'unknown_tool');
 try{const value=await createPublisher(env).run(tool.name.slice('vyibc-skill-publisher_'.length),input.params.arguments);return ok({content:[{type:'text',text:JSON.stringify(value)}],structuredContent:value});}
 catch(e){const code=/^[a-z][a-z0-9_]{1,80}$/.test(e.message)?e.message:'publisher_failed';return ok({isError:true,content:[{type:'text',text:JSON.stringify({ok:false,error:code})}]});}
}};
