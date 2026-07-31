# REQ-ML Dataset Examples Contract v1

## Purpose

The dataset example layer converts one loaded `wavefield_sample` into one row
per estimator window.

It is the boundary between field-level simulation outputs and model-ready
tabular data.

## API

```matlab
dataset = reqml.datasets.extract_examples_from_sample( ...
    data, ...
    feature_config, ...
    DatasetId="heterogeneous_v1", ...
    SampleId="sample_000001");
```

## Output

```text
dataset.schema_name
dataset.schema_version
dataset.dataset_id
dataset.sample_id
dataset.examples
dataset.estimator
dataset.sample_summary
```

## Required identifiers

Each row contains:

- `dataset_id`
- `sample_id`
- `example_id`

The example identifier is deterministic from the sample identifier and the
window center:

```text
<sample_id>__z<cz>_x<cx>
```

## Estimator outputs

The table preserves scalar estimator and feature columns produced by
`reqml.estimators.req_estimator_map`, including `q_local_req`.

## Heterogeneous truth annotations

Each window receives:

- center SWS;
- mean, median, standard deviation, minimum, and maximum SWS;
- center material ID;
- dominant material ID;
- dominant-material purity;
- valid-pixel fraction.

These annotations allow later pipelines to distinguish pure homogeneous
windows, heterogeneous interior windows, and interface-contaminated windows
without regenerating the field.

## Responsibilities intentionally excluded

This layer does not:

- save the dataset;
- assign train/test splits;
- train models;
- choose ROIs;
- filter examples by purity;
- define the final ML target.

Those decisions belong to later dataset assembly and training stages.
