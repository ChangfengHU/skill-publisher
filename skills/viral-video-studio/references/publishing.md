# Publishing and Public URLs

Do not store secrets in the skill. Use environment variables or the user's existing project configuration.

## R2 Upload Endpoint Pattern

If the user provides the common upload endpoint, use:

```bash
curl --location "$CONTENT_R2_UPLOAD_URL" \
  --header "Authorization: Bearer $CONTENT_R2_UPLOAD_TOKEN" \
  --form "file=@/path/to/video.mp4" \
  --form "name=\"video-name.mp4\""
```

Expected response:

```json
{
  "success": true,
  "image_url": "https://cdn.example.com/uploads/date/video.mp4",
  "object_key": "uploads/date/video.mp4"
}
```

Then run `curl -I -L "$image_url"` and require HTTP 200.

## Cloudflare Old Global API Key

When a user explicitly provides old Cloudflare credentials, use request headers:

```bash
X-Auth-Email: user@example.com
X-Auth-Key: <global-api-key>
Content-Type: application/json
```

Never echo the key. Do not write it to repo files.

Useful endpoints:

- verify user: `GET https://api.cloudflare.com/client/v4/user`
- list zones: `GET https://api.cloudflare.com/client/v4/zones?account.id=<account_id>`
- list DNS: `GET https://api.cloudflare.com/client/v4/zones/<zone_id>/dns_records`
- create DNS: `POST https://api.cloudflare.com/client/v4/zones/<zone_id>/dns_records`

Typical CNAME body:

```json
{
  "type": "CNAME",
  "name": "video-skill.example.com",
  "content": "skill.example.com",
  "ttl": 1,
  "proxied": true
}
```

Only create or update DNS records after the user confirms the intended hostname and target. Listing zones is safe for discovery; changing DNS is not.

## Final Publishing Report

Report:

- install command if publishing a skill
- public video URL if rendering a video
- DNS hostname if created
- exact checks run
- secrets handling note: "credentials were used from runtime input/env and not written to the repo"
