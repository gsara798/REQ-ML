function dataset = build_dataset_from_campaign( ...
    campaign_runs_csv, feat_cfg, options)
%BUILD_DATASET_FROM_CAMPAIGN Build one traceable REQ-ML dataset.
%
% Each accepted campaign run contributes one wavefield sample. Each sample is
% converted into local patch examples using extract_examples_from_sample.
%
% The supervised target is:
%
%   q_target_from_center_truth =
%       Ecum_patch(2*pi*f / cs_true(center pixel))

arguments
    campaign_runs_csv {mustBeTextScalar}
    feat_cfg (1,1) struct

    options.DatasetId (1,1) string = "dataset"
    options.MaxSamples (1,1) double = Inf
    options.RequireBackend (1,1) string = ""
    options.CsGuessMPerS (1,1) double = 3.0
    options.WindowWavelengths (1,1) double = 2.0
    options.MinimumPlacementsPerAxis (1,1) double = 5
    options.StepX (1,1) double = NaN
    options.StepZ (1,1) double = NaN

    options.UseDirectedCenterSelection (1,1) logical = false
    options.PurityEdges (1,:) double = zeros(1,0)
    options.DiffusivityEdges (1,:) double = zeros(1,0)
    options.SwsEdges (1,:) double = zeros(1,0)
    options.FrequencyEdges (1,:) double = zeros(1,0)
    options.CandidateStepPixels (1,1) double = 2
    options.MaximumCentersPerCell (1,1) double = 4
    options.MinimumCenterDistanceFraction (1,1) double = 0.5
    options.MinimumValidFraction (1,1) double = 1
    options.CenterSelectionSeedOffset (1,1) double = 0

    options.AdaptiveBatchPlanFile (1,1) string = ""

    options.StoreReqCurves (1,1) logical = false
    options.UseWindowParfor (1,1) logical = false
    options.UseSampleParfor (1,1) logical = false
    options.OutputDirectory (1,1) string = ""
    options.SaveOutputs (1,1) logical = true
    options.PreviousDatasetDirectory (1,1) string = ""
    options.TheoryClassMapping (:,1) struct = struct.empty

    options.Loader (1,1) function_handle = ...
        @reqml.io.load_wavefield_sample

    options.ReadinessEvaluator (1,1) function_handle = ...
        @reqml.readiness.assess_req_readiness

    options.Extractor (1,1) function_handle = ...
        @reqml.datasets.extract_examples_from_sample
end

inventory = reqml.datasets.load_campaign_samples( ...
    campaign_runs_csv, ...
    MaxSamples=options.MaxSamples, ...
    RequireBackend=options.RequireBackend);

previous_dataset = load_previous_dataset( ...
    options.PreviousDatasetDirectory, ...
    feat_cfg, ...
    options);

processing_samples = inventory.samples;

if previous_dataset.available
    previous_run_ids = string( ...
        previous_dataset.samples.run_id);

    current_run_ids = string( ...
        processing_samples.run_id);

    is_new_run = ~ismember( ...
        current_run_ids, ...
        previous_run_ids);

    processing_samples = ...
        processing_samples(is_new_run, :);
end

new_sample_count = height(processing_samples);

analytic_center_controls = ...
    resolve_analytic_center_controls( ...
        processing_samples, ...
        options.AdaptiveBatchPlanFile);

example_tables = cell(new_sample_count, 1);
summary_records = repmat( ...
    empty_summary_record(), ...
    new_sample_count, ...
    1);

if options.UseSampleParfor && options.UseWindowParfor
    error("reqml:NestedDatasetParallelismNotSupported", ...
        ["UseSampleParfor and UseWindowParfor cannot both be true. " ...
         "Choose one parallelization level."]);
end

if options.UseSampleParfor && new_sample_count > 1
    ensure_parallel_pool();

    parfor sample_index = 1:new_sample_count
        run = processing_samples(sample_index, :);

        [example_tables{sample_index}, ...
            summary_records(sample_index)] = ...
            process_campaign_sample( ...
                run, ...
                feat_cfg, ...
                options, ...
                analytic_center_controls(sample_index));
    end
else
    for sample_index = 1:new_sample_count
        run = processing_samples(sample_index, :);

        [example_tables{sample_index}, ...
            summary_records(sample_index)] = ...
            process_campaign_sample( ...
                run, ...
                feat_cfg, ...
                options, ...
                analytic_center_controls(sample_index));
    end
end

