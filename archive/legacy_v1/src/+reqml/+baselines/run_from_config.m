function result = run_from_config(config_file)
%RUN_FROM_CONFIG Run reproducible non-ML baselines from a JSON config.

arguments
    config_file (1,1) string
end

repository_root = resolve_repository_root();
config_path = resolve_path(repository_root, config_file);

if ~isfile(config_path)
    error("reqml:BaselineConfigNotFound", ...
        "Baseline config not found: %s", config_path);
end

config = jsondecode(fileread(config_path));
validate_config(config);

examples_path = resolve_path( ...
    repository_root, ...
    string(config.dataset.examples_mat));

dataset_directory = fileparts(examples_path);
registry_path = fullfile(dataset_directory, "variable_registry.csv");

if ~isfile(examples_path)
    error("reqml:BaselineDatasetNotFound", ...
        "Dataset examples file not found: %s", examples_path);
end

if ~isfile(registry_path)
    error("reqml:VariableRegistryNotFound", ...
        "Variable registry not found: %s", registry_path);
end

loaded = load(examples_path, "examples");

if ~isfield(loaded, "examples") || ~istable(loaded.examples)
    error("reqml:InvalidExamplesArtifact", ...
        "Examples MAT file must contain a table named examples.");
end

examples = loaded.examples;
registry = readtable(registry_path, TextType="string");

target_column = string(config.dataset.target_column);
available = string(examples.Properties.VariableNames);

required_example_columns = [
    target_column
    "q_theory_discrete"
    "q_theory_valid"
    ];

missing = setdiff(required_example_columns, available);

if ~isempty(missing)
    error("reqml:MissingBaselineDatasetVariable", ...
        "Dataset is missing baseline variables: %s", ...
        strjoin(missing, ", "));
end

split = reqml.splits.make_grouped_condition_split( ...
    examples, ...
    GroupColumns=string(config.split.group_columns), ...
    RunColumn=string(config.split.run_column), ...
    Seed=config.split.seed, ...
    TrainFraction=config.split.train_fraction, ...
    ValidationFraction=config.split.validation_fraction, ...
    TestFraction=config.split.test_fraction);

integrity = reqml.splits.validate_split_integrity(examples, split);

if islogical(integrity)
    split_valid = integrity;
elseif isstruct(integrity) && isfield(integrity, "valid")
    split_valid = logical(integrity.valid);
elseif isstruct(integrity) && isfield(integrity, "is_valid")
    split_valid = logical(integrity.is_valid);
else
    split_valid = true;
end

if ~split_valid
    error("reqml:InvalidGroupedSplit", ...
        "Grouped split failed integrity validation.");
end

% Validate registry-based predictor selection now, even though ML models are
% introduced in the next milestone.
context_predictors = ...
    reqml.training.select_predictors_from_registry( ...
        registry, ...
        "context_only");

full_predictors = ...
    reqml.training.select_predictors_from_registry( ...
        registry, ...
        "full");

target = double(examples.(char(target_column)));

model_specs = config.models;
model_count = numel(model_specs);
model_names = strings(model_count, 1);

prediction_tables = cell(model_count, 1);
q_metric_tables = cell(model_count, 1);
sws_metric_tables = cell(model_count, 1);
model_metadata = cell(model_count, 1);

for index = 1:model_count
    model_spec = get_model_spec(model_specs, index);

    if ~isfield(model_spec, "id") || ~isfield(model_spec, "type")
        error("reqml:InvalidModelSpecification", ...
            "Every model requires id and type.");
    end

    model_name = string(model_spec.id);
    model_type = lower(string(model_spec.type));
    model_names(index) = model_name;

    switch model_type
        case "fixed_q"
            baseline = reqml.baselines.predict_fixed_q( ...
                target, ...
                split.train_mask, ...
                Estimator=string(model_spec.estimator), ...
                ClipRange=double(config.prediction_clip_range));

            q_pred = baseline.q_pred;
            model_metadata{index} = baseline;

        case "q_theory_discrete"
            baseline = reqml.baselines.predict_discrete_theory_q( ...
                double(examples.q_theory_discrete), ...
                logical(examples.q_theory_valid), ...
                ClipRange=double(config.prediction_clip_range));

            q_pred = baseline.q_pred;
            model_metadata{index} = baseline;

        case {"ridge", "bagged_trees"}
            selection_mode = string(model_spec.predictor_selection);

            predictor_names = ...
                reqml.training.select_predictors_from_registry( ...
                    registry, selection_mode);

            [X, predictor_metadata] = ...
                reqml.training.build_numeric_predictor_matrix( ...
                    examples, predictor_names);

            fitted_model = reqml.training.fit_regression_model( ...
                X, target, split.train_mask, model_spec);

            fitted_model.predictor_names = predictor_names;
            fitted_model.predictor_metadata = predictor_metadata;

            q_pred = reqml.training.predict_regression_model( ...
                fitted_model, X, ...
                ClipRange=double(config.prediction_clip_range));

            model_metadata{index} = fitted_model;

        otherwise
            error("reqml:UnsupportedBaselineModel", ...
                "Unsupported model type: %s", model_type);
    end

    sws_predictions = ...
        reqml.evaluation.convert_q_predictions_to_sws( ...
            examples, ...
            q_pred);

    q_predictions = make_prediction_table( ...
        examples, ...
        target, ...
        q_pred, ...
        split, ...
        model_name, ...
        string(config.split.run_column));

    sws_output_columns = [
        "k_pred_rad_m"
        "cs_true_m_s"
        "cs_pred_m_s"
        "cs_error_m_s"
        "cs_error_percent"
        "cs_absolute_error_percent"
        "sws_valid"
        ];

    predictions = [ ...
        q_predictions, ...
        sws_predictions(:, sws_output_columns)];

    q_metrics = reqml.evaluation.evaluate_q_predictions( ...
        target, ...
        q_pred, ...
        split.partition, ...
        model_name);

    sws_metrics = reqml.evaluation.evaluate_sws_predictions( ...
        sws_predictions, ...
        split.partition, ...
        model_name);

    prediction_tables{index} = predictions;
    q_metric_tables{index} = q_metrics;
    sws_metric_tables{index} = sws_metrics;
