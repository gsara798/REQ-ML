# Active Repository Contract

## Active top-level directories

### `src/+reqml`

Reusable MATLAB package code. Files in this tree must expose clear inputs and
outputs and should be covered by unit or integration tests.

### `configs`

Only versioned configurations for active reproducible workflows.

Planned groups:

- `configs/datasets`
- `configs/training`
- `configs/evaluation`
- `configs/integration`
- `configs/shared`

### `experiments`

Thin entry points for active workflows. Experiment scripts orchestrate package
functions but should not contain large scientific implementations.

Planned groups:

- `experiments/dataset_generation`
- `experiments/training`
- `experiments/evaluation`
- `experiments/integration`
- `experiments/smoke`

### `tests`

Unit, integration, and regression tests for active code.

### `docs`

Architecture, contracts, decisions, and current workflows.

### `archive`

Historical material that is preserved but excluded from the active pipeline.

### `outputs`

Generated artifacts. Outputs are not source code and must be reproducible from
versioned configuration and code.

## Reproducible artifact requirements

### Dataset run

A dataset run should eventually produce:

```text
resolved_config.json
dataset_manifest.json
conditions.csv
samples.csv
examples/features artifact
summary.json
provenance.json
```

### Training run

A training run should eventually produce:

```text
resolved_config.json
dataset_manifest.json
split_manifest.json
model_bundle.mat
predictions.csv
metrics.csv
figures/
provenance.json
```

## Model validity rule

A trained model is an active baseline only when the repository records:

- code commit;
- dataset identity;
- resolved dataset configuration;
- split manifest;
- training configuration;
- all random seeds;
- model bundle;
- evaluation metrics.

Models without this information are exploratory artifacts.

## Source classification policy

Each existing source function will be assigned one status:

- **KEEP** — active responsibility is already clear;
- **PORT** — useful implementation, but it must move or receive a cleaner API;
- **RETIRE** — duplicate backend, study-specific orchestration, or obsolete
  exploratory code.

No function is retained solely because a historical script depends on it.
