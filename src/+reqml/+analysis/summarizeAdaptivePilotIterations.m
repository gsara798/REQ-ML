function summary = summarizeAdaptivePilotIterations(loop_root, options)
%SUMMARIZEADAPTIVEPILOTITERATIONS Aggregate adaptive-pilot progress.
%
% Requested-cell metrics are recomputed from the executed batch plan and
% coverage report by default. This applies the current four-dimensional
% requested-cell definition to both legacy and analytic campaigns.

arguments
    loop_root {mustBeTextScalar}
    options.MaximumIterations (1,1) double = Inf
    options.RecomputeRequestedMetrics (1,1) logical = true
end

loop_root = string(loop_root);
iterations_file = fullfile(loop_root, "adaptive_loop_iterations.csv");

if ~isfile(iterations_file)
    error("reqml:AdaptivePilotIterationsNotFound", ...
        "Adaptive loop iteration table was not found: %s", iterations_file);
end

iterations = readtable(iterations_file, Delimiter=",", TextType="string");
required_iteration_columns = [ ...
    "iteration_index"
    "batch_directory"
    "iteration_directory"
    "executed_run_count"
    "accumulated_run_count"
    "example_count"
    "observed_coverage_cell_count"
    "deficient_cell_count"
    ];
validate_columns(iterations, required_iteration_columns, iterations_file);

iterations = sortrows(iterations, "iteration_index");
iterations = iterations(iterations.iteration_index <= ...
    options.MaximumIterations, :);

if isempty(iterations)
    error("reqml:AdaptivePilotNoIterationsFound", ...
        "No adaptive iterations were available in: %s", loop_root);
end

indices = double(iterations.iteration_index);
expected = (indices(1):indices(end))';
if indices(1) ~= 1 || ~isequal(indices, expected)
    error("reqml:AdaptivePilotMissingIterationArtifact", ...
        "Adaptive iteration indices must be contiguous from one through %d.", ...
        indices(end));
end

iteration_count = height(iterations);
newly_observed_cell_count = zeros(iteration_count, 1);
newly_complete_cell_count = zeros(iteration_count, 1);

requested_condition_count = zeros(iteration_count, 1);
requested_cell_hit_count = zeros(iteration_count, 1);
requested_cell_hit_rate = nan(iteration_count, 1);
condition_with_patch_count = zeros(iteration_count, 1);
condition_with_valid_patch_count = zeros(iteration_count, 1);
zero_patch_condition_count = zeros(iteration_count, 1);
total_patch_count = zeros(iteration_count, 1);
requested_cell_patch_count = zeros(iteration_count, 1);
median_absolute_predicted_purity_error = nan(iteration_count, 1);
maximum_absolute_predicted_purity_error = nan(iteration_count, 1);
median_signed_predicted_purity_error = nan(iteration_count, 1);

prior_observed = strings(0, 1);
prior_complete = strings(0, 1);

for row = 1:iteration_count
    iteration_directory = string(iterations.iteration_directory(row));
    coverage_file = fullfile(iteration_directory, "coverage_summary.csv");
    deficits_file = fullfile(iteration_directory, "coverage_deficits.csv");

    if ~isfile(coverage_file) || ~isfile(deficits_file)
        error("reqml:AdaptivePilotMissingIterationArtifact", ...
            "Iteration %d requires coverage_summary.csv and " + ...
            "coverage_deficits.csv in: %s", ...
            indices(row), iteration_directory);
    end

    coverage = readtable(coverage_file, Delimiter=",", TextType="string");
    deficits = readtable(deficits_file, Delimiter=",", TextType="string");
    validate_columns(coverage, ["cell_key", "example_count"], coverage_file);
    validate_columns(deficits, "cell_key", deficits_file);

    observed = string(coverage.cell_key(double(coverage.example_count) > 0));
    complete = setdiff(string(coverage.cell_key), string(deficits.cell_key), ...
        "stable");

    newly_observed_cell_count(row) = numel(setdiff(observed, prior_observed));
    newly_complete_cell_count(row) = numel(setdiff(complete, prior_complete));
    prior_observed = observed;
    prior_complete = complete;

    requests = read_iteration_requests(iterations(row, :), ...
        options.RecomputeRequestedMetrics);
    request_metrics = aggregate_requests(requests);

    requested_condition_count(row) = request_metrics.condition_count;
    requested_cell_hit_count(row) = request_metrics.hit_count;
    requested_cell_hit_rate(row) = request_metrics.hit_rate;
    condition_with_patch_count(row) = request_metrics.with_patch_count;
    condition_with_valid_patch_count(row) = ...
        request_metrics.with_valid_patch_count;
    zero_patch_condition_count(row) = request_metrics.zero_patch_count;
    total_patch_count(row) = request_metrics.patch_count;
    requested_cell_patch_count(row) = ...
        request_metrics.requested_cell_patch_count;
    median_absolute_predicted_purity_error(row) = ...
        request_metrics.median_absolute_purity_error;
    maximum_absolute_predicted_purity_error(row) = ...
        request_metrics.maximum_absolute_purity_error;
    median_signed_predicted_purity_error(row) = ...
        request_metrics.median_signed_purity_error;
end

