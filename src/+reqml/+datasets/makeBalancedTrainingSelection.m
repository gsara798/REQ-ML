function result = makeBalancedTrainingSelection( ...
    examples, options)
%MAKEBALANCEDTRAININGSELECTION Build a balanced, reproducible training view.
%
% All examples are retained. The function adds:
%
%   selected_for_training
%   training_weight
%
% Balancing hierarchy:
%
%   equal total weight per coverage cell
%       -> equal total weight per condition within each cell
%       -> equal weight per selected patch within each condition
%
% This prevents cells or simulations with many patches from dominating
% training while preserving the complete raw dataset.

arguments
    examples table

    options.PurityEdges (1,:) double
    options.NominalAngularCoverageEdges (1,:) double
    options.SwsEdges (1,:) double
    options.FrequencyEdges (1,:) double

    options.MaximumExamplesPerCell (1,1) double = Inf

    options.MaximumExamplesPerConditionPerCell ...
        (1,1) double = Inf

    options.RandomSeed (1,1) double = 1

    options.OutputDirectory {mustBeTextScalar} = ""
    options.SaveOutputs (1,1) logical = false
end

validate_limits(options);

assigned = reqml.coverage.assignCoverageBins( ...
    examples, ...
    FieldCoverageMode="nominal", ...
    PurityEdges=options.PurityEdges, ...
    DiffusivityEdges= ...
        options.NominalAngularCoverageEdges, ...
    SwsEdges=options.SwsEdges, ...
    FrequencyEdges=options.FrequencyEdges);

validate_required_variables(assigned);

row_count = height(assigned);

selected = false(row_count, 1);
weights = zeros(row_count, 1);

valid = logical(assigned.coverage_valid);

cell_keys = make_cell_keys(assigned);
condition_ids = string( ...
    assigned.campaign_condition_id);

stream = RandStream( ...
    "Threefry", ...
    Seed=options.RandomSeed);

valid_cells = unique( ...
    cell_keys(valid), ...
    "stable");

valid_cells(valid_cells == "") = [];

for cell_index = 1:numel(valid_cells)
    cell_key = valid_cells(cell_index);

    cell_rows = find( ...
        valid & cell_keys == cell_key);

    cell_conditions = unique( ...
        condition_ids(cell_rows), ...
        "stable");

    candidate_rows = zeros(0, 1);

    for condition_index = 1:numel(cell_conditions)
        condition_id = ...
            cell_conditions(condition_index);

        condition_rows = cell_rows( ...
            condition_ids(cell_rows) == condition_id);

        condition_rows = sample_rows( ...
            condition_rows, ...
            options. ...
                MaximumExamplesPerConditionPerCell, ...
            stream);

        candidate_rows = [
            candidate_rows
            condition_rows
            ]; %#ok<AGROW>
    end

    selected_cell_rows = sample_rows( ...
        candidate_rows, ...
        options.MaximumExamplesPerCell, ...
        stream);

    selected(selected_cell_rows) = true;
end

weights = assign_hierarchical_weights( ...
    assigned, ...
    selected, ...
    cell_keys, ...
    condition_ids);

assigned.selected_for_training = selected;
assigned.training_weight = weights;

summary = summarize_selection( ...
    assigned, ...
    cell_keys);

result = struct();

result.schema_name = ...
    "reqml_balanced_training_selection";

result.schema_version = "1.0";

result.random_seed = options.RandomSeed;

result.example_count = row_count;
result.valid_example_count = nnz(valid);
result.selected_example_count = nnz(selected);

result.coverage_cell_count = ...
    height(summary);

result.examples = assigned;
result.summary = summary;

result.paths = struct( ...
    "examples_mat", "", ...
    "summary_csv", "");

if options.SaveOutputs
    result.paths = save_outputs( ...
        result, ...
        options.OutputDirectory);
end

end


function rows = sample_rows(rows, maximum_count, stream)

rows = rows(:);

if isempty(rows) || ...
        isinf(maximum_count) || ...
        numel(rows) <= maximum_count

    return
end

order = randperm(stream, numel(rows));

rows = rows(order(1:maximum_count));

end


function weights = assign_hierarchical_weights( ...
        assigned, selected, ...
        cell_keys, condition_ids)

weights = zeros(height(assigned), 1);

selected_cells = unique( ...
    cell_keys(selected), ...
    "stable");

selected_cells(selected_cells == "") = [];

cell_count = numel(selected_cells);

if cell_count == 0
    return
end

