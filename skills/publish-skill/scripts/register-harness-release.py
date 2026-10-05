#!/usr/bin/env python3
"""Register an already uploaded immutable Skill release; retries never re-upload."""
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import urllib.error
import urllib.parse
import urllib.request

class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None

def source_metadata(directory):
    result = {}
    try:
        def git(*args):
            return subprocess.check_output(['git', '-C', str(directory), *args], stderr=subprocess.DEVNULL, text=True).strip()
        root = Path(git('rev-parse', '--show-toplevel')).resolve()
        remote = git('remote', 'get-url', 'origin')
        match = re.fullmatch(r'(?:https://github.com/|git@github.com:)([\w.-]+/[\w.-]+?)(?:\.git)?', remote)
        if match:
            result['source_git'] = {'repo': match[1], 'ref': git('rev-parse', 'HEAD'), 'path': str(Path(directory).resolve().relative_to(root))}
    except (OSError, ValueError, subprocess.CalledProcessError):
        pass
    markdown = Path(directory) / 'SKILL.md'
    if markdown.is_file():
        content = markdown.read_text()
        heading = re.search(r'^#\s+(.+)', content, re.M)
        if heading:
            result['title'] = heading[1]
    version = os.environ.get('SKILL_VERSION', '')
    if version:
        result['version'] = version
    return result

def register(source):
    if os.environ.get('HARNESS_SKILL_SYNC', '1') == '0':
        return {'status': 'disabled'}
    endpoint = os.environ.get('HARNESS_SKILL_REGISTER_URL', 'https://control.vyibc.com/api/capabilities/skills/releases')
    url = urllib.parse.urlsplit(endpoint)
    if url.scheme != 'https' or url.netloc != 'control.vyibc.com' or url.path != '/api/capabilities/skills/releases' or url.query or url.fragment:
        return {'status': 'failed', 'error': 'harness_registration_origin_rejected'}
    request = urllib.request.Request(endpoint, data=json.dumps(source).encode(), headers={'Content-Type': 'application/json', 'User-Agent': 'Vyibc-Harness-Skill-Publisher/1.0', 'Accept': 'application/json'}, method='POST')
    try:
        with urllib.request.build_opener(NoRedirect()).open(request, timeout=90) as response:
            body = json.loads(response.read(65537))
        if body.get('ok') is not True or body.get('skill') != source['skill'] or body.get('zip_sha256') != source['zip_sha256']:
            return {'status': 'failed', 'error': 'invalid_harness_registration_response'}
        return {'status': 'registered', 'version_id': body['version_id'], 'install_command': body['install_command'], 'idempotent': body.get('idempotent', False), 'content_sha256': body['content_sha256']}
    except urllib.error.HTTPError as error:
        try:
            reason = json.loads(error.read(65537)).get('reason', '')
        except Exception:
            reason = ''
        return {'status': 'failed', 'error': reason if re.fullmatch(r'release_[a-z_]+', reason) else 'harness_http_' + str(error.code)}
    except Exception:
        return {'status': 'failed', 'error': 'harness_sync_unconfirmed'}

if __name__ == '__main__':
    try:
        if len(sys.argv) == 3 and sys.argv[1] == '--source-metadata':
            print(json.dumps(source_metadata(sys.argv[2]))); sys.exit(0)
        source = json.load(sys.stdin)
        directory = os.environ.get('PUBLISH_SKILL_SOURCE_DIR')
        if directory:
            source.update(source_metadata(directory))
        result = register(source)
    except Exception:
        result = {'status': 'failed', 'error': 'invalid_registration_input'}
    print(json.dumps(result))
    sys.exit(1 if result['status'] == 'failed' else 0)
