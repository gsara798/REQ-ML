function split = make_grouped_condition_split(examples, options)
%MAKE_GROUPED_CONDITION_SPLIT Deterministic grouped train/validation/test split.
%
% Conditions are defined by options.GroupColumns. Every example sharing the
% same values in those columns remains in one partition.
%
% The split is deterministic for a fixed dataset, grouping definition, seed,
% and partition fractions.

arguments
    examples table

    options.GroupColumns (1,:) string = [ ...
        "campaign_background_cs_m_s", ...
        "campaign_frequency_hz", ...
        "campaign_direction_count"]

    options.RunColumn (1,1) string = "campaign_run_id"
    options.Seed (1,1) double = 4101
    options.TrainFraction (1,1) double = 0.70
    options.ValidationFraction (1,1) double = 0.15
    options.TestFraction (1,1) double = 0.15
end

group_columns = string(options.GroupColumns(:)');
run_column = string(options.RunColumn);

if isempty(group_columns)
    error("reqml:EmptySplitGroupColumns", ...
        "At least one grouping column is required.");
end

available = string(examples.Properties.VariableNames);
required = unique([run_column, group_columns], "stable");
missing = setdiff(required, available);

if ~isempty(missing)
    error("reqml:MissingSplitVariable", ...
        "Dataset is missing split variables: %s", ...
        strjoin(missing, ", "));
end

fractions = [
    options.TrainFraction
    options.ValidationFraction
    options.TestFraction
    ];

if any(~isfinite(fractions)) || ...
        any(fractions <= 0) || ...
        abs(sum(fractions) - 1) > 1e-12
    error("reqml:InvalidSplitFractions", ...
        "Train, validation, and test fractions must be positive and sum to 1.");
end

group_table = examples(:, cellstr(group_columns));

[condition_group, unique_conditions] = findgroups(group_table);
condition_count = height(unique_conditions);

if condition_count < 3
    error("reqml:InsufficientSplitConditions", ...
        "At least three unique physical conditions are required.");
end

unique_condition_id = make_condition_ids(unique_conditions, group_columns);

if numel(unique(unique_condition_id)) ~= condition_count
    error("reqml:NonUniqueConditionIdentifier", ...
        "Condition identifier generation produced duplicate identifiers.");
end

condition_id = unique_condition_id(condition_group);

previous_rng = rng;
cleanup = onCleanup(@() rng(previous_rng));

rng(options.Seed, "twister");
order = randperm(condition_count);

train_count = floor(options.TrainFraction * condition_count);
validation_count = floor(options.ValidationFraction * condition_count);
test_count = condition_count - train_count - validation_count;

if min([train_count, validation_count, test_count]) < 1
    error("reqml:EmptySplitPartition", ...
        "Resolved split contains an empty partition.");
end

condition_partition = strings(condition_count, 1);

condition_partition(order(1:train_count)) = "train";

validation_start = train_count + 1;
validation_end = train_count + validation_count;

condition_partition(order(validation_start:validation_end)) = ...
    "validation";

condition_partition(order(validation_end + 1:end)) = "test";

partition = condition_partition(condition_group);

split = struct();
split.schema_name = "reqml_grouped_condition_split";
split.schema_version = "2.0";

split.seed = options.Seed;
split.group_columns = group_columns;
split.run_column = run_column;

split.train_fraction_requested = options.TrainFraction;
split.validation_fraction_requested = options.ValidationFraction;
split.test_fraction_requested = options.TestFraction;

split.condition_id = condition_id;
split.partition = partition;

split.train_mask = partition == "train";
split.validation_mask = partition == "validation";
split.test_mask = partition == "test";

condition_table = unique_conditions;
condition_table.condition_id = unique_condition_id;
condition_table.partition = condition_partition;

sort_columns = ["partition", group_columns];
split.conditions = sortrows(condition_table, cellstr(sort_columns));

split.summary = summarize_split( ...
    examples, ...
    split, ...
    run_column);

clear cleanup

end

function condition_id = make_condition_ids(T, group_columns)

n = height(T);
condition_id = strings(n, 1);

for row = 1:n
    parts = strings(1, numel(group_columns));

    for column_index = 1:numel(group_columns)
        name = group_columns(column_index);
        value = T.(char(name))(row, :);

        parts(column_index) = ...
            name + "=" + value_to_stable_string(value);
    end

    condition_id(row) = strjoin(parts, "__");
end

end

function value_string = value_to_stable_string(value)

if isnumeric(value)
    value = double(value);

    if isscalar(value)
        if isnan(value)
            value_string = "NaN";
        elseif isinf(value)
            value_string = string(value);
        else
            value_string = compose("%.17g", value);
        end
    else
        value_string = strjoin(compose("%.17g", value(:)'), ",");
    end

elseif islogical(value)
    value_string = strjoin(string(value(:)'), ",");

elseif isstring(value)
    value_string = strjoin(value(:)', ",");

elseif ischar(value)
    value_string = string(value);

elseif iscategorical(value)
    value_string = strjoin(string(value(:)'), ",");

elseif isdatetime(value) || isduration(value)
    value_string = strjoin(string(value(:)'), ",");

elseif iscell(value) && isscalar(value)
    value_string = value_to_stable_string(value{1});

else
    error("reqml:UnsupportedSplitVariableType", ...
        "Unsupported grouping variable type: %s.", class(value));
end

value_string = replace(value_string, "__", "_");
value_string = replace(value_string, "=", "-");

end

function summary = summarize_split(examples, split, run_column)

partitions = ["train"; "validation"; "test"];

condition_count = zeros(3, 1);
run_count = zeros(3, 1);
example_count = zeros(3, 1);

for index = 1:3
    name = partitions(index);
    mask = split.partition == name;

    condition_count(index) = ...
        numel(unique(split.condition_id(mask)));

    run_count(index) = ...
        numel(unique(examples.(char(run_column))(mask)));

    example_count(index) = nnz(mask);
end

summary = table( ...
    partitions, ...
    condition_count, ...
    run_count, ...
    example_count, ...
    'VariableNames', [ ...
        "partition", ...
        "condition_count", ...
        "run_count", ...
        "example_count"]);

end
