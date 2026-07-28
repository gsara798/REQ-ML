function paths = save_grouped_condition_split(split, output_directory)
%SAVE_GROUPED_CONDITION_SPLIT Persist the exact grouped split assignment.

arguments
    split struct
    output_directory (1,1) string
end

output_directory = string(output_directory);

if ~isfolder(output_directory)
    mkdir(output_directory);
end

paths = struct();
paths.conditions_csv = fullfile( ...
    output_directory, ...
    "condition_split.csv");

paths.examples_mat = fullfile( ...
    output_directory, ...
    "example_partitions.mat");

paths.examples_csv = fullfile( ...
    output_directory, ...
    "example_partitions.csv");

paths.manifest_json = fullfile( ...
    output_directory, ...
    "split_manifest.json");

writetable(split.conditions, paths.conditions_csv);

example_partitions = table( ...
    (1:numel(split.partition))', ...
    split.condition_id(:), ...
    split.partition(:), ...
    'VariableNames', [ ...
        "row_index", ...
        "condition_id", ...
        "partition"]);

writetable(example_partitions, paths.examples_csv);
save(paths.examples_mat, "example_partitions", "-v7.3");

manifest = struct();
manifest.schema_name = split.schema_name;
manifest.schema_version = split.schema_version;
manifest.seed = split.seed;
manifest.group_columns = cellstr(split.group_columns);
manifest.run_column = char(split.run_column);

manifest.requested_fractions = struct( ...
    "train", split.train_fraction_requested, ...
    "validation", split.validation_fraction_requested, ...
    "test", split.test_fraction_requested);

manifest.summary = table2struct(split.summary);

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