if new_sample_count > 0
    new_examples = vertcat(example_tables{:});
    new_sample_summaries = ...
        struct2table(summary_records);
else
    new_examples = table();
    new_sample_summaries = table();
end

if previous_dataset.available
    examples = concatenate_compatible_tables( ...
        previous_dataset.examples, ...
        new_examples, ...
        "examples");

    sample_summaries = concatenate_compatible_tables( ...
        previous_dataset.sample_summaries, ...
        new_sample_summaries, ...
        "sample summaries");
else
    examples = new_examples;
    sample_summaries = new_sample_summaries;
end

if numel(unique(examples.example_id)) ~= height(examples)
    error("reqml:DuplicateCampaignExampleId", ...
        "Combined campaign dataset contains duplicate example IDs.");
end

if ~all(examples.target_valid)
    error("reqml:InvalidCenterTruthTargets", ...
        "Combined campaign dataset contains invalid center-truth targets.");
end

dataset = struct();
dataset.schema_name = "reqml_campaign_dataset";
dataset.schema_version = "1.0";
dataset.dataset_id = options.DatasetId;
dataset.campaign_runs_csv = string(campaign_runs_csv);
dataset.sample_count = inventory.sample_count;
dataset.example_count = height(examples);
dataset.previous_sample_count = ...
    previous_dataset.sample_count;
dataset.new_sample_count = new_sample_count;
dataset.reused_sample_count = ...
    previous_dataset.sample_count;
dataset.inventory = inventory;
dataset.sample_summaries = sample_summaries;
dataset.examples = examples;
dataset.feature_config = feat_cfg;
dataset.build_config = make_build_config(options);

dataset.summary = ...
    reqml.datasets.summarize_dataset(dataset);

dataset.manifest = make_manifest(dataset);

if options.SaveOutputs
    output_directory = resolve_output_directory( ...
        options.OutputDirectory, ...
        options.DatasetId);

    dataset.paths = save_dataset_outputs( ...
        dataset, ...
        output_directory);
else
    dataset.paths = struct();
end

end

function [examples, summary_record] = ...
        process_campaign_sample( ...
            run, feat_cfg, options, analytic_center_control)

data = options.Loader( ...
    run.wavefield_sample_path);

readiness = options.ReadinessEvaluator( ...
    data, ...
    CsGuessMPerS=options.CsGuessMPerS, ...
    WindowWavelengths=double(feat_cfg.M), ...
    MinimumPlacementsPerAxis= ...
        options.MinimumPlacementsPerAxis);

if ~readiness.valid
    error("reqml:CampaignSampleNotReqReady", ...
        "Campaign run '%s' is not REQ-ready: %s", ...
        run.run_id, ...
        readiness.summary);
end

sample_feat_cfg = feat_cfg;

extraction_arguments = {
    "DatasetId", options.DatasetId
    "SampleId", run.run_id
    "StepX", options.StepX
    "StepZ", options.StepZ
    "StoreReqCurves", options.StoreReqCurves
    "UseWindowParfor", options.UseWindowParfor
    };

