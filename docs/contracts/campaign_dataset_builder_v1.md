# Campaign dataset builder contract v1

## Purpose

`reqml.datasets.build_dataset_from_campaign` converts a validated campaign
inventory into one traceable table of local REQ examples.

## Processing stages

For every accepted campaign run, the builder:

1. loads `wavefield_sample.mat`;
2. checks REQ readiness;
3. extracts local patches, spectra, features, truth annotations, and targets;
4. attaches campaign identity and physical metadata to every example;
5. concatenates all example tables;
6. validates global example-ID uniqueness;
7. optionally saves dataset artifacts.

## Supervised target

The active target is:

```text
q_target_from_center_truth =
    Ecum_patch(2*pi*f / cs_true(center pixel))
```

Material purity does not redefine the target.

## Saved artifacts

- `examples.mat`: full example table;
- `samples.csv`: selected campaign inventory;
- `sample_summaries.csv`: one processing summary per sample;
- `variable_registry.csv`: column roles, sources, groups, trainability, and audit statistics;
- `dataset_summary.json`: serializable dataset audit including feature, target, and balance summaries;
- `dataset_manifest.json`: reproducibility metadata and target definition.

## First-phase scope

The initial implementation is fail-fast. A selected sample that is not
REQ-ready aborts the build rather than being silently discarded.

Dataset resume and chunked extraction are later extensions.

## Variable registry and summary

The builder computes the dataset summary before writing artifacts.

`variable_registry.csv` is the authoritative tabular record for every dataset
column. It includes the central schema classification together with finite
fractions, ranges, and constant-variable flags.

`dataset_summary.json` stores the corresponding dataset-level audit in a
portable form. MATLAB tables are converted to arrays of JSON objects before
serialization.

These artifacts make a saved dataset self-describing without requiring the
classification code to be rerun later.

## REQ_M and M compatibility fields

The current estimator publishes both `REQ_M` and `M`. They contain the same
window-length parameter and exist only for compatibility with older analysis
code.

They are diagnostics, not independent features. New code should use one
canonical name consistently; a later cleanup may remove the duplicate after
legacy workflows are archived.

