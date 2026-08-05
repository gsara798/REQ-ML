function tests = test_physical_condition_to_swsynth_runs
%TEST_PHYSICAL_CONDITION_TO_SWSYNTH_RUNS Test swsynth export.

tests = functiontests(localfunctions);

end


function setupOnce(~)

root = fileparts(fileparts(fileparts( ...
    mfilename("fullpath"))));

addpath(fullfile(root, "src"));

end


function testExportsHomogeneousCondition(testCase)

condition = make_condition("homogeneous");

runs = reqml.campaigns. ...
    physicalConditionToSwsynthRuns(condition);

verifyEqual(testCase, numel(runs), 2);

verifyEqual(testCase, ...
    string({runs.design_id})', ...
    ["cond_test_r001"; "cond_test_r002"]);

verifyEqual(testCase, ...
    [runs.realization_id]', ...
    [1; 2]);

verifyEqual(testCase, ...
    string({runs.condition_id})', ...
    ["cond_test"; "cond_test"]);

paths = string({runs(1).overrides.path})';

verifyTrue(testCase, ismember("seed", paths));
verifyTrue(testCase, ...
    ismember("wavefield.frequency_hz", paths));
verifyTrue(testCase, ...
    ismember("medium.background_cs_m_s", paths));

verifyTrue(testCase, ...
    ismember("domain.dx_m", paths));

verifyTrue(testCase, ...
    ismember("domain.dz_m", paths));

verifyEqual(testCase, ...
    extract_override_value( ...
        runs(1), ...
        "domain.dx_m"), ...
    0.00025, ...
    AbsTol=1e-15);

verifyEqual(testCase, ...
    extract_override_value( ...
        runs(1), ...
        "domain.dz_m"), ...
    0.00040, ...
    AbsTol=1e-15);

verifyFalse(testCase, ...
    any(startsWith(paths, "medium.objects")));

end


function testExportsBilayerGeometry(testCase)

condition = make_condition("bilayer");

runs = reqml.campaigns. ...
    physicalConditionToSwsynthRuns(condition);

paths = string({runs(1).overrides.path})';

verifyTrue(testCase, ...
    ismember("medium.objects[1].cs_m_s", paths));

verifyTrue(testCase, ...
    ismember("medium.objects[1].normal_angle_rad", paths));

verifyTrue(testCase, ...
    ismember("medium.objects[1].offset_m", paths));

verifyFalse(testCase, ...
    ismember("medium.objects[1].radius_m", paths));

end


function testExportsCircularInclusionGeometry(testCase)

condition = make_condition("circular_inclusion");

runs = reqml.campaigns. ...
    physicalConditionToSwsynthRuns(condition);

paths = string({runs(1).overrides.path})';

verifyTrue(testCase, ...
    ismember("medium.objects[1].cs_m_s", paths));

verifyTrue(testCase, ...
    ismember("medium.objects[1].radius_m", paths));

verifyTrue(testCase, ...
    ismember("medium.objects[1].center_xz_m", paths));

verifyFalse(testCase, ...
    ismember("medium.objects[1].offset_m", paths));

end


function testRealizationSeedsAreDeterministicAndDistinct(testCase)

condition = make_condition("homogeneous");

runs_a = reqml.campaigns. ...
    physicalConditionToSwsynthRuns(condition);

runs_b = reqml.campaigns. ...
    physicalConditionToSwsynthRuns(condition);

seeds_a = extract_seed_values(runs_a);
seeds_b = extract_seed_values(runs_b);

verifyEqual(testCase, seeds_a, seeds_b);
verifyNotEqual(testCase, seeds_a(1), seeds_a(2));

end



function testExportsAngularAxisWhenPresent(testCase)

condition = make_condition("homogeneous");
condition.wavefield.axis_xyz = [0.6 0 0.8];

runs = reqml.campaigns. ...
    physicalConditionToSwsynthRuns(condition);

paths = string({runs(1).overrides.path})';
index = find(paths == "directions.support.axis_xyz", 1);

verifyNotEmpty(testCase, index);
verifyEqual(testCase, ...
    double(runs(1).overrides(index).value), ...
    [0.6 0 0.8], ...
    AbsTol=1e-12);

end


function testLegacyConditionDoesNotExportAngularAxis(testCase)

condition = make_condition("homogeneous");

runs = reqml.campaigns. ...
    physicalConditionToSwsynthRuns(condition);

paths = string({runs(1).overrides.path})';

verifyFalse(testCase, ...
    ismember("directions.support.axis_xyz", paths));

end


function testRejectsInvalidAngularAxis(testCase)

condition = make_condition("homogeneous");
condition.wavefield.axis_xyz = [0 0 0];

verifyError(testCase, ...
    @() reqml.campaigns. ...
        physicalConditionToSwsynthRuns(condition), ...
    "reqml:InvalidSwsynthPhysicalCondition");

end



function value = extract_override_value(run, path_value)

paths = string({run.overrides.path})';
index = find(paths == string(path_value), 1);

if isempty(index)
    error("test:MissingOverride", ...
        "Override '%s' was not found.", ...
        path_value);
end

value = run.overrides(index).value;

end


function seeds = extract_seed_values(runs)

seeds = zeros(numel(runs), 1);

for index = 1:numel(runs)
    paths = string({runs(index).overrides.path})';
    seed_index = find(paths == "seed", 1);

    seeds(index) = ...
        runs(index).overrides(seed_index).value;
end

end


function condition = make_condition(family)

condition = struct();

condition.condition_id = "cond_test";
condition.realization_count = 2;
condition.seed = 12345;

condition.geometry = struct( ...
    "family", family, ...
    "radius_m", 0.008, ...
    "center_xz_m", [0.02 0.03], ...
    "normal_angle_rad", 0.5, ...
    "offset_m", 0.025);

condition.material = struct( ...
    "background_cs_m_s", 2.0, ...
    "object_cs_m_s", 3.0);

condition.discretization = struct( ...
    "dx_m", 0.00025, ...
    "dz_m", 0.00040);

condition.wavefield = struct( ...
    "frequency_hz", 400, ...
    "direction_count", 16, ...
    "in_plane_count", 4, ...
    "solid_angle_sr", pi);

condition.requested_coverage = struct();

end
