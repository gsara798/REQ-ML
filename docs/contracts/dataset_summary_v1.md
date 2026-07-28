# Dataset summary contract v1

## Purpose

`reqml.datasets.summarize_dataset` audits an assembled REQ-ML dataset before
training.

It does not modify examples, select a final model, or train anything.

## Reported information

The summary contains:

- sample and example counts;
- numeric-variable counts;
- finite-value fractions;
- ranges, means, and standard deviations;
- constant numeric variables;
- candidate feature variables;
- target statistics;
- examples per campaign run;
- example distributions by background SWS, frequency, and direction count.

## Candidate feature detection

Candidate features are numeric variables that:

- are not known coordinates, metadata, truth, targets, or predictions;
- are not constant;
- satisfy the requested minimum finite fraction.

This is a first-pass audit. Final predictor selection remains an explicit
training-stage decision.

## Scientific role

The summary is used to detect:

- silent NaN propagation;
- constant or degenerate features;
- accidental inclusion of truth or target variables as predictors;
- imbalance across physical conditions;
- unexpected variation in example counts across runs.