if options.UseDirectedCenterSelection || ...
        analytic_center_control.enabled
    frequency_hz = double(run.frequency_hz);

    physical_cfg = struct();
    physical_cfg.dx = double(data.dx_m);
    physical_cfg.dz = double(data.dz_m);
    physical_cfg.f0 = double(data.frequency_hz);

    if isfield(data, "background_cs_m_s")
        physical_cfg.cs_bg = ...
            double(data.background_cs_m_s);
    else
        physical_cfg.cs_bg = ...
            options.CsGuessMPerS;
    end

    resolved_input_feat_cfg = ...
        complete_feature_config(sample_feat_cfg);

    [~, resolved_feat_cfg] = ...
        reqml.config.default_req_config( ...
            physical_cfg, ...
            resolved_input_feat_cfg);

    win_size = resolved_feat_cfg.win_size;
    sample_feat_cfg = resolved_feat_cfg;

    if analytic_center_control.enabled
        validate_analytic_center_control( ...
            analytic_center_control, ...
            data, ...
            win_size, ...
            run);

        extraction_arguments(end + 1, :) = { ...
            "CenterIndices", ...
            analytic_center_control. ...
                selected_patch_center_indices_xz};
    else
        validate_directed_center_options(options, run);

        dnom = reqml.coverage.computeNominalAngularCoverage( ...
        double(run.direction_count), ...
        double(run.solid_angle_sr), ...
        MaximumDirectionCount=128);

    frequency_bin = double(discretize( ...
        frequency_hz, ...
        options.FrequencyEdges));

    dnom_bin = double(discretize( ...
        dnom, ...
        options.DiffusivityEdges));

    if ~isfinite(frequency_bin) || frequency_bin < 1
        error("reqml:DirectedCenterFrequencyOutOfRange", ...
            "Run '%s' frequency is outside FrequencyEdges.", ...
            string(run.run_id));
    end

    if ~isfinite(dnom_bin) || dnom_bin < 1
        error("reqml:DirectedCenterDnomOutOfRange", ...
            ["Run '%s' nominal angular coverage is outside " ...
             "DiffusivityEdges."], ...
            string(run.run_id));
    end

    requested_cells = make_run_requested_cells( ...
        options.SwsEdges, ...
        options.PurityEdges, ...
        frequency_bin, ...
        dnom_bin, ...
        options.MaximumCentersPerCell);

    minimum_distance = max( ...
        0, ...
        floor( ...
            options.MinimumCenterDistanceFraction * ...
            win_size));

    selection_seed = double(run.seed) + ...
        options.CenterSelectionSeedOffset;

    extraction_arguments(end + 1, :) = { ...
        "RequestedCoverageCells", ...
        requested_cells};

    extraction_arguments(end + 1, :) = { ...
        "PurityEdges", ...
        options.PurityEdges};

    extraction_arguments(end + 1, :) = { ...
        "DiffusivityEdges", ...
        options.DiffusivityEdges};

    extraction_arguments(end + 1, :) = { ...
        "SwsEdges", ...
        options.SwsEdges};

    extraction_arguments(end + 1, :) = { ...
        "FrequencyEdges", ...
        options.FrequencyEdges};

    extraction_arguments(end + 1, :) = { ...
        "DiffusivityValue", ...
        dnom};

    extraction_arguments(end + 1, :) = { ...
        "CandidateStepPixels", ...
        options.CandidateStepPixels};

    extraction_arguments(end + 1, :) = { ...
        "MaximumCentersPerCell", ...
        options.MaximumCentersPerCell};

    extraction_arguments(end + 1, :) = { ...
        "MinimumCenterDistancePixels", ...
        minimum_distance};

    extraction_arguments(end + 1, :) = { ...
        "MinimumValidFraction", ...
        options.MinimumValidFraction};

    extraction_arguments(end + 1, :) = { ...
        "CenterSelectionSeed", ...
        selection_seed};
    end
end

extraction_arguments = reshape( ...
    extraction_arguments.', ...
    1, []);

extraction = options.Extractor( ...
    data, ...
    sample_feat_cfg, ...
    extraction_arguments{:});

examples = attach_campaign_metadata( ...
    extraction.examples, ...
    run);

if ~isempty(options.TheoryClassMapping)
    examples = ...
        reqml.datasets.attach_theory_baseline( ...
            examples, ...
            run, ...
            feat_cfg, ...
            options.TheoryClassMapping);
end

summary_record = make_summary_record( ...
    run, ...
    readiness, ...
    extraction.sample_summary);

end


function controls = resolve_analytic_center_controls( ...
        samples, adaptive_batch_plan_file)

template = struct( ...
    "enabled", false, ...
    "condition_id", "", ...
    "selected_patch_center_indices_xz", [NaN NaN], ...
    "patch_size_pixels", [NaN NaN], ...
    "grid_spacing_m", [NaN NaN], ...
    "predicted_discrete_purity", NaN);

controls = repmat(template, height(samples), 1);

if strlength(adaptive_batch_plan_file) == 0 || isempty(samples)
    return
end

if ~isfile(adaptive_batch_plan_file)
    error("reqml:AdaptiveBatchPlanNotFound", ...
        "Adaptive batch plan was not found: %s", ...
        adaptive_batch_plan_file);
end

plan = jsondecode(fileread(adaptive_batch_plan_file));

if ~isfield(plan, "physical_conditions") || ...
        isempty(plan.physical_conditions)
    return
end

available = string(samples.Properties.VariableNames);

if ~ismember("condition_id", available)
    has_analytic = arrayfun(@condition_has_analytic_control, ...
        plan.physical_conditions);

    if any(has_analytic)
        error("reqml:AnalyticBilayerConditionIdMissing", ...
            "Campaign samples need condition_id for analytic center control.");
    end

    return
end

