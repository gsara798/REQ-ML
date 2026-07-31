function tests = test_summarize_coverage
%TEST_SUMMARIZE_COVERAGE Test patch coverage summaries.

tests = functiontests(localfunctions);

end


function setupOnce(~)

root = fileparts(fileparts(fileparts( ...
    mfilename("fullpath"))));

addpath(fullfile(root, "src"));

end


function testSummarizesCountsAndIndependentRuns(testCase)

examples = table();

examples.truth_material_purity = ...
    [0.55; 0.60; 0.75; 0.76; 0.95];

examples.campaign_angular_entropy = ...
    [0.20; 0.25; 0.50; 0.55; 0.85];

examples.truth_cs_center_m_s = ...
    [1.8; 2.8; 2.2; 3.2; 4.0];

examples.campaign_frequency_hz = ...
    [200; 400; 400; 500; 600];

examples.campaign_run_id = ...
    ["run_1"; "run_2"; "run_2"; "run_3"; "run_4"];

assigned = reqml.coverage.assignCoverageBins( ...
    examples, ...
    PurityEdges=[0.5 0.7 0.9 1.0], ...
    DiffusivityEdges=[0 0.4 0.7 1.0], ...
    SwsEdges=[1.5 2.5 3.5 4.1], ...
    FrequencyEdges=[199 350 450 550 601]);

summary = reqml.coverage.summarizeCoverage(assigned);

verifyEqual(testCase, height(summary), 3);

verifyEqual(testCase, ...
    summary.example_count, ...
    [2; 2; 1]);

verifyEqual(testCase, ...
    summary.independent_run_count, ...
    [2; 2; 1]);

verifyEqual(testCase, ...
    summary.sws_bin_count, ...
    [2; 2; 1]);

verifyEqual(testCase, ...
    summary.frequency_bin_count, ...
    [2; 2; 1]);

end


function testIgnoresInvalidExamples(testCase)

examples = table();

examples.truth_material_purity = [0.3; 0.8];
examples.campaign_angular_entropy = [0.2; 0.5];
examples.truth_cs_center_m_s = [2.0; 3.0];
examples.campaign_frequency_hz = [200; 400];
examples.campaign_run_id = ["run_1"; "run_2"];

assigned = reqml.coverage.assignCoverageBins( ...
    examples, ...
    PurityEdges=[0.5 0.7 0.9 1.0], ...
    DiffusivityEdges=[0 0.4 0.7 1.0], ...
    SwsEdges=[1.5 2.5 3.5 4.1], ...
    FrequencyEdges=[199 350 450 601]);

summary = reqml.coverage.summarizeCoverage(assigned);

verifyEqual(testCase, height(summary), 1);
verifyEqual(testCase, summary.example_count, 1);
verifyEqual(testCase, summary.purity_bin, 2);
verifyEqual(testCase, summary.diffusivity_bin, 2);

end
