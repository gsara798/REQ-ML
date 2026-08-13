# REQ-ML model distribution

Trained bundles are not committed to Git. The current frozen Q0 bundle is
650 MB, so release distribution should use a GitHub Release asset rather than
repository history. No download URL is recorded until that asset exists.

Install the expected file at `models/current/model_bundle.mat`, set the
`REQML_Q0_MODEL` environment variable, or pass its path explicitly:

```matlab
result = reqml.predictSWS(sample_file, Model="/path/model_bundle.mat", M=2);
```

The required SHA-256 is recorded in `models/current/model_manifest.json`.