end

predictions = vertcat(prediction_tables{:});
q_metrics = vertcat(q_metric_tables{:});
sws_metrics = vertcat(sws_metric_tables{:});

execution = resolve_execution_config(config);

output_directory = resolve_path( ...
    repository_root, ...
    fullfile("outputs", "baselines", string(config.baseline_id)));

paths = struct();

if execution.save_outputs
    if isfolder(output_directory)
        if execution.overwrite
            rmdir(output_directory, "s");
        else
            error("reqml:BaselineOutputExists", ...
                "Baseline output already exists: %s", ...
                output_directory);
        end
    end

    mkdir(output_directory);

    paths.split = reqml.splits.save_grouped_condition_split( ...
        split, ...
        fullfile(output_directory, "split"));

    paths.predictions_csv = fullfile( ...
        output_directory, ...
        "predictions.csv");

    paths.q_metrics_csv = fullfile( ...
        output_directory, ...
        "q_metrics.csv");

    paths.sws_metrics_csv = fullfile( ...
        output_directory, ...
        "sws_metrics.csv");

    paths.models_mat = fullfile( ...
        output_directory, ...
        "baseline_models.mat");

    paths.manifest_json = fullfile( ...
        output_directory, ...
        "baseline_manifest.json");

    writetable(predictions, paths.predictions_csv);
    writetable(q_metrics, paths.q_metrics_csv);
    writetable(sws_metrics, paths.sws_metrics_csv);

    save( ...
        paths.models_mat, ...
        "model_metadata", ...
        "context_predictors", ...
        "full_predictors", ...
        "-v7.3");

    manifest = build_manifest( ...
        config, ...
        config_path, ...
        examples_path, ...
        output_directory, ...
        split, ...
        q_metrics, ...
        sws_metrics, ...
        context_predictors, ...
        full_predictors);

    write_json(paths.manifest_json, manifest);
end

result = struct();
result.config = config;
result.examples = examples;
result.registry = registry;
result.split = split;
result.predictions = predictions;
result.q_metrics = q_metrics;
result.sws_metrics = sws_metrics;

% Temporary compatibility alias. New code should use q_metrics explicitly.
result.metrics = q_metrics;

result.model_metadata = model_metadata;
result.context_predictors = context_predictors;
result.full_predictors = full_predictors;
result.output_directory = output_directory;
result.paths = paths;

fprintf("\n============================================\n");
fprintf("REQ-ML baseline evaluation completed\n");
fprintf("============================================\n");
fprintf("Baseline ID : %s\n", string(config.baseline_id));
fprintf("Examples    : %d\n", height(examples));
fprintf("Conditions  : %d\n", height(split.conditions));
fprintf("Models      : %s\n", strjoin(model_names, ", "));
fprintf("Context vars: %d\n", numel(context_predictors));
fprintf("Full vars   : %d\n", numel(full_predictors));

if execution.save_outputs
    fprintf("Output      : %s\n", output_directory);
else
    fprintf("Output      : disabled\n");
end

fprintf("\nQuantile metrics:\n");
disp(q_metrics);

fprintf("\nSWS metrics:\n");
disp(sws_metrics);

end

function predictions = make_prediction_table( ...
    examples, ...
    q_true, ...
    q_pred, ...
    split, ...
    model_id, ...
    run_column)

n = height(examples);

if numel(q_true) ~= n || ...
        numel(q_pred) ~= n || ...
        numel(split.partition) ~= n
    error("reqml:PredictionSizeMismatch", ...
        "Prediction inputs must contain one row per example.");
end

model_id_column = repmat(string(model_id), n, 1);
partition = string(split.partition(:));

predictions = table( ...
    model_id_column, ...
    partition, ...
    'VariableNames', ["model_id", "partition"]);

