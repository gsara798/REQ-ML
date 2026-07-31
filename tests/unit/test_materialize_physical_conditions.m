function tests = test_materialize_physical_conditions
%TEST_MATERIALIZE_PHYSICAL_CONDITIONS Test backend-neutral materialization.

tests = functiontests(localfunctions);

end


function setupOnce(~)

root = fileparts(fileparts(fileparts( ...
    mfilename("fullpath"))));

addpath(fullfile(root, "src"));

end


function testMaterializesAllGeometryFamilies(testCase)

requests = make_requests();

conditions = ...
    reqml.campaigns.materializePhysicalConditions( ...
        requests, ...
        PlannerSeed=101);

verifyEqual(testCase, numel(conditions), 3);

geometry_families = strings(numel(conditions), 1);

for index = 1:numel(conditions)
    geometry_families(index) = ...
        string(conditions(index).geometry.family);
end

verifyEqual(testCase, ...
    geometry_families, ...
    ["homogeneous"; "bilayer"; "circular_inclusion"]);

verifyTrue(testCase, ...
    isnan(conditions(1).material.object_cs_m_s));

verifyTrue(testCase, ...
    isfinite(conditions(2).geometry.normal_angle_rad));

verifyTrue(testCase, ...
    isfinite(conditions(2).geometry.offset_m));

verifyTrue(testCase, ...
    isfinite(conditions(3).geometry.radius_m));

verifyTrue(testCase, ...
    all(isfinite(conditions(3).geometry.center_xz_m)));

verifyEqual(testCase, ...
    conditions(1).wavefield.direction_count, ...
    4);

verifyEqual(testCase, ...
    conditions(2).wavefield.direction_count, ...
    16);

verifyEqual(testCase, ...
    conditions(3).wavefield.direction_count, ...
    32);

end


function testMaterializationIsReproducible(testCase)

requests = make_requests();

a = reqml.campaigns.materializePhysicalConditions( ...
    requests, ...
    PlannerSeed=9001);

b = reqml.campaigns.materializePhysicalConditions( ...
    requests, ...
    PlannerSeed=9001);

verifyEqual(testCase, a, b);

end


function testDifferentPlannerSeedsChangeConditions(testCase)

requests = make_requests();

a = reqml.campaigns.materializePhysicalConditions( ...
    requests, ...
    PlannerSeed=100);

b = reqml.campaigns.materializePhysicalConditions( ...
    requests, ...
    PlannerSeed=200);

verifyNotEqual(testCase, ...
    [a.seed]', ...
    [b.seed]');

end


function requests = make_requests()

requests = repmat(struct( ...
    "condition_id", "", ...
    "realization_count", 2, ...
    "geometry_family", "", ...
    "field_regime", "", ...
    "target_sws_range_m_s", [2.0 2.5], ...
    "target_frequency_range_hz", [300 400], ...
    "purity_bin", 1, ...
    "purity_range", [0.5 0.7], ...
    "diffusivity_bin", 1, ...
    "diffusivity_range", [0 0.4], ...
    "deficit_score", 1.0), ...
    3, 1);

requests(1).condition_id = "cond_hom";
requests(1).geometry_family = "homogeneous";
requests(1).field_regime = "directional";

requests(2).condition_id = "cond_bil";
requests(2).geometry_family = "bilayer";
requests(2).field_regime = "intermediate";

requests(3).condition_id = "cond_inc";
requests(3).geometry_family = "circular_inclusion";
requests(3).field_regime = "broad";

end