progress = table( ...
    indices, ...
    double(iterations.executed_run_count), ...
    double(iterations.accumulated_run_count), ...
    double(iterations.example_count), ...
    double(iterations.observed_coverage_cell_count), ...
    double(iterations.deficient_cell_count), ...
    newly_observed_cell_count, ...
    newly_complete_cell_count, ...
    requested_condition_count, ...
    requested_cell_hit_count, ...
    requested_cell_hit_rate, ...
    median_absolute_predicted_purity_error, ...
    maximum_absolute_predicted_purity_error, ...
    VariableNames=[ ...
        "iteration_index"
        "executed_run_count"
        "accumulated_run_count"
        "example_count"
        "observed_coverage_cell_count"
        "deficient_cell_count"
        "newly_observed_cell_count"
        "newly_complete_cell_count"
        "requested_condition_count"
        "requested_cell_hit_count"
        "requested_cell_hit_rate"
        "median_absolute_predicted_purity_error"
        "maximum_absolute_predicted_purity_error"
        ]);

requested = table( ...
    indices, ...
    requested_condition_count, ...
    condition_with_patch_count, ...
    condition_with_valid_patch_count, ...
    zero_patch_condition_count, ...
    total_patch_count, ...
    requested_cell_patch_count, ...
    requested_cell_hit_count, ...
    requested_cell_hit_rate, ...
    median_signed_predicted_purity_error, ...
    median_absolute_predicted_purity_error, ...
    maximum_absolute_predicted_purity_error, ...
    VariableNames=[ ...
        "iteration_index"
        "requested_condition_count"
        "condition_with_patch_count"
        "condition_with_valid_patch_count"
        "zero_patch_condition_count"
        "patch_count"
        "requested_cell_patch_count"
        "requested_cell_hit_count"
        "requested_cell_hit_rate"
        "median_signed_predicted_purity_error"
        "median_absolute_predicted_purity_error"
        "maximum_absolute_predicted_purity_error"
        ]);

summary = struct();
summary.loop_root = loop_root;
summary.progress = progress;
summary.requested_vs_achieved = requested;
summary.iterations = iterations;

end


function requests = read_iteration_requests(iteration_row, recompute)

iteration_directory = string(iteration_row.iteration_directory);

if recompute
    report_file = fullfile(iteration_directory, "coverage_report.mat");
    plan_file = fullfile(string(iteration_row.batch_directory), ...
        "adaptive_batch_plan.json");

    if ~isfile(report_file) || ~isfile(plan_file)
        error("reqml:AdaptivePilotMissingIterationArtifact", ...
            "Requested-cell recomputation requires coverage_report.mat " + ...
            "and the executed adaptive_batch_plan.json for: %s", ...
            iteration_directory);
    end

    loaded = load(report_file, "coverage_report");
    if ~isfield(loaded, "coverage_report") || ...
            ~isfield(loaded.coverage_report, "assigned_examples")
        error("reqml:AdaptivePilotInvalidCoverageReport", ...
            "Coverage report lacks assigned_examples: %s", report_file);
    end

    requests = reqml.coverage.summarizeRequestedVsAchieved( ...
        loaded.coverage_report.assigned_examples, plan_file);
    return
end

request_file = fullfile(iteration_directory, "requested_vs_achieved.csv");
if isfile(request_file)
    requests = readtable(request_file, Delimiter=",", TextType="string");
else
    requests = table();
end

end


function metrics = aggregate_requests(requests)

metrics = struct( ...
    "condition_count", height(requests), ...
    "hit_count", 0, ...
    "hit_rate", NaN, ...
    "with_patch_count", 0, ...
    "with_valid_patch_count", 0, ...
    "zero_patch_count", 0, ...
    "patch_count", 0, ...
    "requested_cell_patch_count", 0, ...
    "median_absolute_purity_error", NaN, ...
    "maximum_absolute_purity_error", NaN, ...
    "median_signed_purity_error", NaN);

if isempty(requests)
    return
end

names = string(requests.Properties.VariableNames);
if ismember("requested_cell_hit", names)
    hits = logical(requests.requested_cell_hit);
    metrics.hit_count = sum(hits);
    metrics.hit_rate = metrics.hit_count / height(requests);
end

if ismember("patch_count", names)
    patch_count = double(requests.patch_count);
    metrics.with_patch_count = sum(patch_count > 0);
    metrics.zero_patch_count = sum(patch_count == 0);
    metrics.patch_count = sum(patch_count, "omitnan");
end

if ismember("valid_patch_count", names)
    metrics.with_valid_patch_count = sum(double(requests.valid_patch_count) > 0);
end

if ismember("requested_cell_patch_count", names)
    metrics.requested_cell_patch_count = sum( ...
        double(requests.requested_cell_patch_count), "omitnan");
end

errors = nan(0, 1);
if ismember("predicted_vs_achieved_purity_error", names)
    errors = double(requests.predicted_vs_achieved_purity_error);
elseif all(ismember(["predicted_discrete_purity", "purity_median"], names))
    errors = double(requests.purity_median) - ...
        double(requests.predicted_discrete_purity);
end
errors = errors(isfinite(errors));

if ~isempty(errors)
    metrics.median_signed_purity_error = median(errors);
    metrics.median_absolute_purity_error = median(abs(errors));
    metrics.maximum_absolute_purity_error = max(abs(errors));
end

end


function validate_columns(table_value, required, description)

missing = setdiff(string(required), ...
    string(table_value.Properties.VariableNames));
if ~isempty(missing)
    error("reqml:AdaptivePilotMissingIterationArtifact", ...
        "%s is missing required column(s): %s", ...
        description, strjoin(missing, ", "));
end

end
