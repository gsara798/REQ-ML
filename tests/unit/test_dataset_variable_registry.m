function tests = test_dataset_variable_registry
%TEST_DATASET_VARIABLE_REGISTRY Test central dataset role classification.

tests = functiontests(localfunctions);

end

function setupOnce(~)

root = fileparts(fileparts(fileparts( ...
    mfilename("fullpath"))));

addpath(fullfile(root, "src"));

end

function testClassifiesRolesAndTrainability(testCase)

examples = table();

examples.example_id = ["a"; "b"];
examples.cx = [3; 5];
examples.campaign_frequency_hz = [300; 500];
examples.REQ_M = [2; 3];
examples.M = [2; 3];
examples.REQ_cs_guess_m_s = [2.5; 3.5];
examples.REQ_Nbins_effective = [31; 61];
examples.GRID_dx_m = [0.2e-3; 0.3e-3];
examples.GRID_dz_m = [0.2e-3; 0.4e-3];
examples.REQ_dkx_rad_m = [100; 80];
examples.REQ_dkz_rad_m = [100; 60];
examples.SIM_f0 = [300; 500];
examples.SIM_cs_bg = [2; 4];
examples.truth_cs_center_m_s = [2; 4];
examples.q_target_from_center_truth = [0.7; 0.8];
examples.q_pred = [0.6; 0.75];
examples.radial_entropy = [0.1; 0.2];
examples.ang_entropy = [0.3; 0.4];
examples.target_definition = ...
    ["center_pixel_truth"; "center_pixel_truth"];
examples.notes = ["x"; "y"];

registry = ...
    reqml.schema.dataset_variable_registry(examples);

verify_role(testCase, registry, ...
    "example_id", "identifier", false);

verify_role(testCase, registry, ...
    "cx", "coordinate", false);

verify_role(testCase, registry, ...
    "campaign_frequency_hz", "metadata", true);

verify_role(testCase, registry, ...
    "REQ_M", "metadata", true);

verify_role(testCase, registry, ...
    "REQ_cs_guess_m_s", "metadata", true);

verify_role(testCase, registry, ...
    "REQ_Nbins_effective", "metadata", true);

verify_role(testCase, registry, ...
    "GRID_dx_m", "metadata", true);

verify_role(testCase, registry, ...
    "GRID_dz_m", "metadata", true);

verify_role(testCase, registry, ...
    "REQ_dkx_rad_m", "metadata", true);

verify_role(testCase, registry, ...
    "REQ_dkz_rad_m", "metadata", true);

verify_role(testCase, registry, ...
    "M", "diagnostic", false);

verify_role(testCase, registry, ...
    "SIM_f0", "diagnostic", false);

verify_role(testCase, registry, ...
    "SIM_cs_bg", "diagnostic", false);

verify_role(testCase, registry, ...
    "truth_cs_center_m_s", "truth", false);

verify_role(testCase, registry, ...
    "q_target_from_center_truth", "target", false);

verify_role(testCase, registry, ...
    "q_pred", "prediction", false);

verify_role(testCase, registry, ...
    "radial_entropy", "feature", true);

verify_role(testCase, registry, ...
    "ang_entropy", "feature", true);

verify_role(testCase, registry, ...
    "notes", "unregistered", false);

end

function verify_role( ...
        testCase, registry, name, role, trainable)

row = registry(registry.variable_name == name, :);

verifyEqual(testCase, height(row), 1);
verifyEqual(testCase, row.role, role);
verifyEqual(testCase, row.trainable, trainable);

end
