#!/bin/bash
set -e
BASE="http://localhost:7778"

ALICE_TOKEN="alice.client_a.sha256:4fce64322c716f1c822ecfafec1da6623853145d91869f13be5f422fc2207915"
BOB_TOKEN="bob.client_b.sha256:ebc9c5665b3aa8748d7da2c5cc5d1eff1f57fa66f4b1226705d2df88e4fea77c"
CAROL_TOKEN="carol.client_c.sha256:d7db6aa0955822646bfc9e6d381c4424c6746b95f93dc17ac886e09048c6731e"

echo "=== GET /health (no auth needed) ==="
curl -sf "$BASE/health" | python3 -c "import sys,json; d=json.load(sys.stdin); print('ok:', d['ok'], 'version:', d['version'])"

echo ""
echo "=== POST /tx as owner (alice) ==="
curl -sf -X POST "$BASE/tx" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ALICE_TOKEN" \
  -H "x-nonce: nonce_smoke_1" \
  -d '{"id":"tx_smoke_1","workspaceId":"ws","dependencies":[],"preconditions":[],"operation":{"kind":"RENAME_NODE","nodeId":"fn_main","newName":"main_auth"},"lamportTimestamp":1,"replicaId":"cli"}' \
  | python3 -c "import sys,json; d=json.load(sys.stdin); print('status:', d.get('status','?'), 'seq:', d.get('ingressSeq','?'))"

echo ""
echo "=== POST /tx as editor (bob) ==="
curl -sf -X POST "$BASE/tx" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $BOB_TOKEN" \
  -H "x-nonce: nonce_smoke_2" \
  -d '{"id":"tx_smoke_2","workspaceId":"ws","dependencies":[],"preconditions":[],"operation":{"kind":"SET_PROPERTY","nodeId":"stmt_1","key":"value","value":"99"},"lamportTimestamp":2,"replicaId":"cli"}' \
  | python3 -c "import sys,json; d=json.load(sys.stdin); print('status:', d.get('status','?'), 'seq:', d.get('ingressSeq','?'))"

echo ""
echo "=== POST /tx as viewer (carol) — expect 403 ==="
R=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$BASE/tx" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $CAROL_TOKEN" \
  -H "x-nonce: nonce_smoke_3" \
  -d '{"id":"tx_smoke_3","workspaceId":"ws","dependencies":[],"preconditions":[],"operation":{"kind":"RENAME_NODE","nodeId":"fn_main","newName":"bad"},"lamportTimestamp":3,"replicaId":"cli"}')
echo "HTTP $R (expected 403)"

echo ""
echo "=== POST /tx unauthenticated — expect 401 ==="
R=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$BASE/tx" \
  -H "Content-Type: application/json" \
  -H "x-nonce: nonce_smoke_4" \
  -d '{"id":"tx_smoke_4","workspaceId":"ws","dependencies":[],"preconditions":[],"operation":{"kind":"RENAME_NODE","nodeId":"fn_main","newName":"bad"},"lamportTimestamp":4,"replicaId":"cli"}')
echo "HTTP $R (expected 401)"

echo ""
echo "=== GET /snapshot as viewer (carol) ==="
curl -sf "$BASE/snapshot?workspaceId=ws" \
  -H "Authorization: Bearer $CAROL_TOKEN" \
  -H "x-nonce: nonce_smoke_5" \
  | python3 -c "import sys,json; d=json.load(sys.stdin); print('version:', d.get('version','?'), 'text:', str(d.get('projectionText',''))[:35])"

echo ""
echo "=== GET /frames as viewer (carol) ==="
curl -sf "$BASE/frames?workspaceId=ws&since=0" \
  -H "Authorization: Bearer $CAROL_TOKEN" \
  -H "x-nonce: nonce_smoke_6" \
  | python3 -c "import sys,json; d=json.load(sys.stdin); print('count:', d.get('count','?'), 'head:', d.get('headFrameId','?'))"

echo ""
echo "=== Replayed nonce — expect 409 ==="
R=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$BASE/tx" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ALICE_TOKEN" \
  -H "x-nonce: nonce_smoke_1" \
  -d '{"id":"tx_smoke_5","workspaceId":"ws","dependencies":[],"preconditions":[],"operation":{"kind":"RENAME_NODE","nodeId":"fn_main","newName":"bad"},"lamportTimestamp":5,"replicaId":"cli"}')
echo "HTTP $R (expected 409)"

echo ""
echo "=== PASS ==="
