#!/usr/bin/env bash
set -euo pipefail

# Upload a PDF to Knowhere via the API.
# Usage: ./upload-pdf.sh <API_KEY> [file_path] [namespace]
#   API_KEY   - Knowhere API key (from dashboard Settings → API Keys)
#   file_path - path to PDF file (required)
#   namespace - retrieval namespace (default: "default")

API_BASE="http://localhost:5005/api/v1"
API_KEY="${1:?Usage: $0 <API_KEY> [file_path] [namespace]}"
FILE="${2:?Usage: $0 <API_KEY> [file_path] [namespace]}"
NAMESPACE="${3:-default}"

[ -f "$FILE" ] || { echo "File not found: $FILE"; exit 1; }

echo "1. Creating job (namespace=$NAMESPACE, file=$FILE)..."
RESP=$(curl -s -X POST "$API_BASE/jobs" \
  -H "Authorization: Bearer $API_KEY" \
  -H "Content-Type: application/json" \
  -d "{\"source_type\":\"file\",\"file_name\":\"$FILE\",\"namespace\":\"$NAMESPACE\"}")

JOB_ID=$(echo "$RESP" | python3 -c "import sys,json; print(json.load(sys.stdin)['job_id'])")
UPLOAD_URL=$(echo "$RESP" | python3 -c "import sys,json; print(json.load(sys.stdin)['upload_url'])")
echo "   job_id: $JOB_ID"

echo "2. Uploading file to S3..."
curl -s -X PUT "$UPLOAD_URL" \
  -H "content-type: application/pdf" \
  --data-binary @"$FILE" >/dev/null
echo "   uploaded"

echo "3. Waiting for S3 event propagation..."
sleep 5

echo "4. Confirming upload..."
curl -s -X POST "$API_BASE/jobs/$JOB_ID/confirm-upload" \
  -H "Authorization: Bearer $API_KEY" | python3 -m json.tool

echo ""
echo "Done. Job $JOB_ID is now processing."
echo "Check status: curl -s -H 'Authorization: Bearer $API_KEY' $API_BASE/jobs/$JOB_ID | python3 -m json.tool"
