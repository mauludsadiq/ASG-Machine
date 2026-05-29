#!/bin/bash
lsof -ti:7777 | xargs kill -9 2>/dev/null
mkdir -p data/server
fardrun run --program server_durable.fard --out out/sd1 &
SERVER_PID=$!
sleep 3

echo "=== First boot ==="
curl -sf http://localhost:7777/health | python3 -c "import sys,json; d=json.load(sys.stdin); print('health:', d['version'])"
curl -sf -X POST http://localhost:7777/tx -H "Content-Type: application/json" -d '{"id":"tx1","workspaceId":"ws","dependencies":[],"preconditions":[],"operation":{"kind":"RENAME_NODE","nodeId":"fn_main","newName":"main_v1"},"lamportTimestamp":1,"replicaId":"cli"}' | python3 -c "import sys,json; d=json.load(sys.stdin); print('tx1:', d['status'])"
curl -sf "http://localhost:7777/snapshot?workspaceId=ws" | python3 -c "import sys,json; d=json.load(sys.stdin); print('v1 snapshot:', d['version'], d['projectionText'][:30])"
echo "saved files:"; ls data/server/

echo "=== Killing ==="
kill $SERVER_PID 2>/dev/null
sleep 2

echo "=== Restarting ==="
fardrun run --program server_durable.fard --out out/sd2 &
SERVER_PID2=$!
sleep 3

echo "=== After restart ==="
curl -sf "http://localhost:7777/snapshot?workspaceId=ws" | python3 -c "import sys,json; d=json.load(sys.stdin); print('v2 snapshot:', d['version'], d['projectionText'][:30])"
curl -sf "http://localhost:7777/frames?workspaceId=ws&since=0" | python3 -c "import sys,json; d=json.load(sys.stdin); print('frames:', d['count'], 'head:', d['headFrameId'])"

kill $SERVER_PID2 2>/dev/null
echo "=== DONE ==="
