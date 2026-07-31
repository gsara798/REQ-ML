# REQ-ML Rebuild Plan

## Objective

Rebuild the active REQ-ML pipeline around reproducibility, traceability, and
clear ownership of responsibilities while preserving useful scientific work
from the exploratory repository history.

The rebuild is not a compatibility project. Historical experiments are
archived and used as reference material. Active datasets and models will be
generated again from the new pipeline.

## Guiding principles

1. Every active workflow starts from explicit configuration.
2. Every generated artifact has a deterministic or recorded identifier.
3. Dataset generation, splitting, training, and evaluation are separate steps.
4. Simulation backends communicate with REQ-ML through `wavefield_sample`.
5. REQ-ML does not implement its own k-Wave or synthetic wavefield solver.
6. Historical outputs and trained models are not authoritative baselines.
7. Existing scientific functions may be reused when their behavior is clear
   and covered by tests.
8. The active architecture should remain small and understandable.

## Active pipeline

```text
simulation campaign
        |
        v
wavefield_sample
        |
        v
dataset generation
        |
        v
dataset manifest + examples/features
        |
        v
grouped split manifest
        |
        v
model training
        |
        v
frozen model bundle
        |
        v
evaluation by condition, geometry, regime, and ROI
```

## Planned phases

### Phase 0 — Freeze and define

- archive historical configs, runners, analyses, and study documentation;
- define the active repository contract;
- classify source functions as KEEP, PORT, or RETIRE.

### Phase 1 — Minimal scientific core

Keep or port only the code required for:

- loading `wavefield_sample`;
- REQ readiness;
- local spectra;
- REQ quantile estimation;
- feature extraction;
- q-to-k and q-to-SWS conversion;
- core metrics.

### Phase 2 — Reproducible dataset pipeline

Implement:

- resolved dataset configuration;
- deterministic condition IDs and sample IDs;
- explicit seed policy;
- dataset manifest;
- condition and sample tables;
- feature/target tables;
- resume-safe generation.

### Phase 3 — Reproducible training

Implement:

- grouped split manifests;
- fixed training seeds;
- model configuration;
- model bundle;
- prediction table;
- metrics and provenance.

### Phase 4 — Baseline rebuild

Regenerate:

1. a compact homogeneous control dataset;
2. a heterogeneous baseline with bilayers and inclusions;
3. grouped train/test evaluation;
4. ROI- and geometry-specific reports.

### Phase 5 — Extensions

Only after the baseline is stable:

- realistic readout/noise;
- k-Wave transfer;
- estimability and reliability;
- anisotropy;
- attenuation;
- multifrequency workflows.
