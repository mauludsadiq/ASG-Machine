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
in-memory server, and a live HTTP server using std/net and std/mutex.

## Run the Server

    fardrun run --program server.fard --out out/server_run

Server listens on port 7777. Run the smoke test:

    ./smoke.sh

Expected output:

    GET /health    -> ok: True version: 0.6.0 workspaces: 1
    POST /tx       -> status: ACCEPTED ingressSeq: 1
    POST /tx dup   -> status: DUPLICATE
    GET /frames    -> count: 2 headFrameId: 2
    GET /snapshot  -> version: 2 frameId: 2
    GET /frames?since=head -> count since head: 0

## Architecture

    CLI submit
    -> server.fard (net.serve + mutex state)
    -> server_process.fard (route dispatch)
    -> server.fard (multi-workspace manager)
    -> request_router.fard (HTTP handler)
    -> runtime.fard (gateway + log + consumer + bus + journal)
    -> frame_bus / editor_bridge / editor_adapter
    -> snapshot / workspace_format

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
    server.fard                      net.serve entry point (port 7777, mutex state)
    smoke.sh                         curl smoke test

    main.fard                        batch demo
    tests/*.fard                     executable test programs

## Test Suite

    # Fast suite
    fardrun run --program tests/run_all.fard --out out/tests_all

    # E2E smoke
    fardrun run --program tests/test_e2e_smoke.fard --out out/t_smoke

    # Stress (~80s)
    fardrun run --program tests/test_stress_convergence.fard --out out/t_stress

## Scale

    4,903 lines of FARD across 72 files
    607 invariant assertions
    0 failures

| Phase | Files | Key modules |
|---|---|---|
| A Correctness | 9 | asg, reducer, projection, rope, transactions |
| B Client Runtime | 5 | editor_bridge, journal, recovery, vfs, lsp_bridge |
| C Distributed | 7 | gateway, ordered_log, reducer_consumer, frame_bus, snapshot |
| D Adapter Boundary | 5 | api_contract, ws_stream, cli_driver, editor_adapter |
| E Network Runtime | 3 | runtime, request_router, server |
| F Live Server | 3 | server_process, server.fard, smoke.sh |

## Proof of Execution

Live server smoke test:

    ./smoke.sh  (server running on port 7777)
    === PASS ===

Fast suite:

    fard_run_digest=sha256:975140f4ac0c929164c702d9595ae6f448bd71bbe6eec93fa185b7f55cc953c3
    { overallOk: true, phase: C, passed: 12, failed: 0 }

E2E smoke:

    fard_run_digest=sha256:2fe090cd69a98f44266143fe903f7b30af9697172a76004b3e744ed4c69e062d
    { ok: true, passed: 26, failed: 0 }
