# Legacy REQ-ML Workflows

This directory preserves the configuration files, experiment scripts, and
study documentation that were active immediately before the reproducible
REQ-ML rebuild.

## Status

The contents of this directory are historical reference material.

They are not part of the active reproducible pipeline and should not be used
as authoritative baselines for new datasets, model training, or evaluation.

Historical scripts may depend on:

- old directory layouts;
- exploratory outputs;
- previously trained models;
- local paths;
- implicit assumptions;
- simulation engines that have since moved to the shear-wave simulation
  framework.

## How to use this archive

The archive may be consulted to recover:

- scientific ideas;
- parameter ranges;
- feature definitions;
- evaluation strategies;
- useful plots;
- lessons from prior experiments.

Code should be ported into the active tree only when its responsibility is
clear, its inputs and outputs are explicit, and it can be tested independently.

## Reproducibility policy

A historical result does not become an active baseline merely because its
files exist. New baselines must be regenerated from versioned code,
configuration, seeds, dataset manifests, split manifests, and model bundles.
