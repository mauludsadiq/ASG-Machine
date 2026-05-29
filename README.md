# ASG Machine

Text CRDTs converge, but they don't understand code.

## The Problem

Two users edit the same function concurrently:

    User A: rename fn_main -> compute
    User B: update statement value to counter + 1

Both edits are valid. Applied to the same base. What happens?

    TEXT CRDT RESULT:        ASG MACHINE RESULT:
    fn compute() {           fn compute() {
      let x = 1                let x = counter + 1
      return xcounter + 1      return x
    }                        }

The CRDT produces `return xcounter + 1`. The rename shifted character
offsets by +3. The concurrent edit landed in the wrong position.
Syntactically valid. Semantically broken. Silently.

The ASG Machine produces the correct program. Both ops target stable
node IDs — not character positions. They are orthogonal. Both apply
cleanly. Every time. Provably.

    # Start the server, then run:
    ./demo_adversarial.sh
    VERDICT: ASG_WINS

## Quickstart

    git clone https://github.com/mauludsadiq/ASG-Machine.git
    cd ASG-Machine
    docker compose up

Server starts on port 7779. Then from the repo root:

    ./demo_adversarial.sh   # VERDICT: ASG_WINS
    ./demo_extended.sh      # three-way concurrency, failure mode, recovery

No fardrun installation required.

## How It Works

Every operation is a semantic transaction against a versioned AST:

    op_rename("fn_main", "compute")      -- targets node ID, not offset
    op_set("stmt_1", "value", "counter") -- targets field, not position

The reducer applies transactions deterministically, emits
cryptographically hashed frames, and broadcasts minimal projection
diffs. Clients replay frames and converge to identical text —
provably, not probabilistically.

    Client A: rename(fn_main -> compute) ----+
                                             +--> [ASG Machine] --> identical ASTs
    Client B: set(stmt_1, counter + 1)  ----+

## Run the Demo

    mkdir -p data/server_audit
    fardrun run --program server_audited.fard --out out/server_audited
    ./demo_adversarial.sh   # runs end-to-end through live HTTP server

## Run the Server

    # Auditable authenticated server (port 7779)
    mkdir -p data/server_audit
    fardrun run --program server_audited.fard --out out/server_audited
    ./smoke_audit.sh

    # Restart persistence test
    ./restart_test.sh

    # Full test suite
    fardrun run --program tests/run_all.fard --out out/tests_all

## What the Server Proves

    POST /tx alice (owner)   -> ACCEPTED seq:1
    POST /tx bob (editor)    -> ACCEPTED seq:2
    POST /tx carol (viewer)  -> 403
    POST /tx unauth          -> 401
    Replayed nonce           -> 409
    GET /admin/metrics       -> txAccepted:2 authFailures:1 nonceReplays:1
    GET /admin/audit         -> hash-chained, tamper-evident
    Restart                  -> version:1 text:main_v1 frames:1 head:1

## Architecture

    POST /tx
    -> server_audited.fard (net.serve port 7779, mutex {srv,auth,audit,metrics})
    -> server_audit.fard (token+ACL, audit append, metrics)
    -> server_process.fard (route + parse)
    -> server.fard (workspace manager)
    -> request_router.fard (HTTP handlers)
    -> runtime.fard (gateway + log + consumer + bus + journal)
    -> workspace_state.fard (fs snapshot + journal)

