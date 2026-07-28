function dataset = build_dataset_from_config(config_file)
%BUILD_DATASET_FROM_CONFIG Build a REQ-ML dataset from a JSON configuration.
%
% Usage:
%
%   dataset = reqml.datasets.build_dataset_from_config( ...
%       "configs/datasets/homogeneous_projected3d_control_v3.json");

arguments
    config_file {mustBeTextScalar}
end

repository_root = resolve_repository_root();

config_file = resolve_repository_path( ...
    repository_root, ...
    string(config_file));

if ~isfile(config_file)
    error("reqml:MissingDatasetBuildConfig", ...
        "Dataset build configuration not found: %s", ...
        config_file);
end

config = jsondecode(fileread(config_file));

validate_build_config(config);

dataset_id = string(config.dataset_id);

campaign_csv = resolve_repository_path( ...
    repository_root, ...
    string(config.campaign_runs_csv));

if ~isfile(campaign_csv)
    error("reqml:MissingCampaignRunsCsv", ...
        "Campaign runs CSV not found: %s", ...
        campaign_csv);
end

output_directory = fullfile( ...
    repository_root, ...
    "outputs", ...
    "datasets", ...
    dataset_id);

if isfolder(output_directory)
    error("reqml:DatasetOutputExists", ...
        "Dataset output already exists: %s", ...
        output_directory);
end

feature_config = ...
    reqml.config.default_feature_config( ...
        "M", double(config.req.M), ...
        "cs_guess", ...
            double(config.req.cs_guess_m_s), ...
        "gamma_win", ...
            double(config.req.gamma), ...
        "pad_factor", ...
            double(config.req.pad_factor), ...
        "smooth_sigma_2d", ...
            double(config.req.smooth_sigma_2d));

theory_mapping = struct.empty;

if isfield(config, "theory_class_mapping")
    theory_mapping = config.theory_class_mapping;
end

execution = resolve_execution_config(config);

pool = gcp("nocreate");

if execution.start_parallel_pool && isempty(pool)
    pool = parpool("threads");
end

if isempty(pool)
    fprintf("Parallel workers: disabled\n");
else
    fprintf("Parallel workers: %d\n", pool.NumWorkers);
end

fprintf("Dataset config  : %s\n", config_file);
fprintf("Dataset ID      : %s\n", dataset_id);
fprintf("Campaign CSV    : %s\n", campaign_csv);

build_timer = tic;

dataset = ...
    reqml.datasets.build_dataset_from_campaign( ...
        campaign_csv, ...
        feature_config, ...
        DatasetId=dataset_id, ...
        MaxSamples=get_numeric_field( ...
            config, "max_samples", Inf), ...
        RequireBackend= ...
            string(config.require_backend), ...
        CsGuessMPerS= ...
            double(config.req.cs_guess_m_s), ...
        WindowWavelengths= ...
            double(config.req.M), ...
        MinimumPlacementsPerAxis= ...
            double(config.extraction. ...
                minimum_placements_per_axis), ...
        StepX= ...
            double(config.extraction.step_x), ...
        StepZ= ...
            double(config.extraction.step_z), ...
        StoreReqCurves= ...
            logical(config.extraction. ...
                store_req_curves), ...
        UseWindowParfor= ...
            logical(config.extraction. ...
                use_window_parfor), ...
        TheoryClassMapping=theory_mapping, ...
        OutputDirectory=output_directory, ...
        SaveOutputs=execution.save_outputs);

elapsed_s = toc(build_timer);

validate_built_dataset( ...
    dataset, ...
    theory_mapping, ...
    execution.save_outputs);

fprintf("\n============================================\n");
fprintf("REQ-ML dataset build completed\n");
fprintf("============================================\n");
fprintf("Dataset ID : %s\n", dataset.dataset_id);
fprintf("Samples    : %d\n", dataset.sample_count);
fprintf("Examples   : %d\n", dataset.example_count);
fprintf("Elapsed    : %.1f s (%.2f min)\n", ...
    elapsed_s, elapsed_s / 60);
if execution.save_outputs
    fprintf("Output     : %s\n", output_directory);
else
    fprintf("Output     : disabled\n");
end

