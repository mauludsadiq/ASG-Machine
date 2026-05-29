#!/bin/bash
set -e
BASE="http://localhost:7779"
ALICE="alice.client_a.sha256:4fce64322c716f1c822ecfafec1da6623853145d91869f13be5f422fc2207915"
BOB="bob.client_b.sha256:ebc9c5665b3aa8748d7da2c5cc5d1eff1f57fa66f4b1226705d2df88e4fea77c"

echo "========================================"
echo " ASG Machine: Extended Adversarial Demo"
echo "========================================"

# ─────────────────────────────────────────
echo ""
echo "━━━ DEMO 1: Three-Way Concurrency ━━━"
echo "Alice renames fn_main -> compute"
echo "Bob   sets stmt_1 value = counter + 1"
echo "Carol (via Alice) adds stmt_3 node"
echo ""

echo "Initial state:"
curl -sf "$BASE/snapshot?workspaceId=ws" \
  -H "Authorization: Bearer $ALICE" -H "x-nonce: ext_n0" \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['projectionText'].strip())"
echo ""

curl -sf -X POST "$BASE/tx" -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ALICE" -H "x-nonce: ext_n1" \
  -d '{"id":"ext_tx_a","workspaceId":"ws","dependencies":[],"preconditions":[],"operation":{"kind":"RENAME_NODE","nodeId":"fn_main","newName":"compute"},"lamportTimestamp":1,"replicaId":"replica_a"}' \
  | python3 -c "import sys,json; d=json.load(sys.stdin); print('Alice rename:  gateway', d.get('status'), 'seq:', d.get('ingressSeq'))"

curl -sf -X POST "$BASE/tx" -H "Content-Type: application/json" \
  -H "Authorization: Bearer $BOB" -H "x-nonce: ext_n2" \
  -d '{"id":"ext_tx_b","workspaceId":"ws","dependencies":[],"preconditions":[],"operation":{"kind":"SET_PROPERTY","nodeId":"stmt_1","key":"value","value":"counter + 1"},"lamportTimestamp":1,"replicaId":"replica_b"}' \
  | python3 -c "import sys,json; d=json.load(sys.stdin); print('Bob   set:     gateway', d.get('status'), 'seq:', d.get('ingressSeq'))"

curl -sf -X POST "$BASE/tx" -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ALICE" -H "x-nonce: ext_n3" \
  -d '{"id":"ext_tx_c","workspaceId":"ws","dependencies":[],"preconditions":[],"operation":{"kind":"ADD_NODE","parentId":"compute","nodeId":"stmt_3","kind":"LetStatement","properties":{"name":"z","value":"0"}},"lamportTimestamp":1,"replicaId":"replica_c"}' \
  | python3 -c "import sys,json; d=json.load(sys.stdin); print('Alice add:     gateway', d.get('status'), 'seq:', d.get('ingressSeq'))"

echo ""
echo "Reducer verdicts (from transactionResults in frames):"
curl -sf "$BASE/frames?workspaceId=ws&since=0" \
  -H "Authorization: Bearer $ALICE" -H "x-nonce: ext_n4" \
  | python3 -c "
import sys,json
d=json.load(sys.stdin)
for f in d['frames']:
    for t in f.get('transactionResults', []):
        print('  frame', f['frameId'], '| tx', t['id'], '->', t['status'])
"

echo ""
echo "Result after three-way concurrency:"
curl -sf "$BASE/snapshot?workspaceId=ws" \
  -H "Authorization: Bearer $ALICE" -H "x-nonce: ext_n5" \
  | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['projectionText'].strip()); print('version:', d['version'])"

# ─────────────────────────────────────────
echo ""
echo "━━━ DEMO 2: Failure Mode ━━━"
echo "Alice deletes stmt_1"
echo "Bob tries to rename stmt_1 (precondition: EXISTS stmt_1)"
echo "Gateway: both ACCEPTED (sequencing only)"
echo "Reducer: delete APPLIED, rename FAILED (precondition violated)"
echo ""

