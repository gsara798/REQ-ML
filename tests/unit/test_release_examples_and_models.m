function tests = test_release_examples_and_models
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
root = string(fileparts(fileparts(fileparts(mfilename("fullpath")))));
addpath(fullfile(root, "src"));
testCase.TestData.root = root;
end

function testFieldRegimeAliases(testCase)
verifyEqual(testCase, reqml.examples.resolveFieldRegime("low").name, ...
    "directional");
verifyEqual(testCase, reqml.examples.resolveFieldRegime("mid").name, ...
    "intermediate");
verifyEqual(testCase, reqml.examples.resolveFieldRegime("high").name, ...
    "diffuse");
verifyError(testCase, @() reqml.examples.resolveFieldRegime("unknown"), ...
    "reqml:UnknownFieldRegime");
end

function testHomogeneousCampaignConstruction(testCase)
c = reqml.examples.buildSimulationCampaign("homogeneous", ...
    OutputDirectory="/tmp/reqml_example", Cs=2.5, FrequencyHz=500, ...
    FieldRegime="intermediate");
verifyEqual(testCase, c.backend, "swsynth");
verifyEqual(testCase, c.base_config, ...
    "configs/swsynth/scientific/reqml_q0_v2/homogeneous_base.json");
verifyEqual(testCase, override_value(c, "medium.background_cs_m_s"), 2.5);
verifyEqual(testCase, override_value(c, "wavefield.frequency_hz"), 500);
verifyEqual(testCase, override_value(c, "directions.count"), 16);
end

function testInclusionCampaignConstruction(testCase)
c = reqml.examples.buildSimulationCampaign("inclusion", ...
    OutputDirectory="/tmp/reqml_example", CsBackground=2, ...
    CsInclusion=3.2, InclusionRadiusMm=12, FieldRegime="diffuse");
verifyEqual(testCase, c.base_config, ...
    "configs/swsynth/scientific/reqml_q0_v2/inclusion_base.json");
verifyEqual(testCase, override_value(c, "medium.objects[1].cs_m_s"), 3.2);
verifyEqual(testCase, override_value(c, "medium.objects[1].radius_m"), 0.012);
verifyEqual(testCase, override_value(c, "directions.support.solid_angle_sr"), ...
    4*pi, AbsTol=1e-12);
end

function testExplicitAndEnvironmentModelResolution(testCase)
folder = string(testCase.applyFixture( ...
    matlab.unittest.fixtures.TemporaryFolderFixture).Folder);
explicit = fullfile(folder, "explicit.mat"); fclose(fopen(explicit, "w"));
[path, info] = reqml.models.resolveCurrentQ0Model( ...
    Model=explicit, RepositoryRoot=folder);
verifyEqual(testCase, path, explicit);
verifyEqual(testCase, info.source, "Model option");

environment = fullfile(folder, "environment.mat"); fclose(fopen(environment, "w"));
old = string(getenv("REQML_Q0_MODEL"));
cleanup = onCleanup(@() setenv("REQML_Q0_MODEL", old)); %#ok<NASGU>
setenv("REQML_Q0_MODEL", environment);
[path, info] = reqml.models.resolveCurrentQ0Model(RepositoryRoot=folder);
verifyEqual(testCase, path, environment);
verifyEqual(testCase, info.source, "REQML_Q0_MODEL");
end

function testMissingModelFailsClearly(testCase)
folder = string(testCase.applyFixture( ...
    matlab.unittest.fixtures.TemporaryFolderFixture).Folder);
old = string(getenv("REQML_Q0_MODEL"));
cleanup = onCleanup(@() setenv("REQML_Q0_MODEL", old)); %#ok<NASGU>
setenv("REQML_Q0_MODEL", "");
verifyError(testCase, @() reqml.models.resolveCurrentQ0Model( ...
    RepositoryRoot=folder), "reqml:Q0ModelNotFound");
end

function testLegacyEntriesMovedWithoutBrokenReferences(testCase)
legacy = fullfile(testCase.TestData.root, "archive", "legacy_v1");
verifyTrue(testCase, isfile(fullfile(legacy, "configs", "homogeneous", ...
    "homogeneous_cartesian_q0_v1.json")));
verifyFalse(testCase, isfile(fullfile(testCase.TestData.root, "configs", ...
    "homogeneous", "homogeneous_cartesian_q0_v1.json")));
verifyTrue(testCase, isfile(fullfile(testCase.TestData.root, "examples", ...
    "homogeneous", "run_example.m")));
verifyTrue(testCase, isfile(fullfile(testCase.TestData.root, "examples", ...
    "inclusion", "run_example.m")));
end

function value = override_value(campaign, path)
overrides = campaign.runs.overrides;
index = find(string({overrides.path}) == string(path), 1);
value = overrides(index).value;
end
