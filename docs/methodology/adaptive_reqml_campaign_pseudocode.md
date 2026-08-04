# Adaptive REQ-ML Simulation Campaign — Pseudocode

## Objective

Build a reproducible training dataset whose stopping criterion is based on **patch-level coverage**, not on a fixed number of simulations.

The main coverage space is:

- patch purity
- measured field diffusivity
- local shear-wave speed
- excitation frequency

The simulation framework generates physical wavefields. REQ-ML extracts and characterizes patches, evaluates coverage, and proposes the next simulation batch.

---

## Repositories and responsibilities

### `shear-wave-simulation-framework`

Responsible for:

- generating homogeneous, bilayer, and circular-inclusion media;
- generating projected-3D Eikonal wavefields;
- using reproducible geometry, field, and excitation seeds;
- saving wavefields, truth maps, directions, excitation parameters, metrics, and provenance;
- executing explicit simulation batches.

It does **not** calculate patch purity or ML targets.

### `REQ-ML`

Responsible for:

- loading simulation batches;
- extracting candidate patches;
- calculating patch purity and local true SWS;
- computing REQ features and targets;
- assigning patches to coverage bins;
- evaluating coverage deficits;
- proposing the next simulation batch.

---

## High-level adaptive loop

```text
INITIALIZE campaign state

WHILE coverage criteria are not satisfied:

    1. Read all completed simulation batches

    2. Build or update the patch dataset

    3. Characterize every candidate patch

    4. Assign patches to coverage bins

    5. Compute coverage statistics

    6. Identify deficient bins

    7. Translate deficits into new physical simulation conditions

    8. Generate a reproducible next-batch campaign file

    9. Review and approve the proposed batch

    10. Run the batch in the simulation framework

END WHILE

Freeze final dataset manifest
Create grouped train / validation / test splits
Train and evaluate REQ-ML models
```

---

## Detailed pseudocode

