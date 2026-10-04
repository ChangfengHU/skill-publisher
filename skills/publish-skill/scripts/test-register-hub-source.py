import importlib.util
import json
import os
from pathlib import Path
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('register', Path(__file__).with_name('register-hub-source.py'))
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class RegistrationTests(unittest.TestCase):
    def test_explicit_opt_out_and_missing_credentials_are_distinct(self):
        with patch.dict(os.environ, {'FLEET_HUB_SYNC': '0'}, clear=True):
            self.assertEqual(module.register({})['status'], 'disabled')
        with patch.dict(os.environ, {'FLEET_HUB_TOKEN_FILE': '/nonexistent-fixture'}, clear=True):
            self.assertEqual(module.register({})['error'], 'hub_credential_not_configured')

    def test_redirect_and_wrong_origin_never_receive_credentials(self):
        self.assertIsNone(module.NoRedirect().redirect_request(None, None, 302, '', {}, 'https://wrong.example'))
        with patch.dict(os.environ, {'FLEET_HUB_TOKEN': 'fixture-secret', 'FLEET_HUB_REGISTER_URL': 'https://wrong.example/register'}, clear=True):
            self.assertEqual(module.register({})['error'], 'registration_origin_rejected')

    def test_verified_result_is_structured_and_does_not_leak_token(self):
        class Response:
            def __enter__(self): return self
            def __exit__(self, *args): pass
            def read(self, limit): return json.dumps({'ok': True, 'skill': 'example', 'contentSha': 'a' * 64, 'publishedAt': '20261004000000'}).encode()
        class Opener:
            def open(self, req, timeout):
                self.request = req
                return Response()
        opener = Opener()
        with patch.dict(os.environ, {'FLEET_HUB_TOKEN': 'fixture-secret'}, clear=True), patch.object(module.urllib.request, 'build_opener', return_value=opener):
            result = module.register({'skill': 'example'})
            self.assertEqual(result['status'], 'registered')
            self.assertNotIn('fixture-secret', json.dumps(result))
            self.assertEqual(opener.request.get_header('Authorization'), 'Bearer fixture-secret')
            self.assertEqual(opener.request.get_header('User-agent'), 'Vyibc-Fleet-Skill-Publisher/1.0')


if __name__ == '__main__':
    unittest.main()
