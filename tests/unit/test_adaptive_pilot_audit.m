function tests = test_adaptive_pilot_audit
%TEST_ADAPTIVE_PILOT_AUDIT Test pilot aggregation and comparison.

tests = functiontests(localfunctions);

end


function setupOnce(testCase)

testCase.TestData.repository_root = string(fileparts(fileparts(fileparts( ...
    mfilename("fullpath")))));
addpath(fullfile(testCase.TestData.repository_root, "src"));

end


function testAggregatesIterationProgressAndPurityErrors(testCase)

root = make_loop_fixture(testCase, [1 2], [2 1], false);
summary = reqml.analysis.summarizeAdaptivePilotIterations(root, ...
    RecomputeRequestedMetrics=false);

verifyEqual(testCase, summary.progress.newly_observed_cell_count, [1; 1]);
verifyEqual(testCase, summary.progress.newly_complete_cell_count, [1; 1]);
verifyEqual(testCase, summary.progress.requested_condition_count, [2; 2]);
verifyEqual(testCase, summary.progress.requested_cell_hit_count, [1; 1]);
verifyEqual(testCase, summary.progress.requested_cell_hit_rate, [0.5; 0.5]);
verifyEqual(testCase, ...
    summary.progress.median_absolute_predicted_purity_error, ...
    [0.02; 0.02], AbsTol=1e-12);
verifyEqual(testCase, ...
    summary.progress.maximum_absolute_predicted_purity_error, ...
    [0.03; 0.03], AbsTol=1e-12);

end


function testZeroRequestIterationProducesNaNRate(testCase)

root = make_loop_fixture(testCase, [1 2], [2 1], true);
summary = reqml.analysis.summarizeAdaptivePilotIterations(root, ...
    RecomputeRequestedMetrics=false);

verifyEqual(testCase, summary.progress.requested_condition_count, [2; 0]);
verifyEqual(testCase, summary.progress.requested_cell_hit_count, [1; 0]);
verifyTrue(testCase, isnan(summary.progress.requested_cell_hit_rate(2)));
verifyTrue(testCase, isnan( ...
    summary.progress.median_absolute_predicted_purity_error(2)));

end


function testMissingIterationArtifactFailsClearly(testCase)

root = string(testCase.applyFixture( ...
    matlab.unittest.fixtures.TemporaryFolderFixture).Folder);
iteration_directory = fullfile(root, "pilot_iteration_001");
mkdir(iteration_directory);
writetable(table("c01", 1, VariableNames=["cell_key", "example_count"]), ...
    fullfile(iteration_directory, "coverage_summary.csv"));
write_iterations_table(root, iteration_directory, 1, 1, 2);

verifyError(testCase, @() ...
    reqml.analysis.summarizeAdaptivePilotIterations(root, ...
        RecomputeRequestedMetrics=false), ...
    "reqml:AdaptivePilotMissingIterationArtifact");

end


function testComparesExactlyFirstTenIterations(testCase)

v2 = make_progress_table((1:12)', 500 - (1:12)' * 10, 0.20);
v3 = make_progress_table((1:10)', 500 - (1:10)' * 15, 0.75);

comparison = reqml.analysis.compareAdaptivePilotProgress(v2, v3, ...
    MaximumIterations=10);

verifyEqual(testCase, height(comparison), 10);
verifyEqual(testCase, comparison.iteration_index, (1:10)');
verifyEqual(testCase, ...
    comparison.deficient_cell_count_difference_v3_minus_v2, ...
    -(1:10)' * 5);
verifyEqual(testCase, ...
    comparison.requested_hit_rate_difference_v3_minus_v2, ...
    repmat(0.55, 10, 1), AbsTol=1e-12);

end


function root = make_loop_fixture(testCase, observed_counts, ...
        deficient_counts, zero_second_request)

root = string(testCase.applyFixture( ...
    matlab.unittest.fixtures.TemporaryFolderFixture).Folder);
iteration_count = numel(observed_counts);
directories = strings(iteration_count, 1);

for index = 1:iteration_count
    directories(index) = fullfile(root, sprintf("pilot_iteration_%03d", index));
    mkdir(directories(index));

    cell_key = ["c01"; "c02"; "c03"];
    example_count = zeros(3, 1);
    example_count(1:observed_counts(index)) = 4;
    writetable(table(cell_key, example_count), ...
        fullfile(directories(index), "coverage_summary.csv"));

    deficient_keys = cell_key((end - deficient_counts(index) + 1):end);
    writetable(table(deficient_keys, VariableNames="cell_key"), ...
        fullfile(directories(index), "coverage_deficits.csv"));

    if zero_second_request && index == 2
        requests = empty_request_table();
    else
        requests = table( ...
            [true; false], ...
            [2; 1], ...
            [2; 1], ...
            [1; 0], ...
            [-0.01; 0.03], ...
            VariableNames=[ ...
                "requested_cell_hit"
                "patch_count"
                "valid_patch_count"
                "requested_cell_patch_count"
                "predicted_vs_achieved_purity_error"]);
    end
    writetable(requests, ...
        fullfile(directories(index), "requested_vs_achieved.csv"));
end

write_iterations_table(root, directories, (1:iteration_count)', ...
    observed_counts(:), deficient_counts(:));

end


function write_iterations_table(root, directories, indices, observed, deficient)

indices = indices(:);
row_count = numel(indices);
directories = string(directories(:));
batch_directory = repmat(fullfile(root, "batch"), row_count, 1);
executed_run_count = repmat(2, row_count, 1);
accumulated_run_count = (2:2:(2 * row_count))';
example_count = observed(:) * 4;
observed_coverage_cell_count = observed(:);
deficient_cell_count = deficient(:);
iteration_index = indices;
iteration_directory = directories;

iterations = table(iteration_index, batch_directory, iteration_directory, ...
    executed_run_count, accumulated_run_count, example_count, ...
    observed_coverage_cell_count, deficient_cell_count);
writetable(iterations, fullfile(root, "adaptive_loop_iterations.csv"));

end


function requests = empty_request_table()

requests = table( ...
    false(0, 1), zeros(0, 1), zeros(0, 1), zeros(0, 1), zeros(0, 1), ...
    VariableNames=[ ...
        "requested_cell_hit"
        "patch_count"
        "valid_patch_count"
        "requested_cell_patch_count"
        "predicted_vs_achieved_purity_error"]);

end


function progress = make_progress_table(iteration_index, deficient, hit_rate)

row_count = numel(iteration_index);
accumulated_run_count = iteration_index * 24;
example_count = iteration_index * 40;
observed_coverage_cell_count = 500 - deficient;
deficient_cell_count = deficient;
requested_cell_hit_rate = repmat(hit_rate, row_count, 1);
median_absolute_predicted_purity_error = nan(row_count, 1);
maximum_absolute_predicted_purity_error = nan(row_count, 1);

progress = table(iteration_index, accumulated_run_count, example_count, ...
    observed_coverage_cell_count, deficient_cell_count, ...
    requested_cell_hit_rate, median_absolute_predicted_purity_error, ...
    maximum_absolute_predicted_purity_error);

end
