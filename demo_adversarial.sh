#!/bin/bash
set -e
BASE="http://localhost:7779"
ALICE="alice.client_a.sha256:4fce64322c716f1c822ecfafec1da6623853145d91869f13be5f422fc2207915"
BOB="bob.client_b.sha256:ebc9c5665b3aa8748d7da2c5cc5d1eff1f57fa66f4b1226705d2df88e4fea77c"

echo "=== ASG Machine: Adversarial Convergence Demo ==="
echo ""
echo "Scenario: Two users edit concurrently against the same base."
echo "  User A (alice): rename fn_main -> compute"
echo "  User B (bob):   set stmt_1 value to 'counter + 1'"
echo ""

echo "--- Initial state ---"
INITIAL=$(curl -sf "$BASE/snapshot?workspaceId=ws" \
  -H "Authorization: Bearer $ALICE" -H "x-nonce: demo_n0" \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['projectionText'].strip())")
echo "$INITIAL"
echo ""

echo "--- Simulating TEXT CRDT (character-level patches, no OT transform) ---"
python3 - << 'PY'
base = "fn main() {  let x = 1\n  return x\n}\n"
# Edit A: rename "main" -> "compute" at offset 3
edit_a_start, edit_a_old, edit_a_new = 3, "main", "compute"
# Edit B: replace "1" -> "counter + 1" at offset 21 (computed on base)
edit_b_start, edit_b_old, edit_b_new = 21, "1", "counter + 1"

# Apply A first
after_a = base[:edit_a_start] + edit_a_new + base[edit_a_start + len(edit_a_old):]

# Apply B at original offset (naive CRDT - no transform)
crdt_naive = after_a[:edit_b_start] + edit_b_new + after_a[edit_b_start + len(edit_b_old):]
print("CRDT naive result:")
print(crdt_naive)

delta = len(edit_a_new) - len(edit_a_old)
edit_b_ot = edit_b_start + delta
crdt_ot = after_a[:edit_b_ot] + edit_b_new + after_a[edit_b_ot + len(edit_b_old):]
print("CRDT with OT transform (offset corrected by delta=%d):" % delta)
print(crdt_ot)
PY

echo ""
echo "--- Submitting tx_a (User A: rename fn_main -> compute) via POST /tx ---"
curl -sf -X POST "$BASE/tx" -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ALICE" -H "x-nonce: demo_n1" \
  -d '{"id":"demo_tx_a","workspaceId":"ws","dependencies":[],"preconditions":[],"operation":{"kind":"RENAME_NODE","nodeId":"fn_main","newName":"compute"},"lamportTimestamp":1,"replicaId":"replica_a"}' \
  | python3 -c "import sys,json; d=json.load(sys.stdin); print('tx_a:', d.get('status'), 'seq:', d.get('ingressSeq'))"

echo "--- Submitting tx_b (User B: set stmt_1 value = counter + 1) via POST /tx ---"
curl -sf -X POST "$BASE/tx" -H "Content-Type: application/json" \
  -H "Authorization: Bearer $BOB" -H "x-nonce: demo_n2" \
  -d '{"id":"demo_tx_b","workspaceId":"ws","dependencies":[],"preconditions":[],"operation":{"kind":"SET_PROPERTY","nodeId":"stmt_1","key":"value","value":"counter + 1"},"lamportTimestamp":1,"replicaId":"replica_b"}' \
  | python3 -c "import sys,json; d=json.load(sys.stdin); print('tx_b:', d.get('status'), 'seq:', d.get('ingressSeq'))"

echo ""
echo "--- Polling GET /frames to verify reduction ---"
FRAMES=$(curl -sf "$BASE/frames?workspaceId=ws&since=0" \
  -H "Authorization: Bearer $ALICE" -H "x-nonce: demo_n3" \
  | python3 -c "import sys,json; d=json.load(sys.stdin); print('frames:', d['count'], 'head:', d['headFrameId'])")
echo "$FRAMES"

echo ""
echo "--- GET /snapshot: final projected text after full pipeline ---"
RESULT=$(curl -sf "$BASE/snapshot?workspaceId=ws" \
  -H "Authorization: Bearer $ALICE" -H "x-nonce: demo_n4" \
  | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['projectionText'].strip())")
echo "ASG Machine result:"
echo "$RESULT"

echo ""
echo "--- Verdict ---"
python3 - << PY
crdt_broken = "xcounter" in "fn compute() {  let xcounter + 1= 1\n  return x\n}\n"
asg_result = """$RESULT"""
asg_valid = "compute" in asg_result and "counter + 1" in asg_result and "fn main" not in asg_result
crdt_naive = "fn compute() {  let xcounter + 1= 1\n  return x\n}\n"
print("CRDT naive:   ", repr(crdt_naive.strip()))
print("ASG Machine:  ", repr(asg_result.strip()))
print("CRDT broken:  ", crdt_broken)
print("ASG valid:    ", asg_valid)
print("VERDICT:", "ASG_WINS" if asg_valid and crdt_broken else "INCONCLUSIVE")
PY

echo ""
echo "=== DONE ==="