fprintf("Target q   : [%.4f, %.4f]\n", ...
    dataset.summary.target.minimum, ...
    dataset.summary.target.maximum);
fprintf("Unregistered variables: %d\n", ...
    numel(dataset.summary.unregistered_variables));

end

function repository_root = resolve_repository_root()

this_file = mfilename("fullpath");

repository_root = fileparts(fileparts(fileparts( ...
    fileparts(this_file))));

end

function validate_build_config(config)

required_top_level = [
    "dataset_id"
    "campaign_runs_csv"
    "require_backend"
    "req"
    "extraction"
    ];

for name = required_top_level.'
    if ~isfield(config, name)
        error("reqml:InvalidDatasetBuildConfig", ...
            "Dataset build configuration is missing '%s'.", ...
            name);
    end
end

required_req = [
    "M"
    "cs_guess_m_s"
    "gamma"
    "pad_factor"
    "smooth_sigma_2d"
    ];

for name = required_req.'
    if ~isfield(config.req, name)
        error("reqml:InvalidDatasetBuildConfig", ...
            "REQ configuration is missing '%s'.", ...
            name);
    end
end

required_extraction = [
    "minimum_placements_per_axis"
    "step_x"
    "step_z"
    "store_req_curves"
    "use_window_parfor"
    ];

for name = required_extraction.'
    if ~isfield(config.extraction, name)
        error("reqml:InvalidDatasetBuildConfig", ...
            "Extraction configuration is missing '%s'.", ...
            name);
    end
end

end

function validate_built_dataset( ...
    dataset, theory_mapping, save_outputs)

assert(dataset.sample_count > 0);
assert(dataset.example_count > 0);
assert(all(dataset.examples.target_valid));

assert(numel(unique(dataset.examples.example_id)) == ...
    dataset.example_count);

assert(isempty(dataset.summary.unregistered_variables));

if ~isempty(theory_mapping)
    required_theory_columns = [
        "theory_field_class"
        "q_theory_single_wave_discrete"
        "q_theory_diffuse3d_discrete"
        "q_theory_discrete"
        "q_theory_valid"
        ];

    assert(all(ismember( ...
        required_theory_columns, ...
        string(dataset.examples.Properties.VariableNames))));

    assert(all(dataset.examples.q_theory_valid));

    registry = dataset.summary.variable_registry;

    for variable_name = required_theory_columns.'
        row = registry( ...
            registry.variable_name == variable_name, ...
            :);

        assert(height(row) == 1);
        assert(~row.trainable);
        assert(row.role == "diagnostic");
        assert(row.group == "theory_baseline");
    end
end

if save_outputs
    required_artifacts = [
        dataset.paths.examples
        dataset.paths.samples
        dataset.paths.sample_summaries
        dataset.paths.variable_registry
        dataset.paths.dataset_summary
        dataset.paths.manifest
        ];

    assert(all(isfile(required_artifacts)));
else
    assert(isempty(fieldnames(dataset.paths)));
end

end

function execution = resolve_execution_config(config)

execution = struct();
execution.start_parallel_pool = true;
execution.save_outputs = true;

if ~isfield(config, "execution")
    return
end

if isfield(config.execution, "start_parallel_pool")
    execution.start_parallel_pool = ...
        logical(config.execution.start_parallel_pool);
end

if isfield(config.execution, "save_outputs")
    execution.save_outputs = ...
        logical(config.execution.save_outputs);
end

if ~isscalar(execution.start_parallel_pool) || ...
        ~isscalar(execution.save_outputs)
    error("reqml:InvalidDatasetBuildConfig", ...
        "Execution options must be scalar logical values.");
end

end

function path = resolve_repository_path( ...
    repository_root, requested_path)

requested_path = string(requested_path);

if is_absolute_path(requested_path)
    path = requested_path;
else
    path = fullfile(repository_root, requested_path);
end

end

function tf = is_absolute_path(path)

path = char(path);

if ispc
    tf = ~isempty(regexp(path, ...
        "^[A-Za-z]:[\\/]", ...
        "once"));
else
    tf = startsWith(path, "/");
end

end

function value = get_numeric_field( ...
    config, name, default_value)

if isfield(config, name)
    value = double(config.(name));
else
    value = default_value;
end

end
