import importlib.util
import json
import os
from pathlib import Path
import unittest
from unittest.mock import patch
spec = importlib.util.spec_from_file_location('register_harness', Path(__file__).with_name('register-harness-release.py'))
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
class RegistrationTests(unittest.TestCase):
    def test_disable_and_wrong_origin(self):
        with patch.dict(os.environ, {'HARNESS_SKILL_SYNC': '0'}, clear=True):
            self.assertEqual(module.register({})['status'], 'disabled')
        with patch.dict(os.environ, {'HARNESS_SKILL_REGISTER_URL': 'https://wrong.example/register'}, clear=True):
            self.assertEqual(module.register({})['error'], 'harness_registration_origin_rejected')
        self.assertIsNone(module.NoRedirect().redirect_request(None, None, 302, '', {}, 'https://wrong.example'))
    def test_receipt_must_match_the_exact_release(self):
        source = {'skill': 'example', 'zip_sha256': 'a'*64}
        class Response:
            def __enter__(self): return self
            def __exit__(self, *args): pass
            def read(self, limit): return json.dumps({'ok': True, 'skill': 'example', 'zip_sha256': 'a'*64, 'version_id': 'v1', 'content_sha256': 'sha256:b', 'install_command': "bash <(curl -fsSL 'https://skill.vyibc.com/example/releases/v1/install-example.sh') agents", 'idempotent': True}).encode()
        class Opener:
            def open(self, req, timeout):
                self.request = req
                return Response()
        opener = Opener()
        with patch.dict(os.environ, {}, clear=True), patch.object(module.urllib.request, 'build_opener', return_value=opener):
            result = module.register(source)
            self.assertEqual(result['status'], 'registered')
            self.assertTrue(result['idempotent'])
            self.assertEqual(opener.request.get_header('Authorization'), None)
            self.assertEqual(json.loads(opener.request.data), source)
            self.assertEqual(module.register({'skill':'different','zip_sha256':'b'*64})['status'],'failed')
if __name__ == '__main__': unittest.main()
