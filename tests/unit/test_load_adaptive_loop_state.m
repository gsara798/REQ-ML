function tests = test_load_adaptive_loop_state
%TEST_LOAD_ADAPTIVE_LOOP_STATE Test persisted loop-state loading.

tests = functiontests(localfunctions);

end


function setupOnce(~)

root = fileparts(fileparts(fileparts( ...
    mfilename("fullpath"))));

addpath(fullfile(root, "src"));

end


function testLoadsIncompleteLoopWithNextBatch(testCase)

root = string(tempname);
mkdir(root);

cleanup = onCleanup(@() cleanup_root(root));

iteration_directory = fullfile( ...
    root, ...
    "loop_iteration_002");

next_batch = fullfile( ...
    iteration_directory, ...
    "next_batch");

mkdir(iteration_directory);
mkdir(next_batch);

accumulated_csv = fullfile( ...
    iteration_directory, ...
    "accumulated_campaign_runs.csv");

write_table(accumulated_csv);
write_text( ...
    fullfile(next_batch, "adaptive_batch_plan.json"), ...
    "{}");

write_iterations( ...
    root, ...
    iteration_directory, ...
    accumulated_csv, ...
    false);

write_summary( ...
    root, ...
    accumulated_csv, ...
    iteration_directory, ...
    false);

state = ...
    reqml.campaigns.loadAdaptiveLoopState(root);

verifyFalse(testCase, state.coverage_complete);

verifyEqual(testCase, ...
    state.completed_iteration_count, ...
    2);

verifyEqual(testCase, ...
    state.final_accumulated_campaign_csv, ...
    string(accumulated_csv));

verifyEqual(testCase, ...
    state.next_batch_directory, ...
    string(next_batch));

clear cleanup

end


function testLoadsCompletedLoopWithoutNextBatch(testCase)

root = string(tempname);
mkdir(root);

cleanup = onCleanup(@() cleanup_root(root));

iteration_directory = fullfile( ...
    root, ...
    "loop_iteration_002");

mkdir(iteration_directory);

accumulated_csv = fullfile( ...
    iteration_directory, ...
    "accumulated_campaign_runs.csv");

write_table(accumulated_csv);

write_iterations( ...
    root, ...
    iteration_directory, ...
    accumulated_csv, ...
    true);

write_summary( ...
    root, ...
    accumulated_csv, ...
    iteration_directory, ...
    true);

state = ...
    reqml.campaigns.loadAdaptiveLoopState(root);

verifyTrue(testCase, state.coverage_complete);

verifyEqual(testCase, ...
    state.next_batch_directory, ...
    "");

clear cleanup

end


function testRejectsMissingSummary(testCase)

root = string(tempname);
mkdir(root);

cleanup = onCleanup(@() cleanup_root(root));

verifyError(testCase, ...
    @() reqml.campaigns.loadAdaptiveLoopState(root), ...
    "reqml:AdaptiveLoopSummaryNotFound");

clear cleanup

end


function write_iterations( ...
        root, iteration_directory, ...
        accumulated_csv, is_complete)

iterations = table();

iterations.iteration_index = [1; 2];

iterations.iteration_id = [
    "loop_iteration_001"
    "loop_iteration_002"
    ];

iterations.iteration_directory = [
    string(fullfile(root, "loop_iteration_001"))
    string(iteration_directory)
    ];

iterations.accumulated_campaign_csv = [
    string(fullfile(root, "first.csv"))
    string(accumulated_csv)
    ];

iterations.deficient_cell_count = [
    1
    double(~is_complete)
    ];

iterations.coverage_complete = [
    false
    is_complete
    ];

iterations.next_batch_required = [
    true
    ~is_complete
    ];

writetable( ...
    iterations, ...
    fullfile(root, "adaptive_loop_iterations.csv"));

end


function write_summary( ...
        root, accumulated_csv, ...
        iteration_directory, is_complete)

summary = struct();

summary.schema_name = ...
    "reqml_adaptive_campaign_loop";

summary.schema_version = "1.0";
summary.campaign_id = "loop_test";

summary.completed_iteration_count = 2;

if is_complete
    summary.stop_reason = "coverage_complete";
else
    summary.stop_reason = ...
        "maximum_iterations_reached";
end

summary.coverage_complete = is_complete;

summary.final_accumulated_campaign_csv = ...
    string(accumulated_csv);

summary.final_iteration_directory = ...
    string(iteration_directory);

write_text( ...
    fullfile(root, "adaptive_loop_summary.json"), ...
    jsonencode(summary, PrettyPrint=true));

end


function write_table(path_value)

value = table( ...
    [1; 2], ...
    VariableNames="ordinal");

writetable(value, path_value);

end


function write_text(path_value, content)

file_id = fopen(path_value, "w");
assert(file_id >= 0);

cleanup = onCleanup(@() fclose(file_id));

fprintf(file_id, "%s", content);

clear cleanup

end


function cleanup_root(root)

if isfolder(root)
    rmdir(root, "s");
end

end