```text
FUNCTION run_adaptive_reqml_campaign(planner_config):

    state = initialize_campaign_state(planner_config)

    WHILE NOT coverage_complete(state.coverage_report):

        completed_runs = discover_completed_simulation_runs(
            campaign_roots = state.simulation_campaign_roots
        )

        patch_records = []

        FOR each run IN completed_runs:

            sample = load_wavefield_sample(run.wavefield_sample_path)

            validate_sample_contract(sample)

            patch_centers = enumerate_valid_patch_centers(
                sample = sample,
                patch_definition = planner_config.patch_definition,
                stride = planner_config.patch_stride
            )

            FOR each center IN patch_centers:

                patch = extract_patch(
                    wavefield = sample.wavefield.data_zx,
                    truth_maps = sample.truth,
                    center = center,
                    patch_definition = planner_config.patch_definition
                )

                patch_purity = compute_material_purity(
                    material_id_patch = patch.material_id_zx,
                    reference_material = material_at_patch_center
                )

                local_true_sws = sample.truth.cs_map_zx(center)

                interface_distance = compute_distance_to_interface(
                    material_id_map = sample.truth.material_id_zx,
                    center = center
                )

                field_metrics = read_or_compute_field_metrics(
                    sample = sample
                )

                req_features = compute_req_features(
                    wavefield_patch = patch.wavefield_zx,
                    frequency_hz = sample.wavefield.frequency_hz,
                    analysis_config = planner_config.req_analysis
                )

                req_target = compute_req_target(
                    req_features = req_features,
                    local_true_sws = local_true_sws,
                    target_config = planner_config.target_definition
                )

                record = {
                    run_id,
                    design_id,
                    condition_id,
                    realization_id,
                    geometry_family,
                    geometry_seed,
                    field_seed,
                    excitation_seed,
                    patch_center,
                    patch_purity,
                    local_true_sws,
                    frequency_hz,
                    interface_distance,
                    angular_entropy,
                    angular_effective_bins,
                    retained_in_plane_fraction,
                    nominal_solid_angle_sr,
                    direction_count,
                    req_features,
                    req_target
                }

                patch_records.append(record)

        coverage_table = assign_coverage_bins(
            patch_records,
            purity_bins = planner_config.purity_bins,
            diffusivity_bins = planner_config.diffusivity_bins,
            sws_bins = planner_config.sws_bins,
            frequency_bins = planner_config.frequency_bins
        )

        coverage_report = summarize_coverage(
            coverage_table,
            minimum_patches_per_cell,
            minimum_independent_runs_per_cell,
            minimum_geometry_seeds_per_cell,
            minimum_sws_bins_per_cell,
            minimum_frequencies_per_cell
        )

        save_coverage_report(
            coverage_report,
            parent_batch_ids = state.completed_batch_ids,
            reqml_commit = current_reqml_commit,
            simulation_commit = current_simulation_commit,
            planner_config_hash = hash(planner_config)
        )

        IF coverage_complete(coverage_report):
            BREAK

        deficits = find_coverage_deficits(coverage_report)

        proposed_conditions = []

        FOR each deficit IN deficits:

            strategy = map_deficit_to_simulation_strategy(deficit)

            candidate_conditions = propose_physical_conditions(
                deficit = deficit,
                strategy = strategy,
                parameter_ranges = planner_config.parameter_ranges,
                planner_seed = derive_seed(
                    planner_config.master_seed,
                    state.next_batch_index,
                    deficit.bin_id
                )
            )

            valid_conditions = filter_conditions(
                candidate_conditions,
                constraints = {
                    projected3d_eikonal_only,
                    minimum_points_per_wavelength,
                    valid_geometry_inside_domain,
                    interface_crosses_analysis_region,
                    sufficient_pure_material_area,
                    sufficient_mixed_patch_potential,
                    minimum_in_plane_directions,
                    valid_angular_support
                }
            )

            proposed_conditions.extend(valid_conditions)

        proposed_conditions = balance_next_batch(
            proposed_conditions,
            deficits,
            target_balance = {
                local_sws,
                frequency,
                geometry_family,
                nominal_angular_aperture
            },
            maximum_batch_size = planner_config.batch_size
        )

        FOR each condition IN proposed_conditions:

            condition.geometry_seed = derive_geometry_seed(...)
            condition.field_seed = derive_field_seed(...)
            condition.excitation_seed = derive_excitation_seed(...)
            condition.condition_id = deterministic_condition_id(condition)
            condition.realization_id = deterministic_realization_id(condition)
            condition.design_id = deterministic_design_id(condition)

        next_batch = write_explicit_simulation_campaign(
            schema_version = "1.2",
            backend = "swsynth",
            propagation_model = "projected3d_eikonal",
            runs = proposed_conditions,
            parent_coverage_report_hash = hash(coverage_report),
            planner_seed = planner_config.master_seed
        )

        save_next_batch_plan(next_batch)

        WAIT FOR human review and approval

        execute_batch_in_simulation_framework(next_batch)

        state = update_campaign_state(
            state,
            completed_batch = next_batch
        )

    final_dataset = freeze_dataset(
        patch_records,
        dataset_manifest,
        coverage_report,
        all_batch_ids,
        all_code_commits,
        all_config_hashes
    )

    splits = create_grouped_splits(
        final_dataset,
        group_by = condition_id,
        secondary_group = run_id
    )

    RETURN final_dataset, splits, coverage_report
```

---

## Deficit-to-simulation mapping

### Analytic bilayer with deficit-aware centers

The controlled training mode specializes dataset extension as follows. The
coverage snapshot is frozen before processing the new runs and is not updated
inside serial or parallel workers.

