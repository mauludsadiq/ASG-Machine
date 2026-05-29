#!/bin/bash
set -e

PORT=7777
BASE="http://localhost:$PORT"

echo "=== ASG Machine smoke test ==="
echo ""

echo "--- GET /health ---"
curl -sf "$BASE/health" | python3 -c "import sys,json; d=json.load(sys.stdin); print('ok:', d['ok'], 'version:', d['version'], 'workspaces:', d['workspaceCount'])"

echo ""
echo "--- POST /tx (rename fn_main -> main_v1) ---"
curl -sf -X POST "$BASE/tx" \
  -H "Content-Type: application/json" \
  -d '{"id":"tx1","workspaceId":"ws","dependencies":[],"preconditions":[],"operation":{"kind":"RENAME_NODE","nodeId":"fn_main","newName":"main_v1"},"lamportTimestamp":1,"replicaId":"cli"}' \
  | python3 -c "import sys,json; d=json.load(sys.stdin); print('status:', d['status'], 'ingressSeq:', d['ingressSeq'])"

echo ""
echo "--- POST /tx (set stmt_1 value=42) ---"
curl -sf -X POST "$BASE/tx" \
  -H "Content-Type: application/json" \
  -d '{"id":"tx2","workspaceId":"ws","dependencies":[],"preconditions":[],"operation":{"kind":"SET_PROPERTY","nodeId":"stmt_1","key":"value","value":"42"},"lamportTimestamp":2,"replicaId":"cli"}' \
  | python3 -c "import sys,json; d=json.load(sys.stdin); print('status:', d['status'], 'ingressSeq:', d['ingressSeq'])"

echo ""
echo "--- POST /tx duplicate (tx1 again) ---"
curl -sf -X POST "$BASE/tx" \
  -H "Content-Type: application/json" \
  -d '{"id":"tx1","workspaceId":"ws","dependencies":[],"preconditions":[],"operation":{"kind":"RENAME_NODE","nodeId":"fn_main","newName":"main_v1"},"lamportTimestamp":1,"replicaId":"cli"}' \
  | python3 -c "import sys,json; d=json.load(sys.stdin); print('status:', d['status'])"

echo ""
echo "--- GET /frames?since=0 ---"
curl -sf "$BASE/frames?workspaceId=ws&since=0" \
  | python3 -c "import sys,json; d=json.load(sys.stdin); print('count:', d['count'], 'headFrameId:', d['headFrameId'])"

echo ""
echo "--- GET /snapshot ---"
curl -sf "$BASE/snapshot?workspaceId=ws" \
  | python3 -c "import sys,json; d=json.load(sys.stdin); print('version:', d['version'], 'frameId:', d['frameId']); print('text:', d['projectionText'])"

echo ""
echo "--- GET /frames?since=headFrameId (expect empty) ---"
HEAD=$(curl -sf "$BASE/frames?workspaceId=ws&since=0" | python3 -c "import sys,json; print(json.load(sys.stdin)['headFrameId'])")
curl -sf "$BASE/frames?workspaceId=ws&since=$HEAD" \
  | python3 -c "import sys,json; d=json.load(sys.stdin); print('count since head:', d['count'])"

echo ""
echo "=== PASS ==="
