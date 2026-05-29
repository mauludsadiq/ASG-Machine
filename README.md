# ASG Machine

Text CRDTs converge, but they don't understand code. Rename a variable while your
teammate deletes the line it's on — you get garbage. ASG Machine converges
structurally, with cryptographic proofs.

    Client A: rename(x -> counter) ----+
                                       +--> [ASG Machine] --> identical ASTs
    Client B: delete_stmt_1() ---------+

Every operation is a semantic transaction against a versioned AST. The reducer
applies them deterministically, emits cryptographically hashed frames, and
broadcasts minimal projection diffs to clients. Clients replay frames and
converge to identical text — provably, not probabilistically.

## What is FARD

FARD is a general-purpose deterministic functional language with a tree-walking
interpreter (fardrun). This project implements the full ASG machine stack in FARD:
store, reducer, projection, frame broadcast, client replay, HTTP/WS contracts,
in-memory server, live HTTP server, durable persistence, authenticated access
control, and hash-chained audit logging with operator metrics.

## Run

    # Auditable authenticated server (port 7779) — recommended
    mkdir -p data/server_audit
    fardrun run --program server_audited.fard --out out/server_audited

    # Authenticated durable server (port 7778)
    mkdir -p data/server_auth
    fardrun run --program server_auth.fard --out out/server_auth

    # Durable server without auth (port 7777)
    mkdir -p data/server
    fardrun run --program server_durable.fard --out out/server

    # Smoke tests
    ./smoke_audit.sh      # audit + admin endpoints
    ./smoke_auth.sh       # auth/ACL
    ./smoke.sh            # basic endpoints
    ./restart_test.sh     # persistence across restarts

    # Test suite
    fardrun run --program tests/run_all.fard --out out/tests_all

## Verified Behavior

    ./smoke_audit.sh:
    GET /health              -> ok version:0.9.0
    POST /tx alice (owner)   -> ACCEPTED seq:1
    POST /tx bob (editor)    -> ACCEPTED seq:2
    POST /tx carol (viewer)  -> 403
    POST /tx unauth          -> 401
    Replayed nonce           -> 409
    GET /admin/metrics       -> txAccepted:2 authFailures:1 nonceReplays:1 permDenied:1
    GET /admin/audit         -> count:5 headHash verified
    GET /admin/metrics carol -> 403
    GET /admin/state_hash    -> stateHash+metricsHash present

    ./restart_test.sh:
    After restart: snapshot v:1 text:main_v1 frames:1 head:1

## Architecture

    POST /tx
    -> server_audited.fard (net.serve port 7779, mutex {srv,auth,audit,metrics})
    -> server_audit.fard (token+ACL check, audit append, metrics inc)
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
    src/api_contract.fard            HTTP API payload validation and response shaping
    src/ws_stream.fard               WebSocket/long-poll frame stream protocol
    src/cli_driver.fard              CLI command parsing and dispatch
    src/workspace_format.fard        persisted workspace directory format
    src/editor_adapter.fard          browser/editor adapter spec

    Phase E — Executable Network Runtime
    src/runtime.fard                 stateful pipeline bundle
    src/request_router.fard          HTTP dispatch over api_contract
    src/server.fard                  in-memory multi-workspace manager

    Phase F — Live Server
    src/server_process.fard          HTTP route handler and query parser
    server.fard                      net.serve entry point (stateless)
    smoke.sh                         basic smoke test

    Phase G — Durable Server
    src/workspace_state.fard         fs snapshot + journal persistence
    server_durable.fard              net.serve with disk persistence
    restart_test.sh                  restart persistence smoke test

    Phase H — Auth
    src/identity.fard                user/client/token, nonce store
    src/acl.fard                     workspace roles: owner/editor/viewer
    src/signed_request.fard          Bearer token extraction, verify, replay rejection
    src/server_auth.fard             auth-wrapped request handler
    server_auth.fard                 authenticated durable server (port 7778)
    smoke_auth.sh                    auth smoke test

    Phase I — Audit
    src/audit_log.fard               hash-chained audit entries
    src/metrics.fard                 deterministic operator counters
    src/server_audit.fard            audited handler + admin endpoints
    server_audited.fard              auditable authenticated server (port 7779)
    smoke_audit.sh                   audit + admin smoke test

    main.fard                        batch demo
    tests/*.fard                     executable test programs

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
| F Live Server | 3 | server_process, server.fard, smoke.sh |
| G Durable Server | 2 | workspace_state, server_durable.fard |
| H Auth | 4 | identity, acl, signed_request, server_auth |
| I Audit | 3 | audit_log, metrics, server_audit |

## Proof of Execution

Fast suite:

    fard_run_digest=sha256:975140f4ac0c929164c702d9595ae6f448bd71bbe6eec93fa185b7f55cc953c3
    { overallOk: true, phase: C, passed: 12, failed: 0 }

Audit smoke:

    ./smoke_audit.sh -> === PASS ===
    txAccepted:2 authFailures:1 nonceReplays:1 permDenied:1 total:12
    audit count:5, stateHash+metricsHash present

Restart persistence:

    ./restart_test.sh -> After restart: v:1 text:main_v1 frames:1 head:1
