#!/usr/bin/env bash
set -euo pipefail

VIDEO_PATH="${1:-}"
PUBLIC_URL="${2:-}"
OUT_DIR="${3:-}"

if [[ -z "$VIDEO_PATH" || ! -f "$VIDEO_PATH" ]]; then
  echo "Usage: qc-video.sh <video.mp4> [public_url] [out_dir]" >&2
  exit 2
fi

if [[ -z "$OUT_DIR" ]]; then
  base="$(basename "$VIDEO_PATH")"
  OUT_DIR="$(pwd)/qc-${base%.*}-$(date +%Y%m%d%H%M%S)"
fi

mkdir -p "$OUT_DIR"

probe_json="$OUT_DIR/ffprobe.json"
volume_txt="$OUT_DIR/volume.txt"
head_txt="$OUT_DIR/public-url-head.txt"
contact_jpg="$OUT_DIR/contact-sheet.jpg"
report_json="$OUT_DIR/qc-report.json"

ffprobe -v error \
  -show_entries format=duration,size:stream=index,codec_type,codec_name,width,height,avg_frame_rate,duration \
  -of json "$VIDEO_PATH" > "$probe_json"

ffmpeg -hide_banner -nostats -i "$VIDEO_PATH" -af volumedetect -f null - > "$volume_txt" 2>&1 || true

duration="$(python3 - "$probe_json" <<'PY'
import json, sys
p=json.load(open(sys.argv[1]))
print(float(p.get("format",{}).get("duration") or 0))
PY
)"

fps_expr="fps=1/7"
if python3 - "$duration" <<'PY'
import sys
d=float(sys.argv[1])
raise SystemExit(0 if d >= 80 else 1)
PY
then
  fps_expr="fps=1/10"
fi

ffmpeg -y -hide_banner -loglevel error -i "$VIDEO_PATH" \
  -vf "${fps_expr},scale=270:480,tile=4x2" \
  -frames:v 1 "$contact_jpg" || true

http_status=""
if [[ -n "$PUBLIC_URL" ]]; then
  curl -I -L --max-time 20 "$PUBLIC_URL" > "$head_txt" 2>&1 || true
  http_status="$(grep -E '^HTTP/' "$head_txt" | tail -n 1 | awk '{print $2}')"
fi

python3 - "$VIDEO_PATH" "$probe_json" "$volume_txt" "$contact_jpg" "$PUBLIC_URL" "$http_status" "$report_json" <<'PY'
import json, re, sys, os
video_path, probe_path, volume_path, contact_path, public_url, http_status, report_path = sys.argv[1:]
p=json.load(open(probe_path))
streams=p.get("streams",[])
video=next((s for s in streams if s.get("codec_type")=="video"),{})
audio=next((s for s in streams if s.get("codec_type")=="audio"),{})
fmt=p.get("format",{})
vol=open(volume_path, errors="ignore").read() if os.path.exists(volume_path) else ""
def find_db(name):
    m=re.search(rf"{name}:\s*(-?\d+(?:\.\d+)?)\s*dB", vol)
    return float(m.group(1)) if m else None
mean=find_db("mean_volume")
peak=find_db("max_volume")
duration=float(fmt.get("duration") or 0)
width=int(video.get("width") or 0)
height=int(video.get("height") or 0)
issues=[]
if not video: issues.append("missing video stream")
if not audio: issues.append("missing audio stream")
if width < 720 or height < 1280: issues.append("resolution too low for vertical short video")
if height <= width: issues.append("video is not vertical")
if duration < 20: issues.append("duration too short")
if mean is not None and mean < -45: issues.append("audio is likely too quiet")
if peak is not None and peak > -1: issues.append("audio may clip")
if public_url and not http_status: issues.append("public URL HEAD status missing")
if public_url and http_status and http_status != "200": issues.append(f"public URL HEAD returned {http_status}")
if not os.path.exists(contact_path) or os.path.getsize(contact_path) == 0: issues.append("contact sheet missing")
score=100
score -= 18 if not video else 0
score -= 18 if not audio else 0
score -= 8 if height <= width else 0
score -= 8 if width < 720 or height < 1280 else 0
score -= 8 if duration < 20 else 0
score -= 8 if mean is not None and mean < -45 else 0
score -= 6 if peak is not None and peak > -1 else 0
score -= 6 if public_url and not http_status else 0
score -= 6 if public_url and http_status and http_status != "200" else 0
score -= 8 if not os.path.exists(contact_path) or os.path.getsize(contact_path) == 0 else 0
report={
  "videoPath": os.path.abspath(video_path),
  "durationSeconds": duration,
  "width": width,
  "height": height,
  "videoCodec": video.get("codec_name",""),
  "audioCodec": audio.get("codec_name",""),
  "meanVolumeDb": mean,
  "maxVolumeDb": peak,
  "publicUrl": public_url,
  "publicHttpStatus": http_status,
  "contactSheet": os.path.abspath(contact_path) if os.path.exists(contact_path) else "",
  "technicalScore": max(0, score),
  "issues": issues,
  "decision": "PASS" if score >= 88 and not issues else "WAIT" if score >= 70 else "REJECT"
}
open(report_path,"w").write(json.dumps(report,ensure_ascii=False,indent=2))
print(json.dumps(report,ensure_ascii=False,indent=2))
PY

echo ""
echo "QC report: $report_json"
echo "Contact sheet: $contact_jpg"
