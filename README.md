# ASG Machine

A deterministic collaborative ASG machine written in FARD.

Authoritative correctness flow:

    ordered semantic transaction stream
    -> deterministic reducer
    -> persistent ASG store
    -> incremental projection engine
    -> reducer frame broadcast
    -> clients / VFS / LSP / sandbox consumers

This package implements:

- ASG node store with versioned structural mutation.
- Projection graph from ASG to deterministic text.
- Rope-like segment model with deterministic range replacement.
- Semantic transactions with dependencies and preconditions.
- Reducer frame machine with global versions and frame hashes.
- LCG-seeded pseudo-random operation generation for convergence harness.
- Isolated unit tests for every module with hard invariant assertions.

## Layout

    src/core.fard          shared result/assert/hash helpers
    src/asg.fard           ASG store and structural mutation
    src/rope.fard          segment rope and text range replacement
    src/projection.fard    ASG -> text projection and incremental mutation
    src/transactions.fard  transaction/precondition evaluation
    src/reducer.fard       deterministic reducer
    src/frame.fard         batch frame machine and replay
    src/harness.fard       deterministic convergence harness
    main.fard              executable demo summary
    tests/*.fard           executable test programs

## Run

From this directory:

    # Demo
    fardrun run --program main.fard --out out/asg_machine_demo

    # Fast test suite (~seconds)
    fardrun run --program tests/run_all.fard --out out/tests_all

    # Stress convergence suite (~80s)
    fardrun run --program tests/test_stress_convergence.fard --out out/t_stress

The implementation avoids placeholders and stubs: all exported functions perform
concrete validation or mutation and return deterministic records.

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
| test_validate_projection.fard | 14 | TEXT_MISMATCH, HASH_MISMATCH, happy path, all fixtures |
| test_idempotency.fard | 5 | same-batch and cross-batch duplicate handling |
| test_pending_resolution.fard | 4 | PENDING -> auto-retry when dependency arrives |
| test_convergence.fard | 10 | 50-tx convergence, all invariants hard-asserted |
| test_replay.fard | 10 | empty/single/multi frame replay, text and hash |
| test_reducer_failure.fard | — | failure suite via harness |
| test_reducer_edges.fard | — | edge cases via harness |
| run_all.fard | 12 | fast full suite with hard invariant assertions |
| test_stress_convergence.fard | 8 | 100-tx and batch-1 convergence (~80s) |

Total: 16 test files, 151+ assertions, 0 failures.

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

**validate_projection error paths:**

- PROJECTION_TEXT_MISMATCH: returned when the projection text does not match
  a full rebuild from the store. data.expected = correct text, data.actual = stale text.
- PROJECTION_HASH_MISMATCH: returned when text matches but hash does not.
  data.expected = correct hash, data.actual = stale hash.

## Store Fixtures

Three fixtures are available in asg.fard for testing:

- sample_store(): one function, two statements (Let + Return)
- deep_store(): two functions with subtrees (6 nodes total)
- wide_store(): one function with five children (7 nodes total)

## Proof of Execution

Version: v0.1.3 — Phase A complete

Fast suite verified properties:

- Projection convergence: PASS
- Replica/server text convergence: PASS
- Projection hash invariants: PASS
- Frame sequencing invariants: PASS
- Deterministic reducer replay: PASS
- Semantic failure handling: PASS
- Reducer edge cases: PASS
- validate_projection TEXT_MISMATCH: PASS
- validate_projection HASH_MISMATCH: PASS

Stress suite verified properties:

- 100-transaction convergence (batch size 5): PASS
- 50-transaction convergence (batch size 1): PASS

Verified commands:

    fardrun run --program tests/run_all.fard --out out/tests_all
    fardrun run --program tests/test_stress_convergence.fard --out out/t_stress
