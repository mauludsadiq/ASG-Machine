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
interpreter (fardrun). This project uses FARD to implement the full ASG machine
stack: store, reducer, projection, frame broadcast, client replay, and external
adapter contracts. All execution is deterministic and content-addressed.

## Architecture

    client transaction ingress
    -> gateway (dedup, validate, sequence)
    -> ordered log (total order)
    -> reducer consumer (deterministic frames)
    -> frame bus (broadcast)
    -> WebSocket session (delivery tracking)
    -> editor adapter (diff apply, cursor, sync state)
    -> journal (persistence) / recovery (catch-up)
    -> VFS / LSP mirrors / snapshot / workspace directory

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

    main.fard                        executable demo
    tests/*.fard                     executable test programs

## Run

    # Demo
    fardrun run --program main.fard --out out/asg_machine_demo

    # Fast test suite (~seconds)
    fardrun run --program tests/run_all.fard --out out/tests_all

    # Stress convergence suite (~80s)
    fardrun run --program tests/test_stress_convergence.fard --out out/t_stress

    # End-to-end demo
    fardrun run --program tests/test_e2e_demo.fard --out out/t_e2e

## Scale

    4,219 lines of FARD across 63 files
    511 invariant assertions
    0 failures

## Test Suite

Phase A:

| File | Assertions | Coverage |
|---|---|---|
| test_asg.fard | 19 | rename, delete, add, move, hash, duplicate rejection |
| test_asg_move.fard | 13 | reorder, cross-parent move, delete, root rejection |
| test_asg_multi_store.fard | 7 | projection and mutation across deep/wide fixtures |
| test_rope.fard | 17 | replace_range, span, boundary errors, segments |
| test_projection.fard | 9 | hash determinism, nodeMap totality, mutation diff |
| test_projection_stability.fard | 11 | rename-to-same, stale invariant detection |
| test_projection_node_count.fard | 12 | nodeMap completeness across all fixtures |
| test_validate_projection.fard | 14 | TEXT_MISMATCH, HASH_MISMATCH, happy path |
| test_incremental_projection.fard | 17 | minimal diffs, offset computation, hash preservation |
| test_idempotency.fard | 5 | same-batch and cross-batch duplicate handling |
| test_pending_resolution.fard | 4 | PENDING -> auto-retry when dependency arrives |
| test_convergence.fard | 10 | 50-tx convergence, all invariants hard-asserted |
| test_replay.fard | 10 | empty/single/multi frame replay, text and hash |

Phase B:

| File | Assertions | Coverage |
|---|---|---|
| test_editor_bridge.fard | 17 | single/multi frame apply, stale/gap rejection, determinism |
| test_journal.fard | 20 | append, chain integrity, corruption detection, replay |
| test_recovery.fard | 15 | catch-up replay, stale rejection, determinism |
| test_multi_client_convergence.fard | 16 | 5 clients, duplicate/partial/reconnect scenarios |
| test_vfs.fard | 13 | snapshots, frame apply, journal sync, hash determinism |
| test_lsp_bridge.fard | 12 | open/sync/close, diagnostics, unopened rejection |

Phase C:

| File | Assertions | Coverage |
|---|---|---|
| test_gateway.fard | 19 | accept, dedup, malformed rejection, ingress order |
| test_ordered_log.fard | 18 | append order, read_from, commit_offset, hash |
| test_reducer_consumer.fard | 9 | same log same frames, partial+resume, chain integrity |
| test_frame_bus.fard | 15 | subscribe, deliver, duplicate ignored, catch-up |
| test_distributed_sim.fard | 11 | 5-client end-to-end, journal==broadcast, recovery |
| test_partition.fard | 8 | workspace isolation, routing, wrong-ws rejection |
| test_snapshot.fard | 12 | hash determinism, corrupt rejection, restore, suffix replay |

Phase D:

| File | Assertions | Coverage |
|---|---|---|
| test_api_contract.fard | 30 | POST /tx, GET /frames/snapshot/health, route() |
| test_ws_stream.fard | 32 | message shapes, session, subscribe, deliver, pending |
| test_cli_driver.fard | 30 | parse_args, parse_flags, submit/frames/snapshot/health |
| test_workspace_format.fard | 21 | paths, manifest, verify, manifest_from_machine |
| test_editor_adapter.fard | 27 | sync states, diff apply, cursor, handshake, doc_hash |
| test_e2e_demo.fard | 18 | full pipeline: CLI->gateway->reducer->frame->editor |

Infrastructure:

| File | Assertions | Coverage |
|---|---|---|
| run_all.fard | 12 | fast full suite, Phase C proof object |
| test_reducer_failure.fard | - | failure suite via harness |
| test_reducer_edges.fard | - | edge cases via harness |
| test_stress_convergence.fard | 8 | 100-tx and batch-1 convergence (~80s) |

## Documented Behaviors

**Failure semantics:** rename-after-delete => FAILED, kind mismatch => FAILED,
missing dependency => PENDING (auto-retried), duplicate tx => DUPLICATE.

**Editor bridge:** STALE_FRAME if frameId <= clientVersion, FRAME_GAP if
frameId != clientVersion + 1. Duplicates silently skipped.

**Incremental diffs:** minimal_projection_diff() covers only the affected subtree.
Falls back to full-document on delete or missing node.

**Journal:** prevFrameHash chaining. verify_chain() detects broken sequences
and tampering. replay_journal() reconstructs text from entries alone.

**Gateway:** validates shape, checks workspaceId, deduplicates by tx.id,
assigns monotonic ingressSeq. Wrong-workspace txs marked REJECTED.

**Workspace partitions:** isolated gateway/log/consumer/journal/bus per workspace.
Same tx.id allowed in different workspaces.

**Snapshots:** snapshotHash covers version/frameId/asgHash/projectionHash.
restore_and_replay() uses frameId for correct journal suffix lookup.

**API contract:** POST /tx validates all 7 required fields. GET /frames
requires since >= 0. route() returns NOT_FOUND for unknown method+path.

**WebSocket:** deliveredUpTo tracked per subscription. FRAME_ALREADY_DELIVERED
on regression. pending_frame_messages() filters to undelivered only.

**CLI:** --key=value and boolean --flag parsing. submit supports rename/set/delete.
Unknown commands return UNKNOWN_COMMAND.

**Workspace format:** canonical paths for journal/log/snapshot/meta/receipts.
Manifest covers version+journalEntryCount+asgHash+projectionHash with manifestHash.

**Editor adapter:** sync states DISCONNECTED/CONNECTING/SYNCED/BEHIND/ERROR.
apply_diff_to_doc splices text by start/end offsets. cursor_offset checks bounds.

## Store Fixtures

- sample_store(): one function, two statements (Let + Return)
- deep_store(): two functions with subtrees (6 nodes total)
- wide_store(): one function with five children (7 nodes total)

## Proof of Execution

    fardrun run --program tests/run_all.fard --out out/tests_all
    fard_run_digest=sha256:975140f4ac0c929164c702d9595ae6f448bd71bbe6eec93fa185b7f55cc953c3
    { overallOk: true, phase: C, passed: 12, failed: 0 }

    fardrun run --program tests/test_e2e_demo.fard --out out/t_e2e
    fard_run_digest=sha256:373571348fee78becf188ade8c16ac3a1873d35d4f4e0eb7876f59c6ac32f3e4
    { ok: true, passed: 18, failed: 0 }

Stress suite:

    fardrun run --program tests/test_stress_convergence.fard --out out/t_stress

- 100-transaction convergence (batch size 5): PASS
- 50-transaction convergence (batch size 1): PASS
