function state = loadAdaptiveLoopState(output_root)
%LOADADAPTIVELOOPSTATE Load and validate a persisted adaptive loop.
%
% Expected files:
%
%   adaptive_loop_summary.json
%   adaptive_loop_iterations.csv
%
% For an incomplete loop, the latest iteration must also contain:
%
%   next_batch/
%
% The returned state identifies the accumulated CSV and next batch from
% which execution can continue.

arguments
    output_root {mustBeTextScalar}
end

output_root = string(output_root);

if ~isfolder(output_root)
    error("reqml:AdaptiveLoopOutputNotFound", ...
        "Adaptive loop output directory was not found: %s", ...
        output_root);
end

summary_path = fullfile( ...
    output_root, ...
    "adaptive_loop_summary.json");

iterations_path = fullfile( ...
    output_root, ...
    "adaptive_loop_iterations.csv");

if ~isfile(summary_path)
    error("reqml:AdaptiveLoopSummaryNotFound", ...
        "Adaptive loop summary was not found: %s", ...
        summary_path);
end

if ~isfile(iterations_path)
    error("reqml:AdaptiveLoopIterationsNotFound", ...
        "Adaptive loop iterations CSV was not found: %s", ...
        iterations_path);
end

summary = jsondecode(fileread(summary_path));

iterations = readtable( ...
    iterations_path, ...
    Delimiter=",", ...
    TextType="string", ...
    VariableNamingRule="preserve");

validate_summary(summary);
validate_iterations(iterations);
validate_consistency(summary, iterations);

last = iterations(end, :);

accumulated_csv = string( ...
    last.("accumulated_campaign_csv"));

iteration_directory = string( ...
    last.("iteration_directory"));

if ~isfile(accumulated_csv)
    error("reqml:AdaptiveLoopAccumulatedCsvNotFound", ...
        "Final accumulated campaign CSV was not found: %s", ...
        accumulated_csv);
end

if ~isfolder(iteration_directory)
    error("reqml:AdaptiveLoopIterationDirectoryNotFound", ...
        "Final iteration directory was not found: %s", ...
        iteration_directory);
end

coverage_complete = logical( ...
    last.("coverage_complete"));

next_batch_directory = "";

if ~coverage_complete
    next_batch_directory = fullfile( ...
        iteration_directory, ...
        "next_batch");

    if ~isfolder(next_batch_directory)
        error("reqml:AdaptiveLoopNextBatchNotFound", ...
            ["Persisted loop is incomplete, but its final " ...
             "next_batch directory was not found: %s"], ...
            next_batch_directory);
    end

    plan_path = fullfile( ...
        next_batch_directory, ...
        "adaptive_batch_plan.json");

    if ~isfile(plan_path)
        error("reqml:AdaptiveLoopNextBatchPlanNotFound", ...
            "Next adaptive batch plan was not found: %s", ...
            plan_path);
    end
end

state = struct();

state.schema_name = ...
    "reqml_adaptive_loop_state";

state.schema_version = "1.0";

state.output_root = output_root;
state.campaign_id = string(summary.campaign_id);

state.completed_iteration_count = ...
    height(iterations);

state.coverage_complete = coverage_complete;
state.stop_reason = string(summary.stop_reason);

state.final_accumulated_campaign_csv = ...
    accumulated_csv;

state.final_iteration_directory = ...
    iteration_directory;

state.next_batch_directory = ...
    string(next_batch_directory);

state.iterations = iterations;

state.paths = struct();
state.paths.summary_json = string(summary_path);
state.paths.iterations_csv = string(iterations_path);

end


function validate_summary(summary)

required = [
    "schema_name"
    "schema_version"
    "campaign_id"
    "completed_iteration_count"
    "stop_reason"
    "coverage_complete"
    ];

missing = setdiff( ...
    required, ...
    string(fieldnames(summary)));

if ~isempty(missing)
    error("reqml:InvalidAdaptiveLoopSummary", ...
        "Adaptive loop summary is missing field '%s'.", ...
        missing(1));
end

if string(summary.schema_name) ~= ...
        "reqml_adaptive_campaign_loop"

    error("reqml:InvalidAdaptiveLoopSummary", ...
        "Unsupported adaptive loop summary schema '%s'.", ...
        string(summary.schema_name));
end

end


function validate_iterations(iterations)

required = [
    "iteration_index"
    "iteration_id"
    "iteration_directory"
    "accumulated_campaign_csv"
    "deficient_cell_count"
    "coverage_complete"
    "next_batch_required"
    ];

missing = setdiff( ...
    required, ...
    string(iterations.Properties.VariableNames));

if ~isempty(missing)
    error("reqml:InvalidAdaptiveLoopIterations", ...
        "Adaptive loop iterations CSV is missing column '%s'.", ...
        missing(1));
end

if isempty(iterations)
    error("reqml:EmptyAdaptiveLoopIterations", ...
        "Adaptive loop iterations CSV contains no iterations.");
end

expected_indices = (1:height(iterations))';

if ~isequal( ...
        double(iterations.("iteration_index")), ...
        expected_indices)

    error("reqml:InvalidAdaptiveLoopIterationOrder", ...
        "Adaptive loop iteration indices must be contiguous from one.");
end

end


function validate_consistency(summary, iterations)

reported_count = ...
    double(summary.completed_iteration_count);

if reported_count ~= height(iterations)
    error("reqml:AdaptiveLoopIterationCountMismatch", ...
        ["Summary reports %d completed iterations, " ...
         "but the iterations CSV contains %d."], ...
        reported_count, ...
        height(iterations));
end

summary_complete = logical(summary.coverage_complete);
table_complete = logical( ...
    iterations.("coverage_complete")(end));

if summary_complete ~= table_complete
    error("reqml:AdaptiveLoopCompletionMismatch", ...
        ["Summary and final iteration disagree about " ...
         "coverage completion."]);
end

summary_csv = string( ...
    summary.final_accumulated_campaign_csv);

table_csv = string( ...
    iterations.("accumulated_campaign_csv")(end));

if summary_csv ~= table_csv
    error("reqml:AdaptiveLoopFinalCsvMismatch", ...
        ["Summary and final iteration reference different " ...
         "accumulated campaign CSV files."]);
end

end
