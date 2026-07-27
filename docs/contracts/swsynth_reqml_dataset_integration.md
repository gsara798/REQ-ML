# swsynth to REQ-ML Dataset Integration

## Purpose

This integration test verifies the active cross-repository path:

```text
swsynth configuration
        |
        v
swsynth.run
        |
        v
wavefield_sample v1
        |
        v
REQ-ML generic loader
        |
        v
REQ readiness
        |
        v
REQ estimator and feature extraction
        |
        v
dataset example table
```

## Test case

The test uses a deterministic two-dimensional synthetic field with:

- a 2.0 m/s background;
- a circular 4.0 m/s inclusion;
- 500 Hz excitation;
- 16 in-plane propagation directions;
- random phases from a fixed seed;
- no added noise.

## What the test validates

The integration test checks that:

- `swsynth` produces a valid `wavefield_sample`;
- REQ-ML loads the sample without backend-specific adaptation;
- public array orientation remains `(z,x)`;
- REQ readiness is computed in REQ-ML;
- the real REQ estimator produces example rows;
- deterministic example IDs are unique;
- the dataset contains background, inclusion, pure, and mixed windows;
- real spectral features are present;
- per-window truth annotations match the synthetic material maps.

## Scope

This is a pipeline integration test, not a scientific performance benchmark.

It does not require the estimated SWS to match the true map within a selected
error tolerance. Scientific accuracy is evaluated separately in baseline
experiments.