```text
pre_iteration_state = complete_coverage_grid(previous_coverage_report)

FOR each new analytic bilayer run:
    W = resolve_exact_REQ_window(run.frequency, cs_guess, grid_spacing, M)
    target = analytic_center_from_executed_batch_plan(run.condition_id)
    candidates = [target; truth_grid_centers(step = 2)]

    FOR each candidate:
        support = exact_odd_window_support(candidate, W)
        reject if support or valid-mask constraints fail
        purity = compute_material_purity(actual_discrete_truth_mask(support))
        local_sws = truth_sws_at_center(candidate)
        achieved_cell = bin(local_sws, frequency, purity, Dnom)

    selected = [target]
    WHILE selected count < 12:
        eligible = candidates whose achieved_cell was deficient in
                   pre_iteration_state
        enforce at most 2 useful centers per cell per run
        enforce center separation >= 0.75 W
        choose by run deficit, condition deficit, example deficit,
                  deficit score, never-observed status, distance,
                  deterministic seeded tie-break
        append choice, or stop if no candidate remains

    extract exactly selected centers
    persist role, rank, achieved cell, pre-iteration deficits,
            purity, coordinates, distances, run_id, and condition_id
```

The target is never replaced. Multiple selected patches remain examples from
one simulation run and one physical condition; coverage independence is still
computed with unique `run_id` and `condition_id` values.

```text
IF low-purity bins are deficient:
    prioritize bilayers crossing the usable ROI
    prioritize inclusions with radii comparable to patch size
    vary interface angle, interface offset, center, and radius

IF high-purity secondary-material bins are deficient:
    increase inclusion radius
    ensure sufficient interior area
    ensure both bilayer sides occupy enough usable area

IF low-diffusivity bins are deficient:
    reduce solid-angle support
    reduce direction count
    preserve required in-plane directions

IF high-diffusivity bins are deficient:
    increase solid-angle support
    increase direction count
    increase angular coverage

IF a local-SWS bin is deficient:
    constrain background or secondary-material SWS to that bin

IF a frequency bin is deficient:
    constrain the next batch to that frequency

IF one purity × diffusivity cell lacks independent runs:
    generate new geometry and field seeds
    do not oversample additional patches from existing runs
```

---

## Reproducibility rules

```text
The same:

- planner configuration
- parent coverage report
- master seed
- repository commits

must produce exactly the same proposed next batch.
```

Every simulation run must store:

```text
batch_id
condition_id
realization_id
design_id
geometry_seed
field_seed
excitation_seed
resolved configuration
simulation repository commit
REQ-ML repository commit
planner configuration hash
parent coverage report hash
```

Every patch must be traceable to:

```text
dataset row
→ patch ID
→ run ID
→ design ID
→ simulation configuration
→ seeds
→ source batch
```

---

## Stopping criterion

The campaign stops only when every required `purity × diffusivity` cell satisfies:

```text
minimum number of selected patches
minimum number of independent runs
minimum number of geometry seeds
minimum diversity of local SWS
minimum diversity of frequencies
```

The exact numerical quotas will be calibrated after the first prefinal batch.

---

## Critical interpretation

This methodology is scientifically coherent because REQ operates locally on patches.

The geometry is not the learning target. It is a controlled mechanism for generating patches with different material mixtures.

The main risks are:

1. treating correlated patches from one wavefield as independent;
2. using angular entropy as the only description of field geometry;
3. allowing patch count alone to determine coverage;
4. attempting to guarantee exact purity before patch extraction.

These risks are controlled by:

- grouping by run and condition;
- retaining nominal angular aperture, direction count, effective angular bins, and in-plane fraction;
- requiring independent runs and geometry seeds per bin;
- using an iterative generate–measure–correct loop.
## Geometry policy

Adaptive configs may set
`planning.training_geometry_mode = "analytic_bilayer"`. In this mode every
requested coverage cell receives one axis-aligned bilayer condition with a
grid-corrected interface and an exact planned patch center. See
`analytic_bilayer_training_geometry.md` for the equations, discrete mask
convention, feasibility rules, and audit metadata. Omitting the option keeps
the legacy geometry-balancing behavior.
