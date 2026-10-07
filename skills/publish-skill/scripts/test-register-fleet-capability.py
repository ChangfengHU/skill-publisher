import hashlib
import importlib.util
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import zipfile
spec=importlib.util.spec_from_file_location('fleet_publication',Path(__file__).with_name('register-fleet-capability.py'))
module=importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
class FleetPublicationTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.archive=Path(self.temp.name)/'example.zip'
        with zipfile.ZipFile(self.archive,'w') as package:
            package.writestr('example/SKILL.md','---\nname: example\ndescription: Fixture\n---\n# Example')
            package.writestr('example/references/a.md','# Reference')
        self.source={'skill':'example','script_url':'https://skill.vyibc.com/example/releases/frozen/install-example.sh','zip_url':'https://skill.vyibc.com/example/releases/frozen/example.zip','zip_sha256':hashlib.sha256(self.archive.read_bytes()).hexdigest(),'published_at':'20261007100000'}
    def test_complete_inventory_uses_exact_archive_hashes_and_stable_identity(self):
        with patch.dict(os.environ,{},clear=True):
            manifest=module.build_manifest(self.source,self.archive)
        self.assertEqual(manifest['capabilityId'],'skill:fleet/example')
        self.assertEqual([f['path'] for f in manifest['spec']['files']],['SKILL.md','references/a.md'])
        self.assertEqual(manifest['spec']['files'][1]['sha256'],'sha256:'+hashlib.sha256(b'# Reference').hexdigest())
    def test_git_provenance_does_not_change_consumer_identity(self):
        manifest=module.build_manifest({**self.source,'source_git':{'repo':'owner/repo','ref':'a'*40,'path':'skills/example'}},self.archive)
        self.assertEqual(manifest['source']['commit'],'a'*40)
        self.assertEqual(manifest['capabilityId'],'skill:fleet/example')
    def test_corrupt_archive_never_publishes(self):
        with self.assertRaisesRegex(ValueError,'checksum_mismatch'):
            module.build_manifest({**self.source,'zip_sha256':'0'*64},self.archive)
    def test_traversal_and_missing_skill_entry_are_rejected(self):
        for name in ('example/../outside','example/references/only.md'):
            with self.subTest(name=name):
                with zipfile.ZipFile(self.archive,'w') as package:package.writestr(name,'invalid')
                with self.assertRaises(ValueError):module.build_manifest({**self.source,'zip_sha256':hashlib.sha256(self.archive.read_bytes()).hexdigest()},self.archive)
    def test_origin_and_disabled_checks_precede_any_credential_read(self):
        with patch.dict(os.environ,{'FLEET_HUB_SYNC':'0'},clear=True):self.assertEqual(module.register({},'missing')['status'],'disabled')
        with patch.dict(os.environ,{'FLEET_CAPABILITY_REGISTER_URL':'https://wrong.example/api/hub/capabilities/import'},clear=True):self.assertEqual(module.register({},'missing')['error'],'registration_origin_rejected')
        with patch.dict(os.environ,{'FLEET_CAPABILITY_PUBLISH_TOKEN_FILE':'/nonexistent-fixture'},clear=True):self.assertEqual(module.register({},'missing')['error'],'fleet_publication_credential_not_configured')
    def test_result_retains_distribution_identity_without_claiming_harness_received(self):
        parent=self
        class Response:
            def __enter__(self):return self
            def __exit__(self,*args):pass
            def read(self,limit):return json.dumps({'ok':True,'manifest':{'capabilityId':'skill:fleet/example','releaseId':'release-fixed','manifestDigest':'sha256:'+'a'*64},'distributionId':'distribution-fixed'}).encode()
        class Opener:
            def open(self,request,timeout):
                payload=json.loads(request.data)
                parent.assertEqual(len(payload['manifest']['spec']['files']),2)
                parent.assertIn('20261007100000',payload['publicationKey'])
                return Response()
        with patch.dict(os.environ,{'FLEET_CAPABILITY_PUBLISH_TOKEN':'fixture-scoped-key'},clear=True),patch.object(module.urllib.request,'build_opener',return_value=Opener()):
            result=module.register(self.source,self.archive)
        self.assertEqual(result['status'],'published')
        self.assertEqual(result['consumer_status'],'queued')
        self.assertEqual(result['distribution_id'],'distribution-fixed')
        self.assertNotIn('fixture-scoped-key',json.dumps(result))
if __name__=='__main__':unittest.main()
