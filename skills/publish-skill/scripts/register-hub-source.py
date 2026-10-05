#!/usr/bin/env python3
"""Register public Skill artifact metadata, never the publisher credential.

Accepts one JSON document on stdin. May also be used to retry a failed Hub sync
without uploading or regenerating the already-published Skill archive.
"""
import json
import os
from pathlib import Path
import sys
import urllib.error
import urllib.parse
import urllib.request


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


def register(source):
    if os.environ.get('FLEET_HUB_SYNC', '1') == '0':
        return {'status': 'disabled'}
    endpoint = os.environ.get('FLEET_HUB_REGISTER_URL', 'https://fleet.vyibc.com/api/hub/skills/register')
    url = urllib.parse.urlsplit(endpoint)
    if url.scheme != 'https' or url.netloc not in ('fleet.vyibc.com', 'fleet-console.2513120790.workers.dev') or url.path != '/api/hub/skills/register' or url.query or url.fragment:
        return {'status': 'failed', 'error': 'registration_origin_rejected'}
    token = os.environ.get('FLEET_HUB_TOKEN', '').strip()
    if not token:
        path = Path(os.environ.get('FLEET_HUB_TOKEN_FILE', str(Path.home() / '.boss/token')))
        if path.is_file():
            if path.stat().st_mode & 0o077:
                return {'status': 'failed', 'error': 'token_file_must_be_private'}
            token = path.read_text().strip()
    if not token:
        return {'status': 'failed', 'error': 'hub_credential_not_configured'}
    source = {key: source[key] for key in ('skill','script_url','zip_url','zip_sha256','published_at') if key in source}
    request = urllib.request.Request(endpoint, data=json.dumps(source).encode(), headers={'Content-Type': 'application/json', 'Authorization': 'Bearer ' + token, 'User-Agent': 'Vyibc-Fleet-Skill-Publisher/1.0', 'Accept': 'application/json'}, method='POST')
    try:
        with urllib.request.build_opener(NoRedirect()).open(request, timeout=40) as response:
            body = json.loads(response.read(65537))
        if body.get('ok') is not True or body.get('skill') != source['skill']:
            return {'status': 'failed', 'error': 'invalid_registration_response'}
        return {'status': 'registered', 'content_sha256': body['contentSha'], 'published_at': body['publishedAt']}
    except urllib.error.HTTPError as error:
        return {'status': 'failed', 'error': 'hub_http_' + str(error.code)}
    except Exception:
        # Never print HTTP headers, server bodies, or exception reprs.
        return {'status': 'failed', 'error': 'hub_sync_unconfirmed'}


if __name__ == '__main__':
    try:
        result = register(json.load(sys.stdin))
    except Exception:
        result = {'status': 'failed', 'error': 'invalid_registration_input'}
    print(json.dumps(result))
    sys.exit(1 if result['status'] == 'failed' else 0)
