import {zipSync,strToU8} from 'fflate';
import {parse as yaml} from 'yaml';
const assert=(ok,code)=>{if(!ok)throw Error(code);};
const object=v=>v!==null&&typeof v==='object'&&!Array.isArray(v);
const secretPattern=/(?:-----BEGIN [A-Z ]*PRIVATE KEY|Bearer\s+[A-Za-z0-9._~+\/-]{16,}|(?:vmat|vvat|vhrt|vbpa)_[A-Za-z0-9_-]{20,}|sk-[A-Za-z0-9]{24,})/;
export const sha=async bytes=>Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256',typeof bytes==='string'?strToU8(bytes):bytes)),v=>v.toString(16).padStart(2,'0')).join('');
export async function validateSkill(input,forbidden=[]){
 assert(object(input)&&Object.keys(input).every(k=>['skill','version','files','requestId'].includes(k)),'invalid_input');
 assert(/^[a-z][a-z0-9-]{1,63}$/.test(input.skill||'')&&!['constructor','prototype'].includes(input.skill),'invalid_skill');
 assert(/^(0|[1-9]\d{0,3})\.(0|[1-9]\d{0,3})\.(0|[1-9]\d{0,3})$/.test(input.version||''),'invalid_version');
 assert(object(input.files)&&Object.keys(input.files).length>0&&Object.keys(input.files).length<=100,'invalid_files');
 let total=0;const files={},hashes={};
 for(const path of Object.keys(input.files).sort()){
  assert(path.length<=180&&!/[\\\u0000-\u001f]/.test(path)&&path.split('/').every(part=>part&&!part.startsWith('.')&&!['node_modules','__MACOSX','__proto__','constructor','prototype'].includes(part)),'unsafe_file_path');
  const value=input.files[path];assert(typeof value==='string'&&!value.includes('\0'),'text_files_only');
  const bytes=strToU8(value);total+=bytes.length;assert(bytes.length<=200000&&total<=600000,'skill_size_limit');
  assert(!secretPattern.test(value)&&!forbidden.some(s=>typeof s==='string'&&s.length>=8&&value.includes(s)),'secret_material_rejected');
  files[path]=value;hashes[path]=await sha(bytes);
 }
 const md=files['SKILL.md'];assert(typeof md==='string'&&md.startsWith('---\n'),'skill_entry_required');const end=md.indexOf('\n---',4);assert(end>4,'invalid_frontmatter');
 let front;try{front=yaml(md.slice(4,end));}catch{throw Error('invalid_frontmatter');}
 assert(front?.name===input.skill&&typeof front.description==='string'&&front.description.trim(),'skill_frontmatter_identity_mismatch');
 return {skill:input.skill,version:input.version,files,hashes,description:front.description,digest:await sha(JSON.stringify({skill:input.skill,version:input.version,hashes})),fileCount:Object.keys(files).length,totalBytes:total};
}
export function installer({skill,zip_url,zip_sha256}){
 assert(/^[a-z][a-z0-9-]{1,63}$/.test(skill)&&/^https:\/\/skill\.vyibc\.com\/[a-z0-9/_.-]+\.zip$/.test(zip_url)&&/^[a-f0-9]{64}$/.test(zip_sha256),'invalid_installer_source');
 return `#!/usr/bin/env bash
set -euo pipefail
umask 077
SKILL_NAME="${skill}"
ZIP_URL="${zip_url}"
ZIP_SHA256="${zip_sha256}"
case "\${1:-codex}" in
 codex) base="$HOME/.codex/skills" ;;
 claude) base="$HOME/.claude/skills" ;;
 agents) base="$HOME/.agents/skills" ;;
 *) printf '%s\\n' 'Usage: bash install.sh codex|claude|agents' >&2; exit 2 ;;
esac
command -v python3 >/dev/null || { printf '%s\\n' 'Python 3 is required'; exit 1; }
mkdir -p "$base"
stage="$(mktemp -d "$base/.skill-install.XXXXXXXX")"
trap 'rm -rf -- "$stage"' EXIT
curl --fail --silent --show-error --proto '=https' --max-time 60 "$ZIP_URL" -o "$stage/skill.zip"
python3 - "$stage/skill.zip" "$stage/extracted" "$SKILL_NAME" "$ZIP_SHA256" <<'PY'
import hashlib,pathlib,sys,zipfile
archive,root,name,expected=sys.argv[1:]
raw=pathlib.Path(archive).read_bytes()
if len(raw)>1000000 or hashlib.sha256(raw).hexdigest()!=expected:raise SystemExit('Skill archive digest mismatch')
destination=pathlib.Path(root);destination.mkdir(mode=0o700)
with zipfile.ZipFile(archive) as z:
 entries=z.infolist()
 if len(entries)>100 or sum(e.file_size for e in entries)>600000:raise SystemExit('Archive bounds exceeded')
 seen=set()
 for e in entries:
  p=pathlib.PurePosixPath(e.filename)
  if len(p.parts)<2 or p.parts[0]!=name or p.is_absolute() or any(x.startswith('.') for x in p.parts) or str(p) in seen or '\\\\' in e.filename or ((e.external_attr>>16)&0o170000) not in (0,0o100000,0o040000):raise SystemExit('Unsafe archive path')
  seen.add(str(p));target=destination.joinpath(*p.parts)
  if e.is_dir():target.mkdir(parents=True,exist_ok=True,mode=0o700)
  else:
   target.parent.mkdir(parents=True,exist_ok=True,mode=0o700);data=z.read(e);target.write_bytes(data);target.chmod(0o700 if data.startswith(b'#!') or p.suffix=='.sh' else 0o600)
(destination/name/'.publisher-archive-sha256').write_text(expected)
PY
target="$base/$SKILL_NAME"
if [ -e "$target" ] || [ -L "$target" ]; then
 diff -qr "$stage/extracted/$SKILL_NAME" "$target" >/dev/null || { printf '%s\\n' 'Existing Skill differs; preserve it and review the new version before replacing it.' >&2; exit 1; }
else
 mv "$stage/extracted/$SKILL_NAME" "$target"
fi
printf '%s\\n' "Installed: $SKILL_NAME -> $target"
`;
}
export function createPublisher(env,{fetchImpl=fetch,now=()=>new Date()}={}){
 const lookup=id=>env.DB.prepare('SELECT * FROM publish_jobs WHERE request_id=?').bind(id).first();
 const publicRow=row=>({ok:row.status==='published',requestId:row.request_id,status:row.status,skill:row.skill,version:row.version,digest:row.digest,...(row.receipt_json?{receipt:JSON.parse(row.receipt_json)}:{}),...(row.error_code?{error:row.error_code}:{}),hubRegistration:'not_requested'});
 async function upload(data,name,path,expected){
  assert(typeof env.UPLOAD_TOKEN==='string'&&env.UPLOAD_TOKEN.length>0,'upload_unconfigured');
  const form=new FormData();form.append('file',new Blob([data]),name);form.append('domain','https://skill.vyibc.com');form.append('name',name);form.append('path',path);
  const response=await fetchImpl('https://upload-r2.vyibc.com',{method:'POST',redirect:'manual',signal:AbortSignal.timeout(15000),headers:{Authorization:'Bearer '+env.UPLOAD_TOKEN},body:form});
  assert(response.ok,'upload_failed');const result=await response.json();assert(result.image_url===expected,'upload_destination_mismatch');
  // Read back original bytes before declaring this artifact published.
  const read=await fetchImpl(expected,{redirect:'manual',signal:AbortSignal.timeout(15000),headers:{'cache-control':'no-cache'}});assert(read.ok,'upload_readback_failed');
  const limit=1000000,parts=[];let length=0;for await(const part of read.body){length+=part.length;if(length>limit){throw Error('readback_limit');}parts.push(part);}
  const actual=new Uint8Array(length);let offset=0;for(const part of parts){actual.set(part,offset);offset+=part.length;}
  assert(await sha(actual)===await sha(data),'upload_readback_digest_mismatch');
 }
 return {async run(name,args){
  if(name==='get_publish_job'){
   assert(object(args)&&Object.keys(args).length===1&&/^[a-z0-9][a-z0-9-]{7,99}$/.test(args.requestId||''),'invalid_request_id');const row=await lookup(args.requestId);assert(row,'publish_job_not_found');return publicRow(row);
  }
  const skill=await validateSkill(args,[env.MCP_TOKEN,env.UPLOAD_TOKEN]);
  if(name==='validate_skill')return {ok:true,skill:skill.skill,version:skill.version,digest:skill.digest,fileCount:skill.fileCount,totalBytes:skill.totalBytes,hubRegistration:'not_requested'};
  assert(name==='publish_skill','unknown_tool');assert(/^[a-z0-9][a-z0-9-]{7,99}$/.test(args.requestId||''),'invalid_request_id');
  const previous=await lookup(args.requestId);if(previous){assert(previous.digest===skill.digest,'request_id_conflict');return {...publicRow(previous),idempotent:true};}
  const existing=await env.DB.prepare('SELECT * FROM publish_jobs WHERE skill=? AND version=?').bind(skill.skill,skill.version).first();assert(!existing,'skill_version_already_reserved');
  const date=now(),timestamp=date.toISOString(),stamp=timestamp.replace(/\D/g,'').slice(0,14);
  try{await env.DB.prepare("INSERT INTO publish_jobs(request_id,skill,version,digest,status,created_at) VALUES(?,?,?,?,'publishing',?)").bind(args.requestId,skill.skill,skill.version,skill.digest,timestamp).run();}catch{throw Error('publish_reservation_conflict');}
  try{
   const entries=Object.fromEntries(Object.entries(skill.files).map(([path,value])=>[skill.skill+'/'+path,strToU8(value)]));const zip=zipSync(entries,{mtime:new Date('2026-01-01T00:00:00Z')});
   const path=skill.skill+'/mcp-release/'+args.requestId,name=skill.skill+'-'+stamp+'.zip';
   const source={skill:skill.skill,script_url:'https://skill.vyibc.com/install-'+skill.skill+'.sh',zip_url:'https://skill.vyibc.com/'+path+'/'+name,zip_sha256:await sha(zip),published_at:stamp};
   await upload(zip,name,path,source.zip_url);
   const script=installer(source);await upload(strToU8(script),'install-'+skill.skill+'.sh','',source.script_url);
   const receipt={schema:'skill-publication/v1',...source,version:skill.version,content_sha256:skill.digest,files:skill.hashes,fileCount:skill.fileCount,install_command:'bash <(curl -fsSL '+source.script_url+'?ts='+stamp+')',hubRegistration:'not_requested'};
   await env.DB.prepare("UPDATE publish_jobs SET status='published',receipt_json=? WHERE request_id=? AND status='publishing'").bind(JSON.stringify(receipt),args.requestId).run();return publicRow(await lookup(args.requestId));
  }catch{
   await env.DB.prepare("UPDATE publish_jobs SET status='failed',error_code='artifact_publication_unverified' WHERE request_id=? AND status='publishing'").bind(args.requestId).run();return publicRow(await lookup(args.requestId));
  }
 }};
}
