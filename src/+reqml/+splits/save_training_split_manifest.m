function paths = save_training_split_manifest( ...
    examples, split, folds, output_directory, options)
%SAVE_TRAINING_SPLIT_MANIFEST Persist frozen partitions and CV folds.
%
% The saved example-level manifest is keyed by example_id rather than row
% position so downstream training can verify and restore the exact split.

arguments
    examples table
    split (1,1) struct
    folds (1,1) struct
    output_directory (1,1) string

    options.DatasetPath (1,1) string = ""
end

required_variables = [
    "example_id"
    "campaign_condition_id"
    "campaign_run_id"
    ];

missing = setdiff( ...
    required_variables, ...
    string(examples.Properties.VariableNames));

if ~isempty(missing)
    error("reqml:MissingTrainingSplitVariable", ...
        "Examples are missing split variables: %s", ...
        strjoin(missing, ", "));
end

n = height(examples);

if numel(split.partition) ~= n || ...
        numel(folds.cv_fold) ~= n
    error("reqml:TrainingSplitSizeMismatch", ...
        "Split and fold assignments must match the dataset row count.");
end

example_id = string(examples.example_id);

if any(ismissing(example_id)) || ...
        any(strlength(example_id) == 0)
    error("reqml:InvalidTrainingExampleId", ...
        "Every example must have a nonempty example_id.");
end

if numel(unique(example_id)) ~= n
    error("reqml:DuplicateTrainingExampleId", ...
        "example_id must be unique before freezing a split.");
end

output_directory = string(output_directory);

if ~isfolder(output_directory)
    mkdir(output_directory);
end

assignment = table( ...
    example_id, ...
    string(examples.campaign_condition_id), ...
    string(examples.campaign_run_id), ...
    string(split.condition_id), ...
    string(split.partition), ...
    double(folds.cv_fold), ...
    VariableNames=[ ...
        "example_id", ...
        "campaign_condition_id", ...
        "campaign_run_id", ...
        "split_condition_id", ...
        "partition", ...
        "cv_fold"]);

assignment = sortrows(assignment, "example_id");

paths = struct();

paths.example_assignments_csv = fullfile( ...
    output_directory, ...
    "training_split_assignments.csv");

paths.example_assignments_mat = fullfile( ...
    output_directory, ...
    "training_split_assignments.mat");

paths.partition_summary_csv = fullfile( ...
    output_directory, ...
    "partition_summary.csv");

paths.fold_summary_csv = fullfile( ...
    output_directory, ...
    "training_fold_summary.csv");

paths.condition_assignments_csv = fullfile( ...
    output_directory, ...
    "condition_partitions.csv");

paths.fold_condition_assignments_csv = fullfile( ...
    output_directory, ...
    "training_fold_conditions.csv");

paths.manifest_json = fullfile( ...
    output_directory, ...
    "training_split_manifest.json");

writetable(assignment, paths.example_assignments_csv);
save(paths.example_assignments_mat, "assignment", "-v7.3");

writetable(split.summary, paths.partition_summary_csv);
writetable(folds.summary, paths.fold_summary_csv);
writetable(split.conditions, paths.condition_assignments_csv);
writetable( ...
    folds.conditions, ...
    paths.fold_condition_assignments_csv);

manifest = struct();

manifest.schema_name = ...
    "reqml_frozen_training_split";
manifest.schema_version = "1.0";

manifest.dataset_path = char(options.DatasetPath);
manifest.example_count = n;
manifest.unique_example_count = numel(unique(example_id));
manifest.unique_run_count = numel(unique( ...
    string(examples.campaign_run_id)));
manifest.unique_condition_count = numel(unique( ...
    string(examples.campaign_condition_id)));

manifest.group_columns = cellstr(split.group_columns);
manifest.run_column = char(split.run_column);

manifest.split_seed = split.seed;
manifest.fold_seed = folds.seed;
manifest.fold_count = folds.fold_count;

manifest.requested_fractions = struct( ...
    "train", split.train_fraction_requested, ...
    "validation", split.validation_fraction_requested, ...
    "test", split.test_fraction_requested);

manifest.partition_summary = ...
    table2struct(split.summary);

manifest.training_fold_summary = ...
    table2struct(folds.summary);

write_json(paths.manifest_json, manifest);

end

function write_json(path, value)

text = jsonencode(value, PrettyPrint=true);

file_id = fopen(path, "w");

if file_id < 0
    error("reqml:CannotWriteJson", ...
        "Could not open JSON file for writing: %s", path);
end

cleanup = onCleanup(@() fclose(file_id));
fprintf(file_id, "%s\n", text);

end
