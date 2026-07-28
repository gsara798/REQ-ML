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

model_names = string(config.models(:));
supported = ["fixed_q", "q_theory_discrete"];

unsupported = setdiff(model_names, supported);

if ~isempty(unsupported)
    error("reqml:UnsupportedBaselineModel", ...
        "This baseline milestone does not yet support: %s", ...
        strjoin(unsupported, ", "));
end

prediction_tables = cell(numel(model_names), 1);
metric_tables = cell(numel(model_names), 1);
model_metadata = cell(numel(model_names), 1);

for index = 1:numel(model_names)
    model_name = model_names(index);

    switch model_name
        case "fixed_q"
            baseline = reqml.baselines.predict_fixed_q( ...
                target, ...
                split.train_mask, ...
                Estimator=string(config.fixed_q.estimator), ...
                ClipRange=double(config.prediction_clip_range));

        case "q_theory_discrete"
            baseline = reqml.baselines.predict_discrete_theory_q( ...
                double(examples.q_theory_discrete), ...
                logical(examples.q_theory_valid), ...
                ClipRange=double(config.prediction_clip_range));

        otherwise
            error("reqml:UnsupportedBaselineModel", ...
                "Unsupported model: %s", model_name);
    end

    predictions = make_prediction_table( ...
        examples, ...
        target, ...
        baseline.q_pred, ...
        split, ...
        model_name, ...
        string(config.split.run_column));

    metrics = reqml.evaluation.evaluate_q_predictions( ...
        target, ...
        baseline.q_pred, ...
        split.partition, ...
        model_name);

    prediction_tables{index} = predictions;
    metric_tables{index} = metrics;
    model_metadata{index} = baseline;
end

predictions = vertcat(prediction_tables{:});
metrics = vertcat(metric_tables{:});

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

    paths.metrics_csv = fullfile( ...
        output_directory, ...
        "metrics.csv");

    paths.models_mat = fullfile( ...
        output_directory, ...
        "baseline_models.mat");

    paths.manifest_json = fullfile( ...
        output_directory, ...
        "baseline_manifest.json");

    writetable(predictions, paths.predictions_csv);
    writetable(metrics, paths.metrics_csv);

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
        metrics, ...
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
result.metrics = metrics;
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

disp(metrics);

end

function predictions = make_prediction_table( ...
    examples, ...
    q_true, ...
    q_pred, ...
    split, ...
    baseline_id, ...
    run_column)

n = height(examples);

predictions = table();
predictions.row_index = (1:n)';
predictions.baseline_id = repmat(baseline_id, n, 1);
predictions.partition = split.partition;
predictions.condition_id = split.condition_id;
predictions.run_id = string(examples.(char(run_column)));
predictions.q_true = q_true;
predictions.q_pred = q_pred;
predictions.q_residual = q_pred - q_true;
predictions.q_abs_error = abs(predictions.q_residual);

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
    "fixed_q"
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

end

function manifest = build_manifest( ...
    config, ...
    config_path, ...
    examples_path, ...
    output_directory, ...
    split, ...
    metrics, ...
    context_predictors, ...
    full_predictors)

manifest = struct();
manifest.schema_name = "reqml_baseline_run_manifest";
manifest.schema_version = "1.0";

manifest.baseline_id = config.baseline_id;
manifest.config_path = char(config_path);
manifest.examples_path = char(examples_path);
manifest.output_directory = char(output_directory);

manifest.models = cellstr(string(config.models(:)));
manifest.split_schema_name = split.schema_name;
manifest.split_schema_version = split.schema_version;
manifest.split_seed = split.seed;
manifest.split_group_columns = cellstr(split.group_columns);
manifest.split_run_column = char(split.run_column);

manifest.context_predictors = cellstr(context_predictors);
manifest.full_predictors = cellstr(full_predictors);

manifest.metrics = table2struct(metrics);

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
