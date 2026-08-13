# Changelog

All notable public REQ-ML changes are documented here. The project follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and semantic
versioning for its public software interface.

## [Unreleased]

## [0.1.0] - 2026-08-13

### Added

- Controlled homogeneous Q0 baseline with dense SWS and angular coverage.
- Frozen model support for REQ window multipliers M=2 and M=3.
- External homogeneous projected-3D Eikonal and k-Wave validation.
- High-level `reqml.predictSWS` prediction API.
- Canonical homogeneous and circular-inclusion examples.
- Model-distribution metadata with bundle checksum and provenance.

### Changed

- User documentation now presents the current Q0 workflow instead of adaptive
  experiment history.
- Obsolete v1 user entry points are preserved under `archive/legacy_v1/`.

### Notes

- Large model bundles and generated scientific outputs are not committed.
- Tag and release publication remain manual steps after review.
