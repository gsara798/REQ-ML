function tests = test_summarize_requested_vs_achieved
%TEST_SUMMARIZE_REQUESTED_VS_ACHIEVED Test planner outcome reporting.

tests = functiontests(localfunctions);

end


function setupOnce(~)

root = fileparts(fileparts(fileparts( ...
    mfilename("fullpath"))));

addpath(fullfile(root, "src"));

end


function testSummarizesRequestedAndMeasuredCells(testCase)

examples = make_examples();
plan = make_plan();

summary = reqml.coverage.summarizeRequestedVsAchieved( ...
    examples, ...
    plan);

verifyEqual(testCase, height(summary), 2);

row_a = summary(summary.condition_id == "condition_a", :);
row_b = summary(summary.condition_id == "condition_b", :);

verifyEqual(testCase, row_a.patch_count, 3);
verifyEqual(testCase, row_a.valid_patch_count, 3);
verifyEqual(testCase, row_a.requested_cell_patch_count, 2);
verifyTrue(testCase, row_a.requested_cell_hit);

verifyEqual(testCase, row_a.achieved_cells, ...
    "s01_f01_p01_d01,s02_f02_p02_d02");

verifyEqual(testCase, row_a.dominant_purity_bin, 1);
verifyEqual(testCase, row_a.dominant_diffusivity_bin, 1);
verifyEqual(testCase, row_a.dominant_cell_fraction, 2/3, ...
    AbsTol=1e-12);

verifyEqual(testCase, row_a.geometry_control_mode, ...
    "analytic_bilayer");
verifyEqual(testCase, row_a.target_purity, 0.6);
verifyEqual(testCase, row_a.predicted_discrete_purity, 0.61);
verifyEqual(testCase, ...
    row_a.predicted_vs_achieved_purity_error, ...
    median([0.55 0.62 0.75]) - 0.61, ...
    AbsTol=1e-12);

verifyEqual(testCase, row_b.patch_count, 2);
verifyEqual(testCase, row_b.requested_cell_patch_count, 0);
verifyFalse(testCase, row_b.requested_cell_hit);

verifyEqual(testCase, row_b.dominant_purity_bin, 4);
verifyEqual(testCase, row_b.dominant_diffusivity_bin, 2);

end


function testReportsConditionWithNoPatches(testCase)

examples = make_examples();
plan = make_plan();

plan.physical_conditions(3) = ...
    plan.physical_conditions(2);

plan.physical_conditions(3).condition_id = ...
    "condition_missing";

summary = reqml.coverage.summarizeRequestedVsAchieved( ...
    examples, ...
    plan);

missing = summary( ...
    summary.condition_id == "condition_missing", :);

verifyEqual(testCase, missing.patch_count, 0);
verifyEqual(testCase, missing.valid_patch_count, 0);
verifyFalse(testCase, missing.requested_cell_hit);
verifyEqual(testCase, missing.achieved_cells, "");

end


function examples = make_examples()

examples = table();

examples.campaign_condition_id = [
    "condition_a"
    "condition_a"
    "condition_a"
    "condition_b"
    "condition_b"
    ];

examples.coverage_valid = true(5,1);

examples.coverage_purity_bin = [
    1
    1
    2
    4
    4
    ];

examples.coverage_sws_bin = [1; 1; 2; 3; 3];
examples.coverage_frequency_bin = [1; 1; 2; 3; 3];

examples.coverage_diffusivity_bin = [
    1
    1
    2
    2
    2
    ];

examples.truth_material_purity = [
    0.55
    0.62
    0.75
    0.99
    1.00
    ];

examples.campaign_angular_entropy = [
    0.20
    0.25
    0.55
    0.50
    0.52
    ];

end


function plan = make_plan()

condition_a = make_condition( ...
    "condition_a", ...
    "bilayer", ...
    1, ...
    [0.5 0.7], ...
    1, ...
    [0 0.4]);

condition_b = make_condition( ...
    "condition_b", ...
    "circular_inclusion", ...
    3, ...
    [0.9 0.98], ...
    3, ...
    [0.7 1.0]);

plan = struct();
plan.physical_conditions = [condition_a; condition_b];

end


function condition = make_condition( ...
        condition_id, family, ...
        purity_bin, purity_range, ...
        diffusivity_bin, diffusivity_range)

condition = struct();

condition.condition_id = condition_id;

condition.geometry = struct( ...
    "family", family);

condition.geometry_control = struct( ...
    "geometry_control_mode", "analytic_bilayer", ...
    "target_purity", 0.6, ...
    "predicted_discrete_purity", 0.61, ...
    "interface_offset_pixels", 6, ...
    "interface_offset_m", 0.003, ...
    "interface_position_m", 0.028, ...
    "selected_patch_center_indices_xz", [51 51], ...
    "selected_patch_center_m", [0.025 0.025], ...
    "dominant_material_side", "negative");

condition.material = struct( ...
    "background_cs_m_s", 2.5, ...
    "object_cs_m_s", 3.5);

condition.wavefield = struct( ...
    "frequency_hz", 400, ...
    "direction_count", 4, ...
    "in_plane_count", 2, ...
    "solid_angle_sr", 0.5);

condition.requested_coverage = struct( ...
    "sws_bin", purity_bin, ...
    "frequency_bin", purity_bin, ...
    "purity_bin", purity_bin, ...
    "purity_range", purity_range, ...
    "diffusivity_bin", diffusivity_bin, ...
    "diffusivity_range", diffusivity_range, ...
    "deficit_score", 1);

end
