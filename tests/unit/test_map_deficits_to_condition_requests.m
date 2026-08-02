function tests = test_map_deficits_to_condition_requests
%TEST_MAP_DEFICITS_TO_CONDITION_REQUESTS Test deficit translation.

tests = functiontests(localfunctions);

end


function setupOnce(~)

root = fileparts(fileparts(fileparts( ...
    mfilename("fullpath"))));

addpath(fullfile(root, "src"));

end


function testMapsDeficitsToDeterministicRequests(testCase)

report = make_report();

requests = ...
    reqml.campaigns.mapDeficitsToConditionRequests( ...
        report, ...
        MaximumConditions=2, ...
        RealizationsPerCondition=3, ...
        PlannerSeed=11, ...
        ConditionIdPrefix="batch_test");

verifyEqual(testCase, numel(requests), 2);

verifyEqual(testCase, ...
    string({requests.condition_id})', ...
    ["batch_test_p01_d01_001"; ...
     "batch_test_p03_d03_002"]);

verifyEqual(testCase, ...
    requests(1).purity_range, ...
    [0.5, 0.7], ...
    AbsTol=1e-12);

verifyEqual(testCase, ...
    requests(2).diffusivity_range, ...
    [0.7, 1.0], ...
    AbsTol=1e-12);

verifyEqual(testCase, ...
    requests(1).geometry_family, ...
    "bilayer");

verifyEqual(testCase, ...
    requests(1).field_regime, ...
    "continuous_dnom");

verifyEqual(testCase, ...
    requests(2).field_regime, ...
    "continuous_dnom");

verifyEqual(testCase, ...
    [requests.realization_count]', ...
    [3; 3]);

end


function testReturnsEmptyWhenCoverageComplete(testCase)

report = make_report();
report.deficits = report.deficits([], :);

requests = ...
    reqml.campaigns.mapDeficitsToConditionRequests( ...
        report);

verifyEqual(testCase, numel(requests), 0);

end


function testPlannerSeedIsReproducible(testCase)

report = make_report();

requests_a = ...
    reqml.campaigns.mapDeficitsToConditionRequests( ...
        report, ...
        PlannerSeed=23);

requests_b = ...
    reqml.campaigns.mapDeficitsToConditionRequests( ...
        report, ...
        PlannerSeed=23);

verifyEqual(testCase, requests_a, requests_b);

end


function testPropagatesNominalAngularCoverageRange(testCase)

report = make_report();

requests = ...
    reqml.campaigns.mapDeficitsToConditionRequests( ...
        report, ...
        MaximumConditions=1, ...
        PlannerSeed=81);

verifyTrue(testCase, ...
    isfield(requests, ...
        "nominal_angular_coverage_range"));

verifyEqual(testCase, ...
    requests(1).nominal_angular_coverage_range, ...
    requests(1).diffusivity_range);

verifyEqual(testCase, ...
    string(requests(1).field_regime), ...
    "continuous_dnom");

end


function report = make_report()

deficits = table();

deficits.purity_bin = [1; 3];
deficits.diffusivity_bin = [1; 3];

deficits.purity_label = ...
    ["[0.5,0.7)"; "[0.9,1]"];

deficits.diffusivity_label = ...
    ["[0,0.4)"; "[0.7,1]"];

deficits.example_deficit = [400; 200];
deficits.independent_run_deficit = [4; 2];
deficits.sws_bin_deficit = [2; 1];
deficits.frequency_bin_deficit = [2; 1];
deficits.independent_condition_deficit = [3; 1];
deficits.geometry_seed_deficit = [0; 0];
deficits.deficit_score = [3.2; 1.4];

report = struct();
report.deficits = deficits;

report.config = struct();
report.config.purity_edges = ...
    [0.5 0.7 0.9 1.0];

report.config.diffusivity_edges = ...
    [0 0.4 0.7 1.0];

report.config.sws_edges = ...
    [1.5 2.5 3.5 4.1];

report.config.frequency_edges = ...
    [199 350 450 601];

end