sample_condition_ids = string(samples.condition_id);

for condition_index = 1:numel(plan.physical_conditions)
    condition = plan.physical_conditions(condition_index);

    if ~condition_has_analytic_control(condition)
        continue
    end

    condition_id = string(condition.condition_id);
    matches = find(sample_condition_ids == condition_id);
    control = condition.geometry_control;

    if isempty(matches)
        error("reqml:AnalyticBilayerConditionSampleNotFound", ...
            "No executed sample matches analytic condition '%s'.", ...
            condition_id);
    end

    for sample_index = reshape(matches, 1, [])
        controls(sample_index).enabled = true;
        controls(sample_index).condition_id = condition_id;
        controls(sample_index).selected_patch_center_indices_xz = ...
            double(control.selected_patch_center_indices_xz(:))';
        controls(sample_index).patch_size_pixels = ...
            double(control.patch_size_pixels(:))';
        controls(sample_index).grid_spacing_m = ...
            double(control.grid_spacing_m(:))';
        controls(sample_index).predicted_discrete_purity = ...
            double(control.predicted_discrete_purity);
    end
end

end


function result = condition_has_analytic_control(condition)

result = isfield(condition, "geometry_control") && ...
    isfield(condition.geometry_control, "geometry_control_mode") && ...
    string(condition.geometry_control.geometry_control_mode) == ...
        "analytic_bilayer";

end


function validate_analytic_center_control( ...
        control, data, win_size, run)

if any(control.patch_size_pixels ~= [win_size win_size])
    error("reqml:AnalyticBilayerPatchSupportMismatch", ...
        "Run '%s' resolved REQ window [%d,%d], but its analytic " + ...
        "plan specifies [%d,%d].", ...
        string(run.run_id), win_size, win_size, ...
        control.patch_size_pixels(1), ...
        control.patch_size_pixels(2));
end

actual_spacing = [double(data.dx_m), double(data.dz_m)];

if any(abs(actual_spacing - control.grid_spacing_m) > ...
        64 * eps(max(actual_spacing, control.grid_spacing_m)))
    error("reqml:AnalyticBilayerGridSpacingMismatch", ...
        "Run '%s' grid spacing differs from its analytic plan.", ...
        string(run.run_id));
end

center = control.selected_patch_center_indices_xz;

if any(~isfinite(center)) || any(center < 1) || ...
        any(center ~= fix(center))
    error("reqml:InvalidAnalyticBilayerPatchCenter", ...
        "Run '%s' has an invalid analytic patch center.", ...
        string(run.run_id));
end

end


function ensure_parallel_pool()

pool = gcp("nocreate");

if ~isempty(pool) && isa(pool, "parallel.ThreadPool")
    fprintf( ...
        "Closing thread-based parallel pool because MAT v7.3 " + ...
        "samples require process workers.\n");

    delete(pool);
    pool = [];
end

if isempty(pool)
    pool = parpool("Processes");
end

fprintf( ...
    "REQ sample processing uses %d process workers.\n", ...
    pool.NumWorkers);

end


function previous = load_previous_dataset( ...
        directory, feat_cfg, options)

previous = struct();
previous.available = false;
previous.sample_count = 0;
previous.samples = table();
previous.examples = table();
previous.sample_summaries = table();

if strlength(directory) == 0
    return
end

directory = string(directory);

required_paths = struct();
required_paths.examples = fullfile( ...
    directory, ...
    "examples.mat");
required_paths.samples = fullfile( ...
    directory, ...
    "samples.csv");
required_paths.sample_summaries = fullfile( ...
    directory, ...
    "sample_summaries.csv");
required_paths.manifest = fullfile( ...
    directory, ...
    "dataset_manifest.json");

names = string(fieldnames(required_paths));

for index = 1:numel(names)
    name = names(index);
    path_value = required_paths.(name);

    if ~isfile(path_value)
        error("reqml:PreviousDatasetArtifactNotFound", ...
            "Previous dataset artifact was not found: %s", ...
            path_value);
    end
end

loaded = load( ...
    required_paths.examples, ...
    "examples");

if ~isfield(loaded, "examples") || ...
        ~istable(loaded.examples)
    error("reqml:InvalidPreviousDatasetExamples", ...
        "Previous examples MAT file must contain table 'examples'.");
end

samples = readtable( ...
    required_paths.samples, ...
    Delimiter=",", ...
    TextType="string");

