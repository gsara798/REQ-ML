function tests = test_complete_coverage_grid
%TEST_COMPLETE_COVERAGE_GRID Test explicit zero-coverage cells.

tests = functiontests(localfunctions);

end


function setupOnce(~)

root = fileparts(fileparts(fileparts( ...
    mfilename("fullpath"))));

addpath(fullfile(root, "src"));

end


function testAddsAllConfiguredCells(testCase)

summary = table();

summary.purity_bin = [2; 3];
summary.diffusivity_bin = [1; 2];

summary.purity_label = ...
    ["[0.7,0.9)"; "[0.9,1]"];

summary.diffusivity_label = ...
    ["[0,0.5)"; "[0.5,1]"];

summary.example_count = [4; 8];
summary.independent_run_count = [2; 3];
summary.sws_bin_count = [1; 2];
summary.frequency_bin_count = [1; 2];
summary.independent_condition_count = [1; 2];

complete = reqml.coverage.completeCoverageGrid( ...
    summary, ...
    [0.5 0.7 0.9 1.0], ...
    [0 0.5 1.0]);

verifyEqual(testCase, height(complete), 6);

empty_cell = ...
    complete.purity_bin == 1 & ...
    complete.diffusivity_bin == 1;

verifyEqual(testCase, ...
    complete.example_count(empty_cell), ...
    0);

verifyEqual(testCase, ...
    complete.independent_run_count(empty_cell), ...
    0);

observed_cell = ...
    complete.purity_bin == 2 & ...
    complete.diffusivity_bin == 1;

verifyEqual(testCase, ...
    complete.example_count(observed_cell), ...
    4);

verifyEqual(testCase, ...
    complete.independent_run_count(observed_cell), ...
    2);

end