metadata_columns = [
    "dataset_id"
    "sample_id"
    "example_id"
    "campaign_ordinal"
    "campaign_run_id"
    "campaign_hash_sha256"
    "campaign_backend"
    "campaign_scenario"
    "campaign_seed"
    "campaign_frequency_hz"
    "campaign_background_cs_m_s"
    "campaign_direction_count"
    "patch_idx"
    "cx"
    "cz"
    "x_center_m"
    "z_center_m"
    ];

available = string(examples.Properties.VariableNames);
metadata_columns = metadata_columns( ...
    ismember(metadata_columns, available));

if ~ismember(run_column, metadata_columns)
    if ~ismember(run_column, available)
        error("reqml:MissingRunColumn", ...
            "Examples table is missing run column '%s'.", ...
            run_column);
    end

    metadata_columns = [metadata_columns; run_column];
end

metadata = examples(:, cellstr(metadata_columns));
predictions = [predictions, metadata];

predictions.q_true = double(q_true(:));
predictions.q_pred = double(q_pred(:));
predictions.q_residual = predictions.q_pred - predictions.q_true;
predictions.q_abs_error = abs(predictions.q_residual);

end

function normalized = normalize_model_specs(models)

normalized = cell(numel(models), 1);

for index = 1:numel(models)
    normalized{index} = get_model_spec(models, index);
end

end

function model_spec = get_model_spec(models, index)

if iscell(models)
    model_spec = models{index};
else
    model_spec = models(index);
end

if ~isstruct(model_spec) || ~isscalar(model_spec)
    error("reqml:InvalidModelSpecification", ...
        "Model specification %d must be a scalar struct.", index);
end

end

function execution = resolve_execution_config(config)

execution = struct();
execution.save_outputs = true;
execution.overwrite = false;

if isfield(config, "execution")
    if isfield(config.execution, "save_outputs")
        execution.save_outputs = logical(config.execution.save_outputs);
    end

    if isfield(config.execution, "overwrite")
        execution.overwrite = logical(config.execution.overwrite);
    end
end

end

function validate_config(config)

required = [
    "schema_name"
    "schema_version"
    "baseline_id"
    "dataset"
    "split"
    "models"
    "prediction_clip_range"
    ];

missing = required(~isfield(config, cellstr(required)));

if ~isempty(missing)
    error("reqml:InvalidBaselineConfig", ...
        "Baseline config is missing fields: %s", ...
        strjoin(missing, ", "));
end

if string(config.schema_name) ~= "reqml_baseline_config"
    error("reqml:InvalidBaselineConfigSchema", ...
        "Unexpected baseline config schema: %s", ...
        string(config.schema_name));
end

if isempty(config.models) || ...
        ~(isstruct(config.models) || iscell(config.models))
    error("reqml:InvalidModelConfiguration", ...
        "Baseline config models must be a non-empty struct array or cell array.");
end

for index = 1:numel(config.models)
    model_spec = get_model_spec(config.models, index);

    if ~isfield(model_spec, "id") || ~isfield(model_spec, "type")
        error("reqml:InvalidModelSpecification", ...
            "Every model specification requires id and type.");
    end
end

end

function manifest = build_manifest( ...
    config, ...
    config_path, ...
    examples_path, ...
    output_directory, ...
    split, ...
    q_metrics, ...
    sws_metrics, ...
    context_predictors, ...
    full_predictors)

manifest = struct();
manifest.schema_name = "reqml_baseline_run_manifest";
manifest.schema_version = "1.0";

manifest.baseline_id = config.baseline_id;
manifest.config_path = char(config_path);
manifest.examples_path = char(examples_path);
manifest.output_directory = char(output_directory);

manifest.models = normalize_model_specs(config.models);
manifest.split_schema_name = split.schema_name;
manifest.split_schema_version = split.schema_version;
manifest.split_seed = split.seed;
manifest.split_group_columns = cellstr(split.group_columns);
manifest.split_run_column = char(split.run_column);

manifest.context_predictors = cellstr(context_predictors);
manifest.full_predictors = cellstr(full_predictors);

manifest.q_metrics = table2struct(q_metrics);
manifest.sws_metrics = table2struct(sws_metrics);

end

function root = resolve_repository_root()

path = mfilename("fullpath");

for index = 1:4
    path = fileparts(path);
end

root = string(path);

end

function path = resolve_path(repository_root, requested_path)

requested_path = string(requested_path);

if is_absolute_path(requested_path)
    path = requested_path;
else
    path = fullfile(repository_root, requested_path);
end

path = string(path);

end

function value = is_absolute_path(path)

path = char(path);

if ispc
    value = ~isempty(regexp(path, "^[A-Za-z]:[\\/]", "once")) || ...
        startsWith(path, "\\");
else
    value = startsWith(path, "/");
end

end

function write_json(path, value)

text = jsonencode(value, PrettyPrint=true);

file_id = fopen(path, "w");

if file_id < 0
    error("reqml:CannotWriteJson", ...
        "Could not write JSON file: %s", path);
end

cleanup = onCleanup(@() fclose(file_id));
fprintf(file_id, "%s\n", text);

end
