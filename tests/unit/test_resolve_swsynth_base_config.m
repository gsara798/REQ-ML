function tests = test_resolve_swsynth_base_config
%TEST_RESOLVE_SWSYNTH_BASE_CONFIG Test geometry-to-base resolution.

tests = functiontests(localfunctions);

end


function setupOnce(~)

root = fileparts(fileparts(fileparts( ...
    mfilename("fullpath"))));

addpath(fullfile(root, "src"));

end


function testResolvesAllSupportedFamilies(testCase)

mapping = make_mapping();

verifyEqual(testCase, ...
    reqml.campaigns.resolveSwsynthBaseConfig( ...
        "homogeneous", mapping), ...
    "homogeneous_base.json");

verifyEqual(testCase, ...
    reqml.campaigns.resolveSwsynthBaseConfig( ...
        "bilayer", mapping), ...
    "bilayer_base.json");

verifyEqual(testCase, ...
    reqml.campaigns.resolveSwsynthBaseConfig( ...
        "circular_inclusion", mapping), ...
    "circular_inclusion_base.json");

end


function testRejectsIncompleteMapping(testCase)

mapping = rmfield(make_mapping(), "bilayer");

verifyError(testCase, ...
    @() reqml.campaigns.resolveSwsynthBaseConfig( ...
        "bilayer", mapping), ...
    "reqml:InvalidSwsynthBaseConfigMapping");

end


function mapping = make_mapping()

mapping = struct();

mapping.homogeneous = ...
    "homogeneous_base.json";

mapping.bilayer = ...
    "bilayer_base.json";

mapping.circular_inclusion = ...
    "circular_inclusion_base.json";

end
