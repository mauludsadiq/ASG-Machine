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
in-memory server, live HTTP server, and durable persistence across restarts.

## Run

    # Durable server (persists state across restarts)
    mkdir -p data/server
    fardrun run --program server_durable.fard --out out/server

    # Stateless server (no persistence)
    fardrun run --program server.fard --out out/server

    # Smoke test (server must be running on port 7777)
    ./smoke.sh

    # Restart persistence test
    ./restart_test.sh

    # Fast test suite
    fardrun run --program tests/run_all.fard --out out/tests_all

    # E2E smoke test
    fardrun run --program tests/test_e2e_smoke.fard --out out/t_smoke

## Verified Behavior

    ./smoke.sh output:
    GET /health    -> ok: True version: 0.7.0 workspaces: 1
    POST /tx       -> status: ACCEPTED ingressSeq: 1
    POST /tx dup   -> status: DUPLICATE
    GET /frames    -> count: 2 headFrameId: 2
    GET /snapshot  -> version: 2 frameId: 2
    GET /frames?since=head -> count since head: 0

    ./restart_test.sh output:
    First boot:    tx1 ACCEPTED, snapshot v:1 text:main_v1
    After restart: snapshot v:1 text:main_v1, frames:1 head:1

## Architecture

    POST /tx
    -> server_durable.fard (net.serve + mutex)
    -> server_process.fard (route + parse)
    -> server.fard (workspace manager)
    -> request_router.fard (HTTP handlers)
    -> runtime.fard (gateway + log + consumer + bus + journal)
    -> workspace_state.fard (fs snapshot + journal persistence)
    -> reducer / asg / projection / frame

## Modules

    Phase A — Correctness Core
    src/core.fard                    shared result/assert/hash helpers
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
    smoke.sh                         curl smoke test

    Phase G — Durable Server
    src/workspace_state.fard         fs snapshot + journal persistence
    server_durable.fard              net.serve with disk persistence
    restart_test.sh                  restart persistence smoke test

    main.fard                        batch demo
    tests/*.fard                     executable test programs

## Scale

    5,153 lines of FARD across 75 files
    625 invariant assertions
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

## Proof of Execution

Fast suite:

    fard_run_digest=sha256:975140f4ac0c929164c702d9595ae6f448bd71bbe6eec93fa185b7f55cc953c3
    { overallOk: true, phase: C, passed: 12, failed: 0 }

E2E smoke:

    fard_run_digest=sha256:2fe090cd69a98f44266143fe903f7b30af9697172a76004b3e744ed4c69e062d
    { ok: true, passed: 26, failed: 0 }

Restart persistence:

    ./restart_test.sh
    After restart: snapshot v:1 text:main_v1 frames:1 head:1
    === DONE ===
