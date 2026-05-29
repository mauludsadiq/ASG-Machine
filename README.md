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
store, reducer, projection, frame broadcast, client replay, HTTP/WS adapter
contracts, in-memory server, and end-to-end smoke tests. All execution is
deterministic and content-addressed.

## Architecture

    CLI submit
    -> server.handle_request (multi-workspace manager)
    -> request_router (HTTP dispatch)
    -> runtime (gateway + log + consumer + bus + journal)
    -> frame_bus (WebSocket delivery)
    -> editor_bridge / editor_adapter (client replay)
    -> snapshot / workspace_format (persistence)

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
    src/runtime.fard                 stateful pipeline bundle (gateway+log+consumer+bus+journal)
    src/request_router.fard          HTTP dispatch over api_contract
    src/server.fard                  in-memory multi-workspace server

    main.fard                        executable demo
    tests/*.fard                     executable test programs

## Run

    # Demo
    fardrun run --program main.fard --out out/asg_machine_demo

    # Fast test suite (~seconds)
    fardrun run --program tests/run_all.fard --out out/tests_all

    # End-to-end smoke test
    fardrun run --program tests/test_e2e_smoke.fard --out out/t_smoke

    # Stress convergence suite (~80s)
    fardrun run --program tests/test_stress_convergence.fard --out out/t_stress

## Scale

    4,815 lines of FARD across 70 files
    607 invariant assertions
    0 failures

## Test Suite

Phase A — Correctness Core:

| File | Assertions |
|---|---|
| test_asg.fard | 19 |
| test_asg_move.fard | 13 |
| test_asg_multi_store.fard | 7 |
| test_rope.fard | 17 |
| test_projection.fard | 9 |
| test_projection_stability.fard | 11 |
| test_projection_node_count.fard | 12 |
| test_validate_projection.fard | 14 |
| test_incremental_projection.fard | 17 |
| test_idempotency.fard | 5 |
| test_pending_resolution.fard | 4 |
| test_convergence.fard | 10 |
| test_replay.fard | 10 |

Phase B — Client Runtime:

| File | Assertions |
|---|---|
| test_editor_bridge.fard | 17 |
| test_journal.fard | 20 |
| test_recovery.fard | 15 |
| test_multi_client_convergence.fard | 16 |
| test_vfs.fard | 13 |
| test_lsp_bridge.fard | 12 |

Phase C — Distributed Runtime:

| File | Assertions |
|---|---|
| test_gateway.fard | 19 |
| test_ordered_log.fard | 18 |
| test_reducer_consumer.fard | 9 |
| test_frame_bus.fard | 15 |
| test_distributed_sim.fard | 11 |
| test_partition.fard | 8 |
| test_snapshot.fard | 12 |

Phase D — Production Adapter Boundary:

| File | Assertions |
|---|---|
| test_api_contract.fard | 30 |
| test_ws_stream.fard | 32 |
| test_cli_driver.fard | 30 |
| test_workspace_format.fard | 21 |
| test_editor_adapter.fard | 27 |
| test_e2e_demo.fard | 18 |

Phase E — Executable Network Runtime:

| File | Assertions |
|---|---|
| test_runtime.fard | 22 |
| test_request_router.fard | 26 |
| test_server.fard | 22 |
| test_e2e_smoke.fard | 26 |

Infrastructure:

| File | Assertions |
|---|---|
| run_all.fard | 12 |
| test_reducer_failure.fard | - |
| test_reducer_edges.fard | - |
| test_stress_convergence.fard | 8 |

## End-to-End Smoke Test

    fardrun run --program tests/test_e2e_smoke.fard --out out/t_smoke
    fard_run_digest=sha256:2fe090cd69a98f44266143fe903f7b30af9697172a76004b3e744ed4c69e062d

Verified path:

    CLI parse
    -> server POST /tx (201 ACCEPTED)
    -> GET /frames (journal entries)
    -> recovery.replay_since (client catch-up)
    -> editor_adapter.apply_diff_to_doc (SYNCED)
    -> GET /snapshot (verified)
    -> WebSocket pending_frame_messages
    -> editor text == client text == server text

## Proof of Execution

    fardrun run --program tests/run_all.fard --out out/tests_all
    fard_run_digest=sha256:975140f4ac0c929164c702d9595ae6f448bd71bbe6eec93fa185b7f55cc953c3
    { overallOk: true, phase: C, passed: 12, failed: 0 }

Stress suite:

    fardrun run --program tests/test_stress_convergence.fard --out out/t_stress
    100-tx convergence (batch 5): PASS
    50-tx convergence (batch 1): PASS
