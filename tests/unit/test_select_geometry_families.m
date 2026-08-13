function tests = test_select_geometry_families
%TEST_SELECT_GEOMETRY_FAMILIES Test geometry diversity selection.

tests = functiontests(localfunctions);

end


function setupOnce(~)

root = fileparts(fileparts(fileparts( ...
    mfilename("fullpath"))));

addpath(fullfile(root, "src"));

end


function testSelectsUnderrepresentedEligibleFamily(testCase)

request = make_request(1, [0.5 0.7], 1);

examples = make_history();

selected = reqml.campaigns.selectGeometryFamilies( ...
    request, ...
    examples, ...
    PlannerSeed=1);

verifyEqual(testCase, ...
    selected.geometry_family, ...
    "circular_inclusion");

verifyEqual(testCase, ...
    selected.geometry_candidates, ...
    ["bilayer"; "circular_inclusion"]);

verifyEqual(testCase, ...
    selected.geometry_historical_run_counts, ...
    [2; 0]);

end


function testIgnoresHistoryFromOtherFiveDimensionalCells(testCase)

request = make_request(1, [0.5 0.7], 1);

examples = make_history();

extra = examples(1, :);
extra.coverage_sws_bin = 2;
extra.coverage_frequency_bin = 2;
extra.coverage_discretization_bin = 3;
extra.campaign_geometry_family = "circular_inclusion";
extra.campaign_run_id = "other_cell_run";

examples = [examples; extra];

selected = reqml.campaigns.selectGeometryFamilies( ...
    request, ...
    examples, ...
    PlannerSeed=1);

verifyEqual(testCase, ...
    selected.geometry_historical_run_counts, ...
    [2; 0]);

verifyEqual(testCase, ...
    selected.geometry_family, ...
    "circular_inclusion");

end


function testAllowsHomogeneousOnlyForPurePatchRequests(testCase)

request = make_request(3, [0.98 1.0], 3);

examples = make_history();

selected = reqml.campaigns.selectGeometryFamilies( ...
    request, ...
    examples, ...
    PlannerSeed=1);

verifyTrue(testCase, ...
    ismember("homogeneous", ...
        selected.geometry_candidates));

verifyEqual(testCase, ...
    selected.geometry_family, ...
    "homogeneous");

end


function testDoesNotAllowHomogeneousForMixedPatches(testCase)

request = make_request(2, [0.7 0.9], 2);

selected = reqml.campaigns.selectGeometryFamilies( ...
    request, ...
    make_history(), ...
    PlannerSeed=5);

verifyFalse(testCase, ...
    ismember("homogeneous", ...
        selected.geometry_candidates));

end


function testCountsRunsOnlyWithinMatchingFiveDimensionalCell(testCase)

request = make_request(1, [0.5 0.7], 1);

examples = make_history();

matching = examples(1, :);
matching.campaign_geometry_family = ...
    "circular_inclusion";
matching.campaign_run_id = ...
    "matching_inclusion_run";

examples = [examples; matching];

selected = reqml.campaigns.selectGeometryFamilies( ...
    request, ...
    examples, ...
    PlannerSeed=1);

verifyEqual(testCase, ...
    selected.geometry_historical_run_counts, ...
    [2; 1]);

verifyEqual(testCase, ...
    selected.geometry_family, ...
    "circular_inclusion");

end


function testSelectionIsReproducible(testCase)

request = make_request(1, [0.5 0.7], 1);
examples = make_history();

a = reqml.campaigns.selectGeometryFamilies( ...
    request, examples, PlannerSeed=31);

b = reqml.campaigns.selectGeometryFamilies( ...
    request, examples, PlannerSeed=31);

verifyEqual(testCase, a, b);

end


function testAnalyticTrainingModeSelectsOnlyBilayer(testCase)

request = make_request(3, [0.9 0.98], 2);

selected = reqml.campaigns.selectGeometryFamilies( ...
    request, make_history(), ...
    PlannerSeed=1, ...
    TrainingGeometryMode="analytic_bilayer");

verifyEqual(testCase, selected.geometry_family, "bilayer");
verifyEqual(testCase, selected.geometry_candidates, "bilayer");
verifyEqual(testCase, selected.geometry_selection_basis, ...
    "analytic_bilayer_training_mode");

end


function request = make_request( ...
        purity_bin, purity_range, diffusivity_bin)

request = struct();

request.condition_id = "request_001";
request.sws_bin = 1;
request.frequency_bin = 1;
request.purity_bin = purity_bin;
request.purity_range = purity_range;
request.diffusivity_bin = diffusivity_bin;
request.diffusivity_range = [0 0.4];
request.discretization_bin = 1;
request.target_grid_spacing_m = ...
    [0.25e-3 0.25e-3];

request.geometry_family = "";
request.field_regime = "directional";

request.target_sws_range_m_s = [2.0 2.5];
request.target_frequency_range_hz = [300 400];

request.realization_count = 2;
request.deficit_score = 1.0;

end


function examples = make_history()

examples = table();

examples.coverage_sws_bin = [1; 1; 1];
examples.coverage_frequency_bin = [1; 1; 1];
examples.coverage_purity_bin = [1; 1; 3];
examples.coverage_diffusivity_bin = [1; 1; 3];
examples.coverage_discretization_bin = [1; 1; 1];
examples.coverage_valid = true(3, 1);

examples.campaign_geometry_family = [
    "bilayer"
    "bilayer"
    "bilayer"
    ];

examples.campaign_run_id = [
    "run_1"
    "run_2"
    "run_3"
    ];

end
