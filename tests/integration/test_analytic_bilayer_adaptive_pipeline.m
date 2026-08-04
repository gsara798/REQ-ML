function tests = test_analytic_bilayer_adaptive_pipeline
%TEST_ANALYTIC_BILAYER_ADAPTIVE_PIPELINE Test planning artifact integration.

tests = functiontests(localfunctions);

end


function setupOnce(~)

root = fileparts(fileparts(fileparts( ...
    mfilename("fullpath"))));
addpath(fullfile(root, "src"));

end


function testMaterializesAndWritesAnalyticPurityMetadata(testCase)

output_directory = string(tempname);
cleanup = onCleanup(@() cleanup_directory(output_directory));

result = reqml.campaigns.planNextAdaptiveBatch( ...
    make_coverage_report(), ...
    make_campaign_config(), ...
    OutputDirectory=output_directory, ...
    BatchId="analytic_integration", ...
    PlannerSeed=61001, ...
    MaximumConditions=1, ...
    RealizationsPerCondition=1);

verifyTrue(testCase, result.batch_required);
verifyEqual(testCase, result.condition_count, 1);
verifyEqual(testCase, ...
    result.selected_requests.geometry_family, "bilayer");

condition = result.physical_conditions;
control = condition.geometry_control;

verifyEqual(testCase, condition.geometry.family, "bilayer");
verifyEqual(testCase, control.geometry_control_mode, ...
    "analytic_bilayer");
verifyEqual(testCase, control.requested_purity_lower, 0.9);
verifyEqual(testCase, control.requested_purity_upper, 0.98);
verifyGreaterThanOrEqual(testCase, ...
    control.predicted_discrete_purity, 0.9);
verifyLessThan(testCase, ...
    control.predicted_discrete_purity, 0.98);
verifyEqual(testCase, ...
    control.selected_patch_center_indices_xz, [51 51]);
verifyEqual(testCase, control.patch_size_pixels(1), ...
    control.patch_size_pixels(2));
verifyEqual(testCase, mod(control.patch_size_pixels(1), 2), 1);

plan = jsondecode(fileread(result.paths.plan));
persisted = plan.physical_conditions.geometry_control;

verifyEqual(testCase, ...
    string(persisted.geometry_control_mode), ...
    "analytic_bilayer");
verifyEqual(testCase, ...
    double(persisted.requested_purity_lower), 0.9);
verifyEqual(testCase, ...
    double(persisted.requested_purity_upper), 0.98);
verifyEqual(testCase, ...
    double(persisted.interface_position_m), ...
    double(condition.geometry.offset_m));

campaign_file = ...
    result.paths.simulation_campaigns.path(1);
campaign = jsondecode(fileread(campaign_file));
overrides = campaign.runs.overrides;
paths = string({overrides.path});
offset_override = overrides( ...
    paths == "medium.objects[1].offset_m");

verifyEqual(testCase, ...
    double(offset_override.value), ...
    control.interface_position_m);

clear cleanup

end


function report = make_coverage_report()

deficits = table();
deficits.sws_bin = 1;
deficits.frequency_bin = 1;
deficits.purity_bin = 3;
deficits.diffusivity_bin = 2;
deficits.purity_label = "[0.9,0.98)";
deficits.diffusivity_label = "[0.01,0.05)";
deficits.example_deficit = 4;
deficits.independent_run_deficit = 1;
deficits.independent_condition_deficit = 1;
deficits.geometry_seed_deficit = 0;
deficits.deficit_score = 3;

report = struct();
report.deficits = deficits;
report.config = struct( ...
    "purity_edges", [0.5 0.7 0.9 0.98 1.0], ...
    "diffusivity_edges", [0 0.01 0.05 0.2 0.5 1.0], ...
    "sws_edges", [1.5 2.0 2.5 3.0 3.5 4.0], ...
    "frequency_edges", [199 250 350 450 550 601]);

assigned = table();
assigned.coverage_purity_bin = zeros(0,1);
assigned.coverage_diffusivity_bin = zeros(0,1);
assigned.coverage_valid = false(0,1);
assigned.campaign_geometry_family = strings(0,1);
assigned.campaign_run_id = strings(0,1);
report.assigned_examples = assigned;

end


function config = make_campaign_config()

config = struct();
config.backend = "swsynth";
config.campaign_name = "analytic_integration";
config.training_geometry_mode = "analytic_bilayer";
config.base_config_mapping = struct( ...
    "homogeneous", "/tmp/homogeneous.json", ...
    "bilayer", "/tmp/bilayer.json", ...
    "circular_inclusion", "/tmp/inclusion.json");
config.output = struct("directory", "/tmp/analytic_integration");
config.analytic_bilayer = struct( ...
    "domain_size_m", [0.05 0.05], ...
    "grid_spacing_m", [0.0005 0.0005], ...
    "patch_window_wavelengths", 3, ...
    "cs_guess_m_s", 3, ...
    "selected_patch_center_indices_xz", [51 51], ...
    "interface_orientation", "x", ...
    "minimum_domain_margin_pixels", 0);

end


function cleanup_directory(path_value)

if isfolder(path_value)
    rmdir(path_value, "s");
end

end