## Modules

    Phase A — Correctness Core
    src/core.fard                    result/assert/hash helpers
    src/asg.fard                     ASG store and structural mutation
    src/rope.fard                    segment rope and text range replacement
    src/projection.fard              ASG -> text projection
    src/incremental_projection.fard  minimal subtree diff engine
    src/transactions.fard            transaction/precondition evaluation
    src/reducer.fard                 deterministic reducer
    src/frame.fard                   batch frame machine and replay
    src/harness.fard                 convergence harness

    Phase B — Client Runtime
    src/editor_bridge.fard           deterministic client-side frame replay
    src/journal.fard                 replay log with hash chaining
    src/recovery.fard                client catch-up from arbitrary version
    src/vfs.fard                     versioned document snapshots
    src/lsp_bridge.fard              LSP mirror with deterministic diagnostics

    Phase C — Distributed Runtime
    src/gateway.fard                 tx ingress: validate, dedup, sequence
    src/ordered_log.fard             total-order tx log
    src/reducer_consumer.fard        log -> frames -> journal
    src/frame_bus.fard               frame broadcast and subscriber delivery
    src/distributed_sim.fard         end-to-end pipeline simulator
    src/partition.fard               workspace isolation and routing
    src/snapshot.fard                durable ASG + projection snapshots

    Phase D — Production Adapter Boundary
    src/api_contract.fard            HTTP API payload validation
    src/ws_stream.fard               WebSocket frame stream protocol
    src/cli_driver.fard              CLI command parsing and dispatch
    src/workspace_format.fard        persisted workspace directory format
    src/editor_adapter.fard          browser/editor adapter spec

    Phase E — Executable Network Runtime
    src/runtime.fard                 stateful pipeline bundle
    src/request_router.fard          HTTP dispatch over api_contract
    src/server.fard                  in-memory multi-workspace manager

    Phase F — Live Server
    src/server_process.fard          HTTP route handler and query parser
    server.fard                      net.serve entry point (stateless, port 7777)

    Phase G — Durable Server
    src/workspace_state.fard         fs snapshot + journal persistence
    server_durable.fard              persistent server (port 7777)
    restart_test.sh                  restart persistence smoke test

    Phase H — Auth
    src/identity.fard                user/client/token, nonce store
    src/acl.fard                     workspace roles: owner/editor/viewer
    src/signed_request.fard          Bearer token, verify, replay rejection
    src/server_auth.fard             auth-wrapped request handler
    server_auth.fard                 authenticated server (port 7778)

    Phase I — Audit
    src/audit_log.fard               hash-chained audit entries
    src/metrics.fard                 deterministic operator counters
    src/server_audit.fard            audited handler + admin endpoints
    server_audited.fard              auditable server (port 7779)

    Phase J — Adversarial Demo
    demo_adversarial.sh              CRDT vs ASG Machine (end-to-end via live server)
    demo_extended.sh                 Three-way concurrency, failure mode, crash recovery

## Scale

    6,044 lines of FARD across 87 files
    695 invariant assertions
    0 failures

| Phase | Modules | Purpose |
|---|---|---|
| A Correctness | 9 | ASG, reducer, projection, rope, transactions |
| B Client Runtime | 5 | editor_bridge, journal, recovery, vfs, lsp |
| C Distributed | 7 | gateway, log, consumer, bus, sim, partition, snapshot |
| D Adapter Boundary | 5 | api_contract, ws_stream, cli, workspace_format, editor_adapter |
| E Network Runtime | 3 | runtime, request_router, server |
| F Live Server | 2 | server_process, server.fard |
| G Durable Server | 2 | workspace_state, server_durable.fard |
| H Auth | 4 | identity, acl, signed_request, server_auth |
| I Audit | 3 | audit_log, metrics, server_audit |
| J Demo | 1 | demo_adversarial.fard |

## Proof of Execution

Adversarial demo (end-to-end through live server):

    mkdir -p data/server_audit
    fardrun run --program server_audited.fard --out out/server_audited
    ./demo_adversarial.sh

    CRDT naive:   fn compute() {  let xcounter + 1= 1  (broken)
    ASG Machine:  fn compute() {  let x = counter + 1  (correct)
    VERDICT: ASG_WINS

Extended demo:

    ./demo_extended.sh

    Demo 1 — Three-way concurrency:
      Alice rename APPLIED, Bob set APPLIED, reducer verdicts in frames
      Result: fn compute() {  let x = counter + 1 }

    Demo 2 — Failure mode:
      Alice delete APPLIED, Bob rename FAILED: PRECONDITION_EXISTS_FAILED
      Gateway accepts both (sequencing only); reducer enforces preconditions

    Demo 3 — Crash recovery:
      Client at frame 3, server at head 5
      Poll /frames?since=3 -> 2 catch-up frames, Converged: True

Fast suite:

    fard_run_digest=sha256:975140f4ac0c929164c702d9595ae6f448bd71bbe6eec93fa185b7f55cc953c3
    { overallOk: true, phase: C, passed: 12, failed: 0 }

Audit smoke:

    ./smoke_audit.sh -> === PASS ===

Restart persistence:

    ./restart_test.sh -> After restart: v:1 text:main_v1 frames:1 head:1
