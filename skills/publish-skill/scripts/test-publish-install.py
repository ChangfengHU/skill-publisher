import email.parser
import email.policy
import http.server
import json
import os
from pathlib import Path
import subprocess
import tempfile
import threading
import unittest
SCRIPT = Path(__file__).with_name('publish-skill.sh')
class PublishingTests(unittest.TestCase):
    def test_immutable_artifacts_and_generated_installer_targets(self):
        artifacts = {}
        class Handler(http.server.BaseHTTPRequestHandler):
            def log_message(self,*args): pass
            def do_POST(self):
                size=int(self.headers['Content-Length']);body=self.rfile.read(size)
                if self.path!='/upload': self.send_response(404);self.end_headers();return
                msg=email.parser.BytesParser(policy=email.policy.default).parsebytes(b'Content-Type: '+self.headers['Content-Type'].encode()+b'\r\n\r\n'+body)
                form={part.get_param('name',header='content-disposition'):part.get_payload(decode=True) for part in msg.iter_parts()}
                path='/'+('/'.join([form['path'].decode().strip('/'),form['name'].decode()])).lstrip('/')
                artifacts[path]=form['file'];data=json.dumps({'image_url':f'http://127.0.0.1:{self.server.server_port}'+path}).encode()
                self.send_response(200);self.end_headers();self.wfile.write(data)
            def do_GET(self):
                body=artifacts.get(self.path.split('?')[0]);self.send_response(200 if body else 404);self.end_headers();self.wfile.write(body or b'')
        server=http.server.ThreadingHTTPServer(('127.0.0.1',0),Handler);thread=threading.Thread(target=server.serve_forever,daemon=True);thread.start()
        try:
            with tempfile.TemporaryDirectory(prefix='publish-contract-') as tmp:
                root=Path(tmp);source=root/'example';source.mkdir();(source/'SKILL.md').write_text('---\nname: example\ndescription: example\n---\n# Example\n');(source/'references').mkdir();(source/'references'/'a.md').write_text('# Reference\n')
                env={**os.environ,'FILE_API_URL':f'http://127.0.0.1:{server.server_port}/upload','CDN_URL':f'http://127.0.0.1:{server.server_port}','ALLOW_EXTERNAL_SKILL_DIR':'1','FLEET_HUB_SYNC':'0','HARNESS_SKILL_SYNC':'0','GENERATE_SOP_CONTRACT':'0','PUBLISH_DOC_URL':'','PUBLISH_BACKUP_DIR':str(root/'backup')}
                result=subprocess.run(['bash',str(SCRIPT),'example',str(source)],env=env,capture_output=True,text=True,timeout=45)
                self.assertEqual(result.returncode,0,result.stderr)
                receipt=json.loads(next(line.split('=',1)[1] for line in result.stdout.splitlines() if line.startswith('PUBLISH_RESULT_JSON=')))
                self.assertIn('/example/releases/',receipt['script_url']);self.assertNotEqual(receipt['script_url'],receipt['latest_script_url']);self.assertNotIn('\n',receipt['install_command'])
                script=artifacts[receipt['script_url'].split(f':{server.server_port}')[1]];installer=root/'install.sh';installer.write_bytes(script)
                for target in ['codex','claude','agents','all']:
                    destination=root/target
                    installed=subprocess.run(['bash',str(installer),target],env={**os.environ,'SKILL_INSTALL_DIR':str(destination)},capture_output=True,text=True,timeout=15)
                    self.assertEqual(installed.returncode,0,installed.stderr);self.assertEqual((destination/'example'/'references'/'a.md').read_text(),'# Reference\n')
                zip_path=receipt['zip_url'].split(f':{server.server_port}')[1];artifacts[zip_path]=b'corrupt'
                bad=root/'corrupt'
                failed=subprocess.run(['bash',str(installer),'claude'],env={**os.environ,'SKILL_INSTALL_DIR':str(bad)},capture_output=True,text=True,timeout=15)
                self.assertNotEqual(failed.returncode,0);self.assertFalse(bad.exists())
        finally: server.shutdown();server.server_close()
if __name__ == '__main__': unittest.main()