sample_summaries = readtable( ...
    required_paths.sample_summaries, ...
    Delimiter=",", ...
    TextType="string");

manifest = jsondecode( ...
    fileread(required_paths.manifest));

validate_previous_dataset_compatibility( ...
    manifest, ...
    feat_cfg, ...
    options);

if ~ismember("run_id", ...
        string(samples.Properties.VariableNames))
    error("reqml:PreviousDatasetRunIdNotFound", ...
        "Previous samples table does not contain run_id.");
end

if numel(unique(string(samples.run_id))) ~= ...
        height(samples)
    error("reqml:DuplicatePreviousDatasetRunId", ...
        "Previous samples table contains duplicate run IDs.");
end

previous.available = true;
previous.sample_count = height(samples);
previous.samples = samples;
previous.examples = loaded.examples;
previous.sample_summaries = sample_summaries;

end


function validate_previous_dataset_compatibility( ...
        manifest, feat_cfg, options)

if ~isfield(manifest, "feature_config") || ...
        ~isfield(manifest, "build_config")
    error("reqml:PreviousDatasetManifestIncomplete", ...
        "Previous dataset manifest lacks configuration metadata.");
end

expected_feature_config = ...
    canonicalize_json_value(feat_cfg);

previous_feature_config = ...
    canonicalize_json_value(manifest.feature_config);

if ~isequaln( ...
        orderfields(previous_feature_config), ...
        orderfields(expected_feature_config))
    error("reqml:PreviousDatasetFeatureConfigMismatch", ...
        "Previous dataset feature configuration is incompatible.");
end

expected_build_config = ...
    make_build_config(options);

previous_build_config = ...
    manifest.build_config;

% These fields do not change how an individual sample is extracted.
ignored_fields = [
    "dataset_id"
    "max_samples"
    "use_sample_parfor"
    "use_window_parfor"
    ];

for index = 1:numel(ignored_fields)
    field_name = ignored_fields(index);

    if isfield(expected_build_config, field_name)
        expected_build_config = rmfield( ...
            expected_build_config, ...
            field_name);
    end

    if isfield(previous_build_config, field_name)
        previous_build_config = rmfield( ...
            previous_build_config, ...
            field_name);
    end
end

expected_build_config = ...
    canonicalize_json_value(expected_build_config);

previous_build_config = ...
    canonicalize_json_value(previous_build_config);

if ~isequaln( ...
        orderfields(previous_build_config), ...
        orderfields(expected_build_config))
    error("reqml:PreviousDatasetBuildConfigMismatch", ...
        "Previous dataset build configuration is incompatible.");
end

end


function value = canonicalize_json_value(value)

value = jsondecode(jsonencode(value));

end


function combined = concatenate_compatible_tables( ...
        previous, current, description)

if isempty(previous)
    combined = current;
    return
end

if isempty(current)
    combined = previous;
    return
end

previous_names = string( ...
    previous.Properties.VariableNames);

current_names = string( ...
    current.Properties.VariableNames);

if ~isequal(previous_names, current_names)
    error("reqml:IncrementalDatasetSchemaMismatch", ...
        "Previous and current %s tables have different schemas.", ...
        description);
end

combined = [
    previous
    current
    ];

end


function completed = complete_feature_config(requested)

completed = reqml.config.default_feature_config();
names = string(fieldnames(requested));

for index = 1:numel(names)
    name = names(index);
    completed.(name) = requested.(name);
end

end


function win_size = resolve_center_selection_window(readiness)

win_size = max( ...
    double(readiness.window_points_x), ...
    double(readiness.window_points_z));

win_size = round(win_size);

if mod(win_size, 2) == 0
    win_size = win_size + 1;
end

end


function requested = make_run_requested_cells( ...
    sws_edges, purity_edges, frequency_bin, ...
    diffusivity_bin, maximum_per_cell)

sws_bin_count = numel(sws_edges) - 1;
purity_bin_count = numel(purity_edges) - 1;

[sws_bin, purity_bin] = ndgrid( ...
    1:sws_bin_count, ...
    1:purity_bin_count);

n = numel(sws_bin);

requested = table();
requested.sws_bin = double(sws_bin(:));
requested.frequency_bin = repmat( ...
    double(frequency_bin), n, 1);
requested.purity_bin = double(purity_bin(:));
requested.diffusivity_bin = repmat( ...
    double(diffusivity_bin), n, 1);
requested.needed_example_count = repmat( ...
    double(maximum_per_cell), n, 1);

end


