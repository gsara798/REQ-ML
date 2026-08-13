function tests = test_validate_adaptive_pilot_isolation
%TEST_VALIDATE_ADAPTIVE_PILOT_ISOLATION Test clean-output preflight checks.

tests = functiontests(localfunctions);

end


function setupOnce(testCase)

testCase.TestData.repository_root = string(fileparts(fileparts(fileparts( ...
    mfilename("fullpath")))));
addpath(fullfile(testCase.TestData.repository_root, "src"));

end


function testV3PilotConfigUsesIsolatedPaths(testCase)

campaign_id = "reqml_adaptive_scientific_4d_v3_analytic_bilayer_pilot";
config_file = fullfile(testCase.TestData.repository_root, "configs", ...
    "adaptive", campaign_id + ".json");
config = jsondecode(fileread(config_file));

verifyEqual(testCase, string(config.campaign_id), campaign_id);
verifyFalse(testCase, logical(config.execution.resume_existing_loop));
verifyEqual(testCase, double(config.execution.maximum_iterations), 10);
verifyEqual(testCase, string(config.planning.training_geometry_mode), ...
    "analytic_bilayer");
verifyEqual(testCase, string(config.bootstrap.geometry_families), "bilayer");
verifyEqual(testCase, string(config.paths.simulation_framework_root), ...
    "/Users/sara/local/shear-wave-simulation-framework");
verifyFalse(testCase, contains(string(config.paths.output_root), ...
    "reqml_adaptive_scientific_4d_v2"));
verifyFalse(testCase, contains(string(config.simulation.output_directory), ...
    "reqml_adaptive_scientific_4d_v2"));
verifyEqual(testCase, string(get_basename(config.paths.output_root)), campaign_id);
verifyEqual(testCase, string(get_basename( ...
    config.simulation.output_directory)), campaign_id);

end


function testV4DeficitCenterPilotConfigUsesIsolatedPaths(testCase)

campaign_id = ...
    "reqml_adaptive_scientific_4d_v4_analytic_bilayer_deficit_centers_pilot";
config_file = fullfile(testCase.TestData.repository_root, "configs", ...
    "adaptive", campaign_id + ".json");
config_text = string(fileread(config_file));
config = jsondecode(config_text);

verifyEqual(testCase, string(config.campaign_id), campaign_id);
verifyEqual(testCase, double(config.execution.maximum_iterations), 10);
verifyFalse(testCase, logical(config.execution.resume_existing_loop));
verifyTrue(testCase, logical(config.execution.resume_runs));
verifyTrue(testCase, logical(config.execution.use_sample_parfor));
verifyEqual(testCase, double(config.planning.maximum_conditions), 12);
verifyEqual(testCase, double(config.planning.realizations_per_condition), 2);
verifyEqual(testCase, string(config.planning.training_geometry_mode), ...
    "analytic_bilayer");
verifyEqual(testCase, string(config.bootstrap.geometry_families), "bilayer");
verifyEqual(testCase, string(config.center_selection.mode), ...
    "analytic_target_plus_deficit_aware_centers");
verifyEqual(testCase, double(config.center_selection.candidate_step_pixels), 2);
verifyEqual(testCase, ...
    double(config.center_selection.maximum_centers_per_run), 12);
verifyEqual(testCase, ...
    double(config.center_selection.maximum_centers_per_cell_per_run), 2);
verifyEqual(testCase, ...
    double(config.center_selection.minimum_center_separation_fraction), 0.75);
verifyEqual(testCase, string(config.paths.simulation_framework_root), ...
    "/Users/sara/local/shear-wave-simulation-framework");
verifyFalse(testCase, contains(config_text, ...
    "reqml_adaptive_scientific_4d_v2"));
verifyFalse(testCase, contains(config_text, ...
    "reqml_adaptive_scientific_4d_v3_analytic_bilayer_pilot"));
verifyEqual(testCase, string(get_basename(config.paths.output_root)), campaign_id);
verifyEqual(testCase, string(get_basename( ...
    config.simulation.output_directory)), campaign_id);

end


function testFinalCampaignConfigUsesProductionPoliciesAndIsolatedPaths(testCase)
campaign_id="reqml_adaptive_scientific_4d_final";
config_file=fullfile(testCase.TestData.repository_root,"configs", ...
    "adaptive",campaign_id+".json");
text=string(fileread(config_file)); config=jsondecode(text);
verifyEqual(testCase,string(config.campaign_id),campaign_id);
verifyEqual(testCase,double(config.execution.maximum_iterations),15);
verifyFalse(testCase,logical(config.execution.resume_existing_loop));
verifyEqual(testCase,string(config.center_selection.mode), ...
    "analytic_deficit_aware_final");
