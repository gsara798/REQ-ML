function tests = test_assess_req_readiness
%TEST_ASSESS_REQ_READINESS Test REQ-specific field readiness.

tests = functiontests(localfunctions);

end

function setupOnce(~)

root = fileparts(fileparts(fileparts( ...
    mfilename("fullpath"))));

addpath(fullfile(root, "src"));

end

function testValidFieldPasses(testCase)

data = sample_data(30, 30);

report = reqml.integration.assess_req_readiness( ...
    data, ...
    CsGuessMPerS=3.0, ...
    WindowWavelengths=2.0, ...
    MinimumPlacementsPerAxis=5);

verifyTrue(testCase, report.valid);
verifyEqual(testCase, report.window_points_x, 25);
verifyEqual(testCase, report.window_points_z, 25);
verifyEqual(testCase, report.placements_x, 6);
verifyEqual(testCase, report.placements_z, 6);
verifyTrue(testCase, contains(report.summary, "REQ-ready=1"));

end

function testInsufficientWindowPlacementsFails(testCase)

data = sample_data(27, 27);

report = reqml.integration.assess_req_readiness( ...
    data, ...
    CsGuessMPerS=3.0, ...
    WindowWavelengths=2.0, ...
    MinimumPlacementsPerAxis=5);

verifyFalse(testCase, report.valid);

check_names = string([report.checks.name]);

x_index = find(check_names == "minimum_x_placements", 1);
z_index = find(check_names == "minimum_z_placements", 1);

verifyFalse(testCase, report.checks(x_index).pass);
verifyFalse(testCase, report.checks(z_index).pass);

end

function testZeroEnergyFails(testCase)

data = sample_data(30, 30);
data.wavefield_zx(:) = 0;

report = reqml.integration.assess_req_readiness(data);

verifyFalse(testCase, report.valid);

check_names = string([report.checks.name]);
index = find(check_names == "nonzero_wavefield_energy", 1);

verifyFalse(testCase, report.checks(index).pass);
verifyEqual(testCase, report.field_energy, 0);

end

function testRejectsInvalidParameters(testCase)

data = sample_data(30, 30);

verifyError(testCase, ...
    @() reqml.integration.assess_req_readiness( ...
        data, CsGuessMPerS=0), ...
    "reqml:InvalidReqReadinessParameters");

verifyError(testCase, ...
    @() reqml.integration.assess_req_readiness( ...
        data, WindowWavelengths=0), ...
    "reqml:InvalidReqReadinessParameters");

verifyError(testCase, ...
    @() reqml.integration.assess_req_readiness( ...
        data, MinimumPlacementsPerAxis=2.5), ...
    "reqml:InvalidReqReadinessParameters");

end

function data = sample_data(Nz, Nx)

data = struct();
data.wavefield_zx = complex(ones(Nz, Nx), 0.25);
data.dx_m = 0.5e-3;
data.dz_m = 0.5e-3;
data.frequency_hz = 500;

end
