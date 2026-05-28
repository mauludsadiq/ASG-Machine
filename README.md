# ASG Machine

A deterministic collaborative ASG machine written in FARD.

Authoritative correctness flow:

```text
ordered semantic transaction stream
→ deterministic reducer
→ persistent ASG store
→ incremental projection engine
→ reducer frame broadcast
→ clients / VFS / LSP / sandbox consumers
```

This package implements:

- ASG node store with versioned structural mutation.
- Projection graph from ASG to deterministic text.
- Rope-like segment model with deterministic range replacement.
- Semantic transactions with dependencies and preconditions.
- Reducer frame machine with global versions and frame hashes.
- Deterministic convergence harness with fixed pseudo-random operation generation.
- Tests for rename/delete/move/idempotence/projection/replay/convergence.

## Layout

```text
src/core.fard          shared result/assert/hash helpers
src/asg.fard           ASG store and structural mutation
src/rope.fard          segment rope and text range replacement
src/projection.fard    ASG → text projection and incremental mutation
src/transactions.fard  transaction/precondition evaluation
src/reducer.fard       deterministic reducer
src/frame.fard         batch frame machine and replay
src/harness.fard       deterministic convergence harness
main.fard              executable demo summary
tests/*.fard           executable test programs
```

## Run

From this directory:

```bash
fardrun run --program main.fard --out out/asg_machine_demo
fardrun run --program tests/run_all.fard --out out/asg_machine_tests
```

The implementation avoids placeholders and stubs: all exported functions perform concrete validation or mutation and return deterministic records.