verifyEqual(testCase, ...
    double(config.center_selection.analytic_to_opportunistic_separation_fraction),.25);
verifyEqual(testCase, ...
    double(config.center_selection.different_cell_separation_fraction),.25);
verifyEqual(testCase, ...
    double(config.center_selection.same_cell_separation_fraction),.5);
verifyEqual(testCase,string(config.domain_policy.mode), ...
    "adaptive_for_center_packing");
verifyEqual(testCase,double(config.domain_policy.default_size_m(:))',[.05 .05]);
verifyEqual(testCase,double(config.domain_policy.expanded_size_m(:))',[.07 .07]);
verifyFalse(testCase,contains(text,"reqml_adaptive_scientific_4d_v2"));
verifyFalse(testCase,contains(text,"reqml_adaptive_scientific_4d_v3"));
verifyFalse(testCase,contains(text,"reqml_adaptive_scientific_4d_v4"));
verifyEqual(testCase,string(get_basename(config.paths.output_root)),campaign_id);
verifyEqual(testCase,string(get_basename(config.simulation.output_directory)), ...
    campaign_id);
end


function testRejectsExistingReqmlOutput(testCase)

[root, config_file, config] = make_fixture_config(testCase);
mkdir(config.paths.output_root);
write_config(config_file, config);

verifyError(testCase, @() ...
    reqml.campaigns.validateAdaptivePilotIsolation(config_file), ...
    "reqml:AdaptivePilotReqmlOutputExists");

clear root

end


function testRejectsSimulationOutputWithPriorData(testCase)

[root, config_file, config] = make_fixture_config(testCase);
mkdir(config.simulation.output_directory);
write_text(fullfile(config.simulation.output_directory, "campaign.csv"), ...
    "run_id");
write_config(config_file, config);

verifyError(testCase, @() ...
    reqml.campaigns.validateAdaptivePilotIsolation(config_file), ...
    "reqml:AdaptivePilotSimulationOutputConflict");

clear root

end


function testAllowsEmptySimulationOutputDirectory(testCase)

[root, config_file, config] = make_fixture_config(testCase);
mkdir(config.simulation.output_directory);
write_config(config_file, config);

report = reqml.campaigns.validateAdaptivePilotIsolation(config_file);

verifyTrue(testCase, report.safe_to_start);
verifyTrue(testCase, report.simulation_output_exists);
verifyFalse(testCase, report.simulation_output_has_entries);

clear root

end


function testRejectsResumeAndV2References(testCase)

[root, config_file, config] = make_fixture_config(testCase);
config.execution.resume_existing_loop = true;
write_config(config_file, config);

verifyError(testCase, @() ...
    reqml.campaigns.validateAdaptivePilotIsolation(config_file), ...
    "reqml:AdaptivePilotResumeEnabled");

config.execution.resume_existing_loop = false;
config.simulation.base_config_mapping = struct( ...
    "bilayer", "/tmp/reqml_adaptive_scientific_4d_v2/base.json");
write_config(config_file, config);

verifyError(testCase, @() ...
    reqml.campaigns.validateAdaptivePilotIsolation(config_file), ...
    "reqml:AdaptivePilotForbiddenCampaignPath");

clear root

end


function [root, config_file, config] = make_fixture_config(testCase)

root = string(testCase.applyFixture( ...
    matlab.unittest.fixtures.TemporaryFolderFixture).Folder);
campaign_id = "isolated_v3_pilot";

config = struct();
config.campaign_id = campaign_id;
config.paths = struct( ...
    "output_root", fullfile(root, "reqml", campaign_id), ...
    "simulation_framework_root", fullfile(root, "framework"));
config.simulation = struct( ...
    "output_directory", fullfile(root, "simulation", campaign_id));
config.execution = struct("resume_existing_loop", false);
config_file = fullfile(root, "config.json");

end


function write_config(path_value, config)

write_text(path_value, jsonencode(config, PrettyPrint=true));

end


function write_text(path_value, text_value)

parent = fileparts(path_value);
if strlength(string(parent)) > 0 && ~isfolder(parent)
    mkdir(parent);
end

file_id = fopen(path_value, "w");
cleanup = onCleanup(@() fclose(file_id));
fprintf(file_id, "%s", text_value);
clear cleanup

end


function name = get_basename(path_value)

[~, name, extension] = fileparts(path_value);
name = string(name) + string(extension);

end
