function result = mergeCampaignRunCsvs(csv_files, options)
%MERGECAMPAIGNRUNCSVS Merge campaign run tables without duplicating runs.
%
% Rows are deduplicated using run_id. Repeated rows must be identical;
% conflicting metadata for the same run_id is rejected.

arguments
    csv_files (:,1) string
    options.OutputFile {mustBeTextScalar} = ""
end

validate_files(csv_files);

tables = cell(numel(csv_files), 1);
reference_names = strings(0, 1);

for index = 1:numel(csv_files)
    current = readtable( ...
        csv_files(index), ...
        Delimiter=",", ...
        TextType="string");

    names = string(current.Properties.VariableNames);

    if index == 1
        reference_names = names;
    elseif ~isequal(names, reference_names)
        error("reqml:CampaignRunCsvSchemaMismatch", ...
            "All campaign CSV files must have identical columns.");
    end

    tables{index} = current;
end

combined = vertcat(tables{:});

if isempty(combined)
    error("reqml:EmptyCampaignRunCsvMerge", ...
        "The combined campaign table contains no rows.");
end

if ~ismember("run_id", ...
        string(combined.Properties.VariableNames))

    error("reqml:MissingCampaignRunId", ...
        "Campaign CSV files must contain run_id.");
end

run_ids = string(combined.run_id);

if any(ismissing(run_ids) | strlength(run_ids) == 0)
    error("reqml:InvalidCampaignRunId", ...
        "Every campaign row must contain a non-empty run_id.");
end

[unique_ids, first_indices, group_indices] = ...
    unique(run_ids, "stable");

keep = false(height(combined), 1);
keep(first_indices) = true;

for group_index = 1:numel(unique_ids)
    indices = find(group_indices == group_index);

    if numel(indices) <= 1
        continue
    end

    reference = combined(indices(1), :);

    for duplicate_index = indices(2:end).'
        candidate = combined(duplicate_index, :);

        if ~isequaln(reference, candidate)
            error("reqml:ConflictingCampaignRunDuplicate", ...
                "Multiple rows use run_id '%s' but contain different metadata.", ...
                unique_ids(group_index));
        end
    end
end

merged = combined(keep, :);

output_file = string(options.OutputFile);

if strlength(output_file) > 0
    output_directory = string(fileparts(output_file));

    if strlength(output_directory) > 0 && ...
            ~isfolder(output_directory)

        [created, message] = mkdir(output_directory);

        if ~created
            error("reqml:CampaignRunMergeDirectoryCreateFailed", ...
                "Could not create directory '%s': %s", ...
                output_directory, message);
        end
    end

    writetable( ...
        merged, ...
        output_file, ...
        FileType="text", ...
        Delimiter=",");
end

result = struct();

result.schema_name = ...
    "reqml_campaign_run_csv_merge";

result.schema_version = "1.0";

result.input_file_count = numel(csv_files);
result.input_row_count = height(combined);
result.output_row_count = height(merged);
result.duplicate_row_count = ...
    height(combined) - height(merged);

result.run_count = ...
    numel(unique(string(merged.run_id)));

if ismember("condition_id", ...
        string(merged.Properties.VariableNames))

    condition_ids = string(merged.condition_id);
    condition_ids = condition_ids( ...
        ~ismissing(condition_ids) & ...
        strlength(condition_ids) > 0);

    result.condition_count = ...
        numel(unique(condition_ids));
else
    result.condition_count = NaN;
end

result.table = merged;
result.output_file = output_file;

end


function validate_files(files)

if isempty(files)
    error("reqml:EmptyCampaignRunCsvList", ...
        "At least one campaign CSV file is required.");
end

for index = 1:numel(files)
    if strlength(files(index)) == 0
        error("reqml:InvalidCampaignRunCsvPath", ...
            "Campaign CSV paths must be non-empty.");
    end

    if ~isfile(files(index))
        error("reqml:CampaignRunCsvNotFound", ...
            "Campaign CSV file was not found: %s", ...
            files(index));
    end
end

end
