function difficulty = rankDifficultCoverageCells( ...
    history, final_deficits, options)
%RANKDIFFICULTCOVERAGECELLS Rank deficient adaptive coverage cells.
%
% The ranking combines final deficits, stagnation, request frequency,
% and requested-cell hit rate.

arguments
    history table
    final_deficits table

    options.RecentWindow (1,1) double = 10
end

if isempty(history)
    error("reqml:AdaptiveAuditEmptyHistory", ...
        "Coverage-cell history must not be empty.");
end

if isempty(final_deficits)
    difficulty = table();
    return
end

recent_window = double(options.RecentWindow);
final_iteration = max(history.iteration_index);

required_history_columns = [
    "cell_key"
    "iteration_index"
    "example_count"
    "independent_run_count"
    "independent_condition_count"
    "requested_condition_count"
    "requested_patch_count"
    "requested_cell_patch_count"
    "requested_cell_hit_count"
    ];

validate_columns( ...
    history, ...
    required_history_columns, ...
    "coverage history");

required_deficit_columns = [
    "cell_key"
    "sws_bin"
    "frequency_bin"
    "purity_bin"
    "diffusivity_bin"
    "sws_label"
    "frequency_label"
    "purity_label"
    "diffusivity_label"
    "example_count"
    "independent_run_count"
    "independent_condition_count"
    "required_example_count"
    "required_independent_run_count"
    "example_deficit"
    "independent_run_deficit"
    "independent_condition_deficit"
    "deficit_score"
    ];

validate_columns( ...
    final_deficits, ...
    required_deficit_columns, ...
    "final deficits");

row_count = height(final_deficits);

first_observed_iteration = nan(row_count, 1);
last_improvement_iteration = nan(row_count, 1);
iterations_since_improvement = nan(row_count, 1);

total_example_gain = zeros(row_count, 1);
recent_example_gain = zeros(row_count, 1);

total_requested_conditions = zeros(row_count, 1);
total_requested_patches = zeros(row_count, 1);
total_requested_cell_patches = zeros(row_count, 1);
total_requested_cell_hits = zeros(row_count, 1);

request_hit_rate = nan(row_count, 1);
difficulty_reason = strings(row_count, 1);
difficulty_score = zeros(row_count, 1);

for row = 1:row_count
    cell_key = final_deficits.cell_key(row);

    cell_history = history( ...
        history.cell_key == cell_key, ...
        :);

    cell_history = sortrows( ...
        cell_history, ...
        "iteration_index");

    examples = double(cell_history.example_count);
    iterations = double(cell_history.iteration_index);

    observed_index = find(examples > 0, 1, "first");

    if ~isempty(observed_index)
        first_observed_iteration(row) = ...
            iterations(observed_index);
    end

    gains = [examples(1); diff(examples)];
    improved_index = find(gains > 0);

    if ~isempty(improved_index)
        last_improvement_iteration(row) = ...
            iterations(improved_index(end));

        iterations_since_improvement(row) = ...
            final_iteration - ...
            last_improvement_iteration(row);
    else
        iterations_since_improvement(row) = ...
            final_iteration;
    end

    total_example_gain(row) = ...
        examples(end) - examples(1);

    recent_start_iteration = ...
        max(1, final_iteration - recent_window);

    prior_index = find( ...
        iterations <= recent_start_iteration, ...
        1, ...
        "last");

    if isempty(prior_index)
        prior_example_count = examples(1);
    else
        prior_example_count = examples(prior_index);
    end

    recent_example_gain(row) = ...
        examples(end) - prior_example_count;

    total_requested_conditions(row) = sum( ...
        double(cell_history.requested_condition_count));

    total_requested_patches(row) = sum( ...
        double(cell_history.requested_patch_count));

    total_requested_cell_patches(row) = sum( ...
        double(cell_history.requested_cell_patch_count));

    total_requested_cell_hits(row) = sum( ...
        double(cell_history.requested_cell_hit_count));

    if total_requested_conditions(row) > 0
        request_hit_rate(row) = ...
            total_requested_cell_hits(row) / ...
            total_requested_conditions(row);
    end

    reasons = strings(0, 1);

    if final_deficits.example_count(row) == 0
        reasons(end + 1) = "never_observed";
    elseif recent_example_gain(row) == 0
        reasons(end + 1) = "stagnant";
    end

    if total_requested_conditions(row) == 0
        reasons(end + 1) = "not_requested";
    elseif total_requested_cell_hits(row) == 0
        reasons(end + 1) = "requests_miss_target";
    elseif request_hit_rate(row) < 0.25
        reasons(end + 1) = "low_request_hit_rate";
    end

    if final_deficits.example_deficit(row) > 0
        reasons(end + 1) = "insufficient_examples";
    end

    if final_deficits.independent_run_deficit(row) > 0
        reasons(end + 1) = "insufficient_independent_runs";
    end

    if final_deficits.independent_condition_deficit(row) > 0
        reasons(end + 1) = ...
            "insufficient_independent_conditions";
    end

    difficulty_reason(row) = strjoin(reasons, "|");

    score = double(final_deficits.deficit_score(row));

    if final_deficits.example_count(row) == 0
        score = score + 5;
    end

    score = score + min( ...
        iterations_since_improvement(row) / ...
        max(recent_window, 1), ...
        5);

    if total_requested_conditions(row) == 0
        score = score + 2;
    elseif isfinite(request_hit_rate(row))
        score = score + ...
            3 * (1 - request_hit_rate(row));
    end

    difficulty_score(row) = score;
end

difficulty = final_deficits;

difficulty.final_iteration = repmat( ...
    final_iteration, ...
    row_count, ...
    1);

difficulty.first_observed_iteration = ...
    first_observed_iteration;

difficulty.last_improvement_iteration = ...
    last_improvement_iteration;

difficulty.iterations_since_improvement = ...
    iterations_since_improvement;

difficulty.total_example_gain = ...
    total_example_gain;

difficulty.recent_example_gain = ...
    recent_example_gain;

difficulty.total_requested_conditions = ...
    total_requested_conditions;

difficulty.total_requested_patches = ...
    total_requested_patches;

difficulty.total_requested_cell_patches = ...
    total_requested_cell_patches;

difficulty.total_requested_cell_hits = ...
    total_requested_cell_hits;

difficulty.request_hit_rate = ...
    request_hit_rate;

difficulty.difficulty_reason = ...
    difficulty_reason;

difficulty.difficulty_score = ...
    difficulty_score;

difficulty = sortrows( ...
    difficulty, ...
    ["difficulty_score", ...
     "iterations_since_improvement", ...
     "deficit_score"], ...
    ["descend", "descend", "descend"]);

end


function validate_columns(table_value, required_columns, description)

missing_columns = setdiff( ...
    required_columns, ...
    string(table_value.Properties.VariableNames));

if ~isempty(missing_columns)
    error("reqml:AdaptiveAuditColumnsMissing", ...
        "%s is missing columns: %s", ...
        description, ...
        strjoin(missing_columns, ", "));
end

end
