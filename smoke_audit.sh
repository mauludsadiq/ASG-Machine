#!/bin/bash
set -e
BASE="http://localhost:7779"
ALICE="alice.client_a.sha256:4fce64322c716f1c822ecfafec1da6623853145d91869f13be5f422fc2207915"
BOB="bob.client_b.sha256:ebc9c5665b3aa8748d7da2c5cc5d1eff1f57fa66f4b1226705d2df88e4fea77c"
CAROL="carol.client_c.sha256:d7db6aa0955822646bfc9e6d381c4424c6746b95f93dc17ac886e09048c6731e"
echo "=== GET /health ==="
curl -sf "$BASE/health" | python3 -c "import sys,json; d=json.load(sys.stdin); print('ok:', d['ok'], 'version:', d['version'])"
echo "=== POST /tx alice ==="
curl -sf -X POST "$BASE/tx" -H "Content-Type: application/json" -H "Authorization: Bearer $ALICE" -H "x-nonce: n1" -d '{"id":"tx1","workspaceId":"ws","dependencies":[],"preconditions":[],"operation":{"kind":"RENAME_NODE","nodeId":"fn_main","newName":"main_v1"},"lamportTimestamp":1,"replicaId":"cli"}' | python3 -c "import sys,json; d=json.load(sys.stdin); print('status:', d.get('status'), 'seq:', d.get('ingressSeq'))"
echo "=== POST /tx bob ==="
curl -sf -X POST "$BASE/tx" -H "Content-Type: application/json" -H "Authorization: Bearer $BOB" -H "x-nonce: n2" -d '{"id":"tx2","workspaceId":"ws","dependencies":[],"preconditions":[],"operation":{"kind":"SET_PROPERTY","nodeId":"stmt_1","key":"value","value":"99"},"lamportTimestamp":2,"replicaId":"cli"}' | python3 -c "import sys,json; d=json.load(sys.stdin); print('status:', d.get('status'), 'seq:', d.get('ingressSeq'))"
echo "=== POST /tx carol expect 403 ==="
R=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$BASE/tx" -H "Content-Type: application/json" -H "Authorization: Bearer $CAROL" -H "x-nonce: n3" -d '{"id":"tx3","workspaceId":"ws","dependencies":[],"preconditions":[],"operation":{"kind":"RENAME_NODE","nodeId":"fn_main","newName":"bad"},"lamportTimestamp":3,"replicaId":"cli"}')
echo "HTTP $R (expected 403)"
echo "=== POST /tx unauth expect 401 ==="
R=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$BASE/tx" -H "Content-Type: application/json" -H "x-nonce: n4" -d '{"id":"tx4","workspaceId":"ws","dependencies":[],"preconditions":[],"operation":{"kind":"RENAME_NODE","nodeId":"fn_main","newName":"bad"},"lamportTimestamp":4,"replicaId":"cli"}')
echo "HTTP $R (expected 401)"
echo "=== Replayed nonce expect 409 ==="
R=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$BASE/tx" -H "Content-Type: application/json" -H "Authorization: Bearer $ALICE" -H "x-nonce: n1" -d '{"id":"tx5","workspaceId":"ws","dependencies":[],"preconditions":[],"operation":{"kind":"RENAME_NODE","nodeId":"fn_main","newName":"bad"},"lamportTimestamp":5,"replicaId":"cli"}')
echo "HTTP $R (expected 409)"
echo "=== GET /admin/metrics alice ==="
curl -sf "$BASE/admin/metrics?workspaceId=ws" -H "Authorization: Bearer $ALICE" -H "x-nonce: n5" | python3 -c "import sys,json; d=json.load(sys.stdin); print('txAccepted:', d.get('txAccepted'), 'authFailures:', d.get('authFailures'), 'nonceReplays:', d.get('nonceReplays'), 'permDenied:', d.get('permissionDenied'), 'total:', d.get('totalRequests'))"
echo "=== GET /admin/audit alice ==="
curl -sf "$BASE/admin/audit?workspaceId=ws&since=0" -H "Authorization: Bearer $ALICE" -H "x-nonce: n6" | python3 -c "import sys,json; d=json.load(sys.stdin); print('count:', d.get('count'), 'head:', d.get('headHash','')[:16])"
echo "=== GET /admin/metrics carol expect 403 ==="
R=$(curl -s -o /dev/null -w "%{http_code}" "$BASE/admin/metrics?workspaceId=ws" -H "Authorization: Bearer $CAROL" -H "x-nonce: n7")
echo "HTTP $R (expected 403)"
echo "=== GET /admin/state_hash alice ==="
curl -sf "$BASE/admin/state_hash?workspaceId=ws" -H "Authorization: Bearer $ALICE" -H "x-nonce: n8" | python3 -c "import sys,json; d=json.load(sys.stdin); print('stateHash:', d.get('stateHash','')[:16], 'metricsHash:', d.get('metricsHash','')[:16])"
echo ""
echo "=== PASS ==="