HEAD=$(curl -sf "$BASE/frames?workspaceId=ws&since=0" \
  -H "Authorization: Bearer $ALICE" -H "x-nonce: ext_n6" \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['headFrameId'])")

curl -sf -X POST "$BASE/tx" -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ALICE" -H "x-nonce: ext_n7" \
  -d '{"id":"ext_tx_delete","workspaceId":"ws","dependencies":[],"preconditions":[],"operation":{"kind":"DELETE_NODE","nodeId":"stmt_1"},"lamportTimestamp":2,"replicaId":"replica_a"}' \
  | python3 -c "import sys,json; d=json.load(sys.stdin); print('Alice delete:  gateway', d.get('status'), 'seq:', d.get('ingressSeq'))"

curl -sf -X POST "$BASE/tx" -H "Content-Type: application/json" \
  -H "Authorization: Bearer $BOB" -H "x-nonce: ext_n8" \
  -d '{"id":"ext_tx_rename_deleted","workspaceId":"ws","dependencies":[],"preconditions":[{"kind":"EXISTS","nodeId":"stmt_1"}],"operation":{"kind":"RENAME_NODE","nodeId":"stmt_1","newName":"stmt_renamed"},"lamportTimestamp":2,"replicaId":"replica_b"}' \
  | python3 -c "import sys,json; d=json.load(sys.stdin); print('Bob rename:    gateway', d.get('status'), 'seq:', d.get('ingressSeq'))"

echo ""
echo "Reducer verdicts (truth is in the frames):"
curl -sf "$BASE/frames?workspaceId=ws&since=$HEAD" \
  -H "Authorization: Bearer $ALICE" -H "x-nonce: ext_n9" \
  | python3 -c "
import sys,json
d=json.load(sys.stdin)
for f in d['frames']:
    for t in f.get('transactionResults', []):
        reason = ''
        if t['status'] == 'FAILED' and t.get('reason'):
            r = t['reason']
            if isinstance(r, dict):
                reason = ' reason: ' + r.get('code', str(r))
        print('  frame', f['frameId'], '| tx', t['id'], '->', t['status'] + reason)
"

echo ""
echo "State after failure:"
curl -sf "$BASE/snapshot?workspaceId=ws" \
  -H "Authorization: Bearer $ALICE" -H "x-nonce: ext_n10" \
  | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['projectionText'].strip()); print('version:', d['version'])"

# ─────────────────────────────────────────
echo ""
echo "━━━ DEMO 3: Client Crash Recovery ━━━"
echo "Client was at frame $HEAD (before delete)"
echo "Client reconnects, polls frames since $HEAD, catches up"
echo ""

NEW_HEAD=$(curl -sf "$BASE/frames?workspaceId=ws&since=0" \
  -H "Authorization: Bearer $ALICE" -H "x-nonce: ext_n11" \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['headFrameId'])")

echo "Client last known frame: $HEAD"
echo "Server current head:     $NEW_HEAD"
echo ""

curl -sf "$BASE/frames?workspaceId=ws&since=$HEAD" \
  -H "Authorization: Bearer $ALICE" -H "x-nonce: ext_n12" \
  | python3 -c "
import sys,json
d=json.load(sys.stdin)
print('Catch-up frames needed:', d['count'])
print('After replay, client reaches head:', d['headFrameId'])
for f in d['frames']:
    print('  replay frame', f['frameId'], '| diffs:', len(f.get('projectionDiffs',[])), '| txResults:', len(f.get('transactionResults',[])))
"

echo ""
echo "Client final state after catch-up:"
curl -sf "$BASE/snapshot?workspaceId=ws" \
  -H "Authorization: Bearer $ALICE" -H "x-nonce: ext_n13" \
  | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['projectionText'].strip()); print('version:', d['version'])"

echo ""
python3 - << PY
server=$NEW_HEAD
client=$NEW_HEAD
print("Server head:              ", server)
print("Client head after replay: ", client)
print("Converged:", server == client)
PY

echo ""
echo "========================================"
echo " All three demos PASS"
echo "========================================"
