function tests = test_analytic_plane_spherical_design
%TEST_ANALYTIC_PLANE_SPHERICAL_DESIGN Validate the fixed diagnostic design.
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
root = fileparts(fileparts(fileparts(mfilename("fullpath"))));
addpath(fullfile(root, "src"));
config_file = fullfile(root, "configs", "validation", ...
    "reqml_analytic_plane_spherical_q0_v1.json");
testCase.TestData.config = jsondecode(fileread(config_file));
end

function testExactlyTwelveUniqueConditions(testCase)
[campaign, design] = build_design(testCase);
verifyEqual(testCase, height(design), 12);
verifyEqual(testCase, numel(campaign.runs), 12);
verifyEqual(testCase, numel(unique(design.design_id)), 12);
end

function testSphericalSourceDirectionAndRadius(testCase)
[~, design] = build_design(testCase);
spherical = design.propagation_model == "spherical_wave";
verifyEqual(testCase, design.source_radius_m, 0.05*ones(12,1), ...
    AbsTol=eps);
dot_product = design.direction_x(spherical).*design.explicit_x(spherical) + ...
    design.direction_y(spherical).*design.explicit_y(spherical) + ...
    design.direction_z(spherical).*design.explicit_z(spherical);
verifyEqual(testCase, dot_product, -ones(nnz(spherical),1), ...
    AbsTol=1e-12);
center = [0.025 0 0.025];
source = [design.source_x_m(spherical), design.source_y_m(spherical), ...
    design.source_z_m(spherical)];
verifyEqual(testCase, vecnorm(source-center,2,2), ...
    0.05*ones(nnz(spherical),1), AbsTol=1e-12);
end

function testDecayExponentsAreFixed(testCase)
[~, design] = build_design(testCase);
verifyEqual(testCase, unique(design.geometric_decay_exponent( ...
    design.propagation_condition=="plane")), 0);
verifyEqual(testCase, unique(design.geometric_decay_exponent( ...
    design.propagation_condition=="spherical_nospread")), 0);
verifyEqual(testCase, unique(design.geometric_decay_exponent( ...
    design.propagation_condition=="spherical_spread")), 1);
end

function testNoTrainingOrLegacyDependency(testCase)
function_file = which("reqml.analysis.buildAnalyticPlaneSphericalCampaign");
content = lower(fileread(function_file));
verifyFalse(testCase, contains(content, "test53"));
verifyFalse(testCase, contains(content, "train"));
end

function [campaign, design] = build_design(testCase)
[campaign, design] = reqml.analysis.buildAnalyticPlaneSphericalCampaign( ...
    testCase.TestData.config, string(tempname));
end