function validate_directed_center_options(options, run)

edge_sets = {
    options.PurityEdges, "PurityEdges"
    options.DiffusivityEdges, "DiffusivityEdges"
    options.SwsEdges, "SwsEdges"
    options.FrequencyEdges, "FrequencyEdges"
    };

for index = 1:size(edge_sets, 1)
    edges = double(edge_sets{index, 1});
    name = string(edge_sets{index, 2});

    if numel(edges) < 2 || ...
            any(~isfinite(edges)) || ...
            any(diff(edges) <= 0)
        error("reqml:InvalidDirectedCenterEdges", ...
            "%s must contain finite strictly increasing edges.", ...
            name);
    end
end

required_run_variables = [
    "frequency_hz"
    "direction_count"
    "solid_angle_sr"
    "seed"
    ];

missing = setdiff( ...
    required_run_variables, ...
    string(run.Properties.VariableNames));

if ~isempty(missing)
    error("reqml:MissingDirectedCenterRunVariable", ...
        "Run metadata is missing '%s'.", missing(1));
end

if options.MaximumCentersPerCell < 1 || ...
        options.MaximumCentersPerCell ~= ...
            round(options.MaximumCentersPerCell)
    error("reqml:InvalidMaximumCentersPerCell", ...
        "MaximumCentersPerCell must be a positive integer.");
end

if options.MinimumCenterDistanceFraction < 0
    error("reqml:InvalidCenterDistanceFraction", ...
        "MinimumCenterDistanceFraction must be nonnegative.");
end

end


function examples = attach_campaign_metadata(examples, run)
%ATTACH_CAMPAIGN_METADATA Propagate scientific run metadata to every patch.

n = height(examples);

source_names = [
    "ordinal"
    "design_id"
    "condition_id"
    "realization_id"
    "run_id"
    "hash_sha256"
    "backend"
    "scenario"
    "seed"
    "frequency_hz"
    "background_cs_m_s"
    "medium_object_count"
    "primary_object_type"
    "primary_object_cs_m_s"
    "primary_object_radius_m"
    "primary_object_center_x_m"
    "primary_object_center_z_m"
    "primary_object_normal_angle_rad"
    "primary_object_offset_m"
    "geometry_family"
    "direction_count"
    "retained_direction_count"
    "direction_support_type"
    "solid_angle_sr"
    "requested_in_plane_count"
    "retained_in_plane_count"
    "retained_in_plane_fraction"
    "angular_entropy"
    "angular_effective_bins"
    "radial_entropy"
    "radial_effective_bins"
    "propagation_model"
    "wavefield_sample_path"
    ];

target_names = [
    "campaign_ordinal"
    "campaign_design_id"
    "campaign_condition_id"
    "campaign_realization_id"
    "campaign_run_id"
    "campaign_hash_sha256"
    "campaign_backend"
    "campaign_scenario"
    "campaign_seed"
    "campaign_frequency_hz"
    "campaign_background_cs_m_s"
    "campaign_medium_object_count"
    "campaign_primary_object_type"
    "campaign_primary_object_cs_m_s"
    "campaign_primary_object_radius_m"
    "campaign_primary_object_center_x_m"
    "campaign_primary_object_center_z_m"
    "campaign_primary_object_normal_angle_rad"
    "campaign_primary_object_offset_m"
    "campaign_geometry_family"
    "campaign_direction_count"
    "campaign_retained_direction_count"
    "campaign_direction_support_type"
    "campaign_solid_angle_sr"
    "campaign_requested_in_plane_count"
    "campaign_retained_in_plane_count"
    "campaign_retained_in_plane_fraction"
    "campaign_angular_entropy"
    "campaign_angular_effective_bins"
    "campaign_radial_entropy"
    "campaign_radial_effective_bins"
    "campaign_propagation_model"
    "campaign_sample_file"
    ];

if numel(source_names) ~= numel(target_names)
    error("reqml:CampaignMetadataMappingMismatch", ...
        ["Campaign metadata source and target mappings must " ...
         "have equal lengths."]);
end

available = string(run.Properties.VariableNames);
attached_names = strings(0, 1);

for index = 1:numel(source_names)
    source_name = source_names(index);
    target_name = target_names(index);

    if ~ismember(source_name, available)
        continue
    end

    value = run.(source_name);

    if height(run) ~= 1
        error("reqml:InvalidCampaignMetadataRow", ...
            "Campaign metadata attachment requires exactly one run.");
    end

    examples.(target_name) = repeat_metadata_value( ...
        value, ...
        n, ...
        source_name);

    attached_names(end + 1, 1) = target_name; %#ok<AGROW>
