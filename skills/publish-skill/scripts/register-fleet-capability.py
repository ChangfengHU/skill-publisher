#!/usr/bin/env python3
"""Submit the complete immutable publication to Fleet. No direct Harness write."""
import hashlib
import json
import os
from pathlib import Path
import re
import sys
import urllib.error
import urllib.parse
import urllib.request
import zipfile

class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, *args):
        return None

def build_manifest(source, archive):
    skill = source['skill']
    if not re.fullmatch(r'[a-zA-Z0-9][a-zA-Z0-9_.-]{0,127}', skill):
        raise ValueError('skill_id_invalid')
    raw = Path(archive).read_bytes()
    sha = hashlib.sha256(raw).hexdigest()
    if len(raw) > 10000000 or sha != source['zip_sha256'].removeprefix('sha256:'):
        raise ValueError('archive_checksum_mismatch')
    files, total = [], 0
    with zipfile.ZipFile(archive) as package:
        names = set()
        for entry in package.infolist():
            if entry.is_dir():
                continue
            prefix = skill + '/'
            if not entry.filename.startswith(prefix):
                raise ValueError('archive_root_invalid')
            path = entry.filename[len(prefix):]
            if not path or '\\' in path or path in names or any(p in ('', '.', '..') for p in path.split('/')) or (entry.external_attr >> 16) & 0o170000 == 0o120000:
                raise ValueError('archive_path_invalid')
            names.add(path)
            total += entry.file_size
            if total > 20000000 or len(names) > 2000:
                raise ValueError('archive_inventory_too_large')
            files.append({'path': path, 'sha256': 'sha256:' + hashlib.sha256(package.read(entry)).hexdigest()})
    if 'SKILL.md' not in names:
        raise ValueError('skill_entry_missing')
    stamp = str(source['published_at'])
    if not re.fullmatch(r'\d{14}', stamp):
        raise ValueError('publication_timestamp_invalid')
    version = os.environ.get('CAPABILITY_VERSION', source.get('version', '0.0.0-' + stamp))
    git = source.get('source_git')
    namespace = os.environ.get('CAPABILITY_NAMESPACE', 'fleet')
    manifest = {'schemaVersion': 'capability-manifest/v1', 'capabilityId': 'skill:' + namespace + '/' + skill, 'catalogId': skill, 'kind': 'skill', 'title': source.get('title', skill), 'domain': source.get('domain', 'biz'), 'version': version, 'artifacts': [{'role': 'skill-package', 'url': source['zip_url'], 'sha256': 'sha256:' + sha}], 'dependencies': [], 'targets': [{'consumer': 'harness', 'engine': 'sop-native', 'support': 'declared'}], 'authProfileRefs': [], 'spec': {'entry': 'SKILL.md', 'installerUrl': source['script_url'], 'archiveUrl': source['zip_url'], 'archiveSha256': 'sha256:' + sha, 'publishedStamp': stamp, 'files': sorted(files, key=lambda f: f['path'])}}
    if git:
        manifest['source'] = {'repo': git['repo'], 'commit': git['ref'], 'path': git['path']}
    return manifest

def register(source, archive):
    if os.environ.get('FLEET_HUB_SYNC', '1') == '0':
        return {'status': 'disabled'}
    endpoint = os.environ.get('FLEET_CAPABILITY_REGISTER_URL', 'https://fleet.vyibc.com/api/hub/capabilities/import')
    url = urllib.parse.urlsplit(endpoint)
    if url.scheme != 'https' or url.netloc not in ('fleet.vyibc.com', 'fleet-console.2513120790.workers.dev') or url.path != '/api/hub/capabilities/import' or url.query or url.fragment:
        return {'status': 'failed', 'error': 'registration_origin_rejected'}
    token = os.environ.get('FLEET_CAPABILITY_PUBLISH_TOKEN', '').strip()
    if not token:
        path = Path(os.environ.get('FLEET_CAPABILITY_PUBLISH_TOKEN_FILE', str(Path.home() / '.boss/capability-publisher-token')))
        if path.is_file():
            if path.stat().st_mode & 0o077:
                return {'status': 'failed', 'error': 'token_file_must_be_private'}
            token = path.read_text().strip()
    if not token:
        return {'status': 'failed', 'error': 'fleet_publication_credential_not_configured'}
    try:
        manifest = build_manifest(source, archive)
        key = 'skill:' + source['skill'] + ':' + source['published_at'] + ':' + source['zip_sha256'].removeprefix('sha256:')
        payload = {'manifest': manifest, 'publicationKey': key}
        request = urllib.request.Request(endpoint, data=json.dumps(payload).encode(), headers={'Content-Type': 'application/json', 'Authorization': 'Bearer ' + token, 'User-Agent': 'Vyibc-Fleet-Capability-Publisher/1.0'}, method='POST')
        with urllib.request.build_opener(NoRedirect()).open(request, timeout=40) as response:
            result = json.loads(response.read(65537))
        release = result.get('manifest', {})
        if result.get('ok') is not True or release.get('capabilityId') != manifest['capabilityId'] or not result.get('distributionId') or not re.fullmatch(r'sha256:[a-f0-9]{64}', str(release.get('manifestDigest', ''))):
            return {'status': 'failed', 'error': 'invalid_fleet_publication_response'}
        return {'status': 'published', 'release_id': release['releaseId'], 'manifest_digest': release['manifestDigest'], 'distribution_id': result['distributionId'], 'consumer_status': 'queued', 'idempotent': result.get('idempotent', False)}
    except urllib.error.HTTPError as error:
        return {'status': 'failed', 'error': 'fleet_http_' + str(error.code)}
    except Exception:
        return {'status': 'failed', 'error': 'fleet_publication_unconfirmed'}

if __name__ == '__main__':
    try:
        result = register(json.load(sys.stdin), sys.argv[1])
    except Exception:
        result = {'status': 'failed', 'error': 'invalid_publication_input'}
    print(json.dumps(result))
    sys.exit(1 if result['status'] == 'failed' else 0)
