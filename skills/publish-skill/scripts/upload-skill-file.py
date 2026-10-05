#!/usr/bin/env python3
"""Upload artifact bytes. Credentials stay in the environment, never argv/logs."""
import json
import os
from pathlib import Path
import sys
import urllib.request
import uuid

class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None

try:
    file, name, path = sys.argv[1:]
    boundary = 'skill-' + uuid.uuid4().hex
    payload = bytearray()
    for key, value in [('domain', os.environ.get('CDN_URL', 'https://skill.vyibc.com')), ('name', name), ('path', path)]:
        payload.extend(f'--{boundary}\r\nContent-Disposition: form-data; name="{key}"\r\n\r\n{value}\r\n'.encode())
    payload.extend(f'--{boundary}\r\nContent-Disposition: form-data; name="file"; filename="{name}"\r\nContent-Type: application/octet-stream\r\n\r\n'.encode())
    payload.extend(Path(file).read_bytes())
    payload.extend(f'\r\n--{boundary}--\r\n'.encode())
    headers = {'Content-Type': 'multipart/form-data; boundary=' + boundary, 'User-Agent': 'Vyibc-Skill-Publisher/1.0'}
    token = os.environ.get('FILE_API_TOKEN', '')
    if token:
        headers['Authorization'] = 'Bearer ' + token
    request = urllib.request.Request(os.environ.get('FILE_API_URL', 'https://upload-r2.vyibc.com'), data=bytes(payload), headers=headers, method='POST')
    with urllib.request.build_opener(NoRedirect()).open(request, timeout=90) as response:
        data = json.loads(response.read(65537))
    url = data.get('image_url') or data.get('url')
    if not url:
        raise ValueError('upload_url_missing')
    print(json.dumps({'url': url}))
except Exception:
    print('artifact_upload_unconfirmed', file=sys.stderr)
    sys.exit(1)