for cell_index = 1:cell_count
    cell_key = selected_cells(cell_index);

    cell_rows = find( ...
        selected & cell_keys == cell_key);

    cell_conditions = unique( ...
        condition_ids(cell_rows), ...
        "stable");

    condition_count = numel(cell_conditions);

    for condition_index = 1:condition_count
        condition_rows = cell_rows( ...
            condition_ids(cell_rows) == ...
                cell_conditions(condition_index));

        row_weight = ...
            1 / ...
            (cell_count * ...
             condition_count * ...
             numel(condition_rows));

        weights(condition_rows) = row_weight;
    end
end

positive = weights > 0;

if any(positive)
    weights(positive) = ...
        weights(positive) / ...
        mean(weights(positive));
end

end


function summary = summarize_selection( ...
        assigned, cell_keys)

valid = logical(assigned.coverage_valid);

keys = unique(cell_keys(valid), "stable");
keys(keys == "") = [];

summary = table();

for index = 1:numel(keys)
    key = keys(index);

    rows = find(valid & cell_keys == key);

    first = rows(1);

    new_row = table( ...
        assigned.coverage_purity_bin(first), ...
        assigned.coverage_diffusivity_bin(first), ...
        string(assigned.coverage_purity_label(first)), ...
        string(assigned.coverage_diffusivity_label(first)), ...
        numel(rows), ...
        nnz(assigned.selected_for_training(rows)), ...
        numel(unique(string( ...
            assigned.campaign_condition_id(rows)))), ...
        numel(unique(string( ...
            assigned.campaign_run_id(rows)))), ...
        sum(assigned.training_weight(rows)), ...
        VariableNames={ ...
            'purity_bin', ...
            'dnom_bin', ...
            'purity_label', ...
            'dnom_label', ...
            'available_example_count', ...
            'selected_example_count', ...
            'independent_condition_count', ...
            'independent_run_count', ...
            'training_weight_sum' ...
            });

    summary = [summary; new_row]; %#ok<AGROW>
end

summary = sortrows( ...
    summary, ...
    ["dnom_bin", "purity_bin"]);

end


function keys = make_cell_keys(assigned)

keys = strings(height(assigned), 1);

valid = logical(assigned.coverage_valid);

keys(valid) = compose( ...
    "p%02d_d%02d", ...
    assigned.coverage_purity_bin(valid), ...
    assigned.coverage_diffusivity_bin(valid));

end


function validate_required_variables(examples)

required = [
    "coverage_valid"
    "coverage_purity_bin"
    "coverage_diffusivity_bin"
    "coverage_purity_label"
    "coverage_diffusivity_label"
    "campaign_condition_id"
    "campaign_run_id"
    ];

missing = setdiff( ...
    required, ...
    string(examples.Properties.VariableNames));

if ~isempty(missing)
    error("reqml:MissingBalancedTrainingVariable", ...
        "Balanced training requires variable '%s'.", ...
        missing(1));
end

end


function validate_limits(options)

validate_limit( ...
    options.MaximumExamplesPerCell, ...
    "MaximumExamplesPerCell");

validate_limit( ...
    options.MaximumExamplesPerConditionPerCell, ...
    "MaximumExamplesPerConditionPerCell");

if ~isfinite(options.RandomSeed) || ...
        options.RandomSeed < 0 || ...
        options.RandomSeed ~= fix(options.RandomSeed)

    error("reqml:InvalidBalancedTrainingOption", ...
        "RandomSeed must be a nonnegative integer.");
end

end


function validate_limit(value, name)

if ~(isinf(value) || ...
        (isfinite(value) && ...
         value >= 1 && ...
         value == fix(value)))

    error("reqml:InvalidBalancedTrainingOption", ...
        "%s must be a positive integer or Inf.", ...
        name);
end

end


function paths = save_outputs(result, output_directory)

output_directory = string(output_directory);

if strlength(output_directory) == 0
    error("reqml:MissingBalancedTrainingOutputDirectory", ...
        ["OutputDirectory is required when " ...
         "SaveOutputs=true."]);
end

if isfolder(output_directory)
    error("reqml:BalancedTrainingOutputExists", ...
        "Output directory already exists: %s", ...
        output_directory);
end

[created, message] = mkdir(output_directory);

if ~created
    error("reqml:BalancedTrainingOutputCreateFailed", ...
        "Could not create output directory '%s': %s", ...
        output_directory, ...
        message);
end

examples = result.examples; %#ok<NASGU>

examples_path = fullfile( ...
    output_directory, ...
    "examples_with_training_selection.mat");

summary_path = fullfile( ...
    output_directory, ...
    "training_balance_summary.csv");

save(examples_path, "examples", "-v7.3");

writetable(result.summary, summary_path);

paths = struct();

paths.examples_mat = string(examples_path);
paths.summary_csv = string(summary_path);

end
