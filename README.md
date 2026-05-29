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
stack: store, reducer, projection, frame broadcast, and client replay. All
execution is deterministic and content-addressed — every run produces a
cryptographic receipt tying inputs to outputs.

## Architecture

    ordered semantic transaction stream
    -> deterministic reducer
    -> persistent ASG store
    -> incremental projection engine
    -> reducer frame broadcast
    -> clients / VFS / LSP / sandbox consumers

## Modules

    src/core.fard                    shared result/assert/hash helpers
    src/asg.fard                     ASG store and structural mutation
    src/rope.fard                    segment rope and text range replacement
    src/projection.fard              ASG -> text projection and incremental mutation
    src/incremental_projection.fard  minimal subtree diff engine
    src/transactions.fard            transaction/precondition evaluation
    src/reducer.fard                 deterministic reducer
    src/frame.fard                   batch frame machine and replay
    src/editor_bridge.fard           deterministic client-side frame replay
    src/journal.fard                 deterministic replay journal with hash chaining
    src/recovery.fard                client catch-up from arbitrary version
    src/vfs.fard                     versioned document snapshots
    src/lsp_bridge.fard              LSP mirror with deterministic diagnostics
    src/harness.fard                 deterministic convergence harness
    main.fard                        executable demo summary
    tests/*.fard                     executable test programs

## Run

    # Demo
    fardrun run --program main.fard --out out/asg_machine_demo

    # Fast test suite (~seconds)
    fardrun run --program tests/run_all.fard --out out/tests_all

    # Stress convergence suite (~80s)
    fardrun run --program tests/test_stress_convergence.fard --out out/t_stress

## Scale

    2,390 lines of FARD across 38 files
    261 invariant assertions
    0 failures

## Test Suite

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
| test_editor_bridge.fard | 17 | single/multi frame apply, stale/gap rejection, determinism |
| test_journal.fard | 20 | append, chain integrity, corruption detection, replay |
| test_recovery.fard | 15 | catch-up replay, stale rejection, determinism |
| test_multi_client_convergence.fard | 16 | 5 clients, duplicate/partial/reconnect scenarios |
| test_vfs.fard | 13 | snapshots, frame apply, journal sync, hash determinism |
| test_lsp_bridge.fard | 12 | open/sync/close, diagnostics, unopened rejection |
| test_reducer_failure.fard | - | failure suite via harness |
| test_reducer_edges.fard | - | edge cases via harness |
| run_all.fard | 12 | fast full suite with hard invariant assertions |
| test_stress_convergence.fard | 8 | 100-tx and batch-1 convergence (~80s) |

## Documented Behaviors

**Failure semantics:**

- rename-after-delete => FAILED (precondition EXISTS fails on deleted node)
- kind mismatch => FAILED (precondition KIND_MATCH fails)
- missing dependency => PENDING (dependencies not yet in processedOps)
- duplicate tx id => DUPLICATE (idempotent, state unchanged)

**Pending resolution:**

The reducer automatically retries PENDING transactions when their dependencies
arrive in a subsequent batch. A transaction that was PENDING in batch N will
appear as APPLIED or FAILED in the batch where its dependency is first processed.

**Idempotency:**

Transaction IDs are tracked in processedOps across the lifetime of the machine.
Submitting the same tx.id twice in the same batch or across batches produces
DUPLICATE on the second occurrence. State and hash are unaffected.

**Editor bridge frame tracking:**

The editor bridge tracks frames by frameId (sequence number). Frames are rejected
as STALE_FRAME if frameId <= clientVersion, and as FRAME_GAP if frameId !=
clientVersion + 1. Duplicate frames are silently skipped without error.

**Incremental projection diffs:**

minimal_projection_diff() computes the span of the affected projection subtree
and emits a diff covering only that span. Falls back to full-document replacement
when the target node is deleted or not found in the new projection.
Unchanged subtree hashes are preserved across mutations.

**Replay journal:**

Each journal entry chains prevFrameHash -> frameHash. verify_chain() detects
broken sequences, broken hash links, and headHash mismatches. replay_journal()
reconstructs final text from journal entries alone — no snapshots required.

**Client recovery:**

recovery_state() computes missing frames for any client version. replay_since()
applies them deterministically via the editor bridge. check_recovery_valid()
rejects clients claiming a version ahead of the server.

**validate_projection error paths:**

- PROJECTION_TEXT_MISMATCH: projection text does not match a full rebuild.
- PROJECTION_HASH_MISMATCH: text matches but hash does not.

## Store Fixtures

- sample_store(): one function, two statements (Let + Return)
- deep_store(): two functions with subtrees (6 nodes total)
- wide_store(): one function with five children (7 nodes total)

## Proof of Execution

    fardrun run --program tests/run_all.fard --out out/tests_all
    fard_run_digest=sha256:ff7c0609f5d095c749a5dfec25c2e0994417ffccf3205c6b06a309c4bf999449

Verified properties:

- Projection convergence: PASS
- Replica/server text convergence: PASS
- Projection hash invariants: PASS
- Frame sequencing invariants: PASS
- Deterministic reducer replay: PASS
- Semantic failure handling: PASS
- Editor bridge stale/gap rejection: PASS
- Editor bridge replay determinism: PASS
- Incremental projection minimal diffs: PASS
- Incremental projection hash preservation: PASS
- Journal chain integrity and corruption detection: PASS
- Client recovery from arbitrary version: PASS
- 5-client convergence simulation: PASS
- VFS document sync determinism: PASS
- LSP mirror sync and diagnostics: PASS

Stress suite (separate, ~80s):

    fardrun run --program tests/test_stress_convergence.fard --out out/t_stress

- 100-transaction convergence (batch size 5): PASS
- 50-transaction convergence (batch size 1): PASS