end

if ~isempty(attached_names)
    examples = movevars( ...
        examples, ...
        attached_names, ...
        "After", ...
        "example_id");
end

end


function repeated = repeat_metadata_value(value, n, source_name)

if iscell(value)
    if numel(value) ~= 1
        error("reqml:InvalidCampaignMetadataValue", ...
            "Campaign metadata '%s' must be scalar.", ...
            source_name);
    end

    value = value{1};
end

if isstring(value) || ischar(value)
    repeated = repmat(string(value), n, 1);
    return
end

if iscategorical(value)
    repeated = repmat(string(value), n, 1);
    return
end

if isnumeric(value) || islogical(value)
    if ~isscalar(value)
        error("reqml:InvalidCampaignMetadataValue", ...
            "Campaign metadata '%s' must be scalar.", ...
            source_name);
    end

    repeated = repmat(value, n, 1);
    return
end

error("reqml:UnsupportedCampaignMetadataType", ...
    "Campaign metadata '%s' has an unsupported type.", ...
    source_name);

end


function record = make_summary_record( ...
        run, readiness, sample_summary)

record = empty_summary_record();

record.ordinal = double(run.ordinal);
record.run_id = string(run.run_id);
record.hash_sha256 = string(run.hash_sha256);
record.backend = string(run.backend);
record.scenario = string(run.scenario);
record.seed = double(run.seed);
record.frequency_hz = double(run.frequency_hz);
record.background_cs_m_s = ...
    double(run.background_cs_m_s);
record.direction_count = ...
    double(run.direction_count);
record.wavefield_sample_path = ...
    string(run.wavefield_sample_path);

record.req_ready = logical(readiness.valid);
record.req_window_points_x = ...
    double(readiness.window_points_x);
record.req_window_points_z = ...
    double(readiness.window_points_z);
record.req_placements_x = ...
    double(readiness.placements_x);
record.req_placements_z = ...
    double(readiness.placements_z);

record.example_count = ...
    double(sample_summary.example_count);
record.valid_example_count = ...
    double(sample_summary.valid_example_count);
record.minimum_material_purity = ...
    double(sample_summary.minimum_material_purity);
record.median_material_purity = ...
    double(sample_summary.median_material_purity);

end

function record = empty_summary_record()

record = struct();
record.ordinal = NaN;
record.run_id = "";
record.hash_sha256 = "";
record.backend = "";
record.scenario = "";
record.seed = NaN;
record.frequency_hz = NaN;
record.background_cs_m_s = NaN;
record.direction_count = NaN;
record.wavefield_sample_path = "";
record.req_ready = false;
record.req_window_points_x = NaN;
record.req_window_points_z = NaN;
record.req_placements_x = NaN;
record.req_placements_z = NaN;
record.example_count = NaN;
record.valid_example_count = NaN;
record.minimum_material_purity = NaN;
record.median_material_purity = NaN;

end

function config = make_build_config(options)

config = struct();
config.dataset_id = options.DatasetId;
config.max_samples = options.MaxSamples;
config.require_backend = options.RequireBackend;
config.cs_guess_m_s = options.CsGuessMPerS;
config.window_wavelengths = ...
    options.WindowWavelengths;
config.minimum_placements_per_axis = ...
    options.MinimumPlacementsPerAxis;
config.step_x = options.StepX;
config.step_z = options.StepZ;
config.store_req_curves = ...
    options.StoreReqCurves;
config.use_window_parfor = ...
    options.UseWindowParfor;
config.use_sample_parfor = ...
    options.UseSampleParfor;

config.use_directed_center_selection = ...
    options.UseDirectedCenterSelection;
config.purity_edges = options.PurityEdges;
config.diffusivity_edges = options.DiffusivityEdges;
config.sws_edges = options.SwsEdges;
config.frequency_edges = options.FrequencyEdges;
config.candidate_step_pixels = ...
    options.CandidateStepPixels;
config.maximum_centers_per_cell = ...
    options.MaximumCentersPerCell;
config.minimum_center_distance_fraction = ...
    options.MinimumCenterDistanceFraction;
config.minimum_valid_fraction = ...
    options.MinimumValidFraction;
config.center_selection_seed_offset = ...
    options.CenterSelectionSeedOffset;

config.theory_class_mapping = ...
    options.TheoryClassMapping;
config.target_definition = ...
    "center_pixel_truth";

end

function manifest = make_manifest(dataset)

manifest = struct();
manifest.schema_name = ...
    "reqml_campaign_dataset_manifest";
manifest.schema_version = "1.0";
manifest.dataset_id = dataset.dataset_id;
manifest.campaign_runs_csv = ...
    dataset.campaign_runs_csv;
manifest.sample_count = dataset.sample_count;
manifest.example_count = dataset.example_count;
manifest.previous_sample_count = ...
    dataset.previous_sample_count;
manifest.new_sample_count = ...
    dataset.new_sample_count;
manifest.reused_sample_count = ...
    dataset.reused_sample_count;
manifest.target_column = ...
    "q_target_from_center_truth";
manifest.target_definition = ...
    "center_pixel_truth";
manifest.feature_config = ...
    dataset.feature_config;
manifest.build_config = ...
    dataset.build_config;
manifest.created = string(datetime( ...
    "now", ...
    "Format", ...
    "yyyy-MM-dd HH:mm:ss Z"));

end

function output_directory = resolve_output_directory( ...
        requested_directory, dataset_id)

if strlength(requested_directory) > 0
    output_directory = requested_directory;
else
    root = fileparts(fileparts(fileparts( ...
        mfilename("fullpath"))));

    output_directory = fullfile( ...
        root, ...
        "outputs", ...
        "datasets", ...
        dataset_id);
end

output_directory = string(output_directory);

if isfolder(output_directory)
    error("reqml:DatasetOutputExists", ...
        "Dataset output directory already exists: %s", ...
        output_directory);
end

[created, message] = mkdir(output_directory);

if ~created
    error("reqml:DatasetOutputCreateFailed", ...
        "Could not create dataset output directory '%s': %s", ...
        output_directory, ...
        message);
end

end

function paths = save_dataset_outputs( ...
        dataset, output_directory)

examples = dataset.examples; %#ok<NASGU>
sample_summaries = dataset.sample_summaries;

examples_path = fullfile( ...
    output_directory, ...
    "examples.mat");

sample_summaries_path = fullfile( ...
    output_directory, ...
    "sample_summaries.csv");

samples_path = fullfile( ...
    output_directory, ...
    "samples.csv");

variable_registry_path = fullfile( ...
    output_directory, ...
    "variable_registry.csv");

dataset_summary_path = fullfile( ...
    output_directory, ...
    "dataset_summary.json");

manifest_path = fullfile( ...
    output_directory, ...
    "dataset_manifest.json");

save(examples_path, "examples", "-v7.3");

writetable( ...
    sample_summaries, ...
    sample_summaries_path, ...
    Delimiter=",");

writetable( ...
    dataset.inventory.samples, ...
    samples_path, ...
    Delimiter=",");

writetable( ...
    dataset.summary.variable_registry, ...
    variable_registry_path, ...
    Delimiter=",");

summary_for_json = ...
    make_summary_json_serializable( ...
        dataset.summary);

write_json( ...
    dataset_summary_path, ...
    summary_for_json);

write_json(manifest_path, dataset.manifest);

paths = struct();
paths.output_directory = output_directory;
paths.examples = string(examples_path);
paths.sample_summaries = ...
    string(sample_summaries_path);
paths.samples = string(samples_path);
paths.variable_registry = ...
    string(variable_registry_path);
paths.dataset_summary = ...
    string(dataset_summary_path);
paths.manifest = string(manifest_path);

end

function value = make_summary_json_serializable(summary)

value = summary;

table_fields = [
    "variable_registry"
    "role_counts"
    "source_counts"
    "feature_group_counts"
    "examples_per_run"
    "by_background_cs"
    "by_frequency"
    "by_direction_count"
    ];

for field_index = 1:numel(table_fields)
    field_name = table_fields(field_index);

    if isfield(value, field_name) && ...
            istable(value.(field_name))
        value.(field_name) = ...
            table2struct( ...
                value.(field_name));
    end
end

end

function write_json(path_value, value)

file_id = fopen(path_value, "w");

if file_id < 0
    error("reqml:DatasetManifestWriteFailed", ...
        "Could not create dataset manifest: %s", ...
        path_value);
end

cleanup = onCleanup(@() fclose(file_id));

fprintf(file_id, "%s", ...
    jsonencode(value, PrettyPrint=true));

clear cleanup

end
