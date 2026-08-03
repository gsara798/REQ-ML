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


for index = 1:numel(conditions)
    requested = ...
        conditions(index).requested_coverage;

    verifyEqual(testCase, ...
        requested.sws_bin, ...
        requests(index).sws_bin);

    verifyEqual(testCase, ...
        requested.frequency_bin, ...
        requests(index).frequency_bin);

    verifyEqual(testCase, ...
        requested.sws_range_m_s, ...
        requests(index).target_sws_range_m_s);

    verifyEqual(testCase, ...
        requested.frequency_range_hz, ...
        requests(index).target_frequency_range_hz);

    verifyEqual(testCase, ...
        requested.purity_bin, ...
        requests(index).purity_bin);

    verifyEqual(testCase, ...
        requested.diffusivity_bin, ...
        requests(index).diffusivity_bin);
end

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

target_ranges = [
    0.00 0.05
    0.20 0.40
    0.70 1.00
    ];

for index = 1:numel(conditions)
    field = conditions(index).wavefield;

    reconstructed = ...
        (field.direction_count / ...
            field.maximum_direction_count) * ...
        (field.solid_angle_sr / (4*pi));

    verifyEqual(testCase, ...
        reconstructed, ...
        field.nominal_angular_coverage, ...
        AbsTol=1e-12);

    verifyGreaterThanOrEqual(testCase, ...
        field.nominal_angular_coverage, ...
        target_ranges(index, 1));

    verifyLessThanOrEqual(testCase, ...
        field.nominal_angular_coverage, ...
        target_ranges(index, 2));

    verifyEqual(testCase, ...
        field.in_plane_count, ...
        min(field.direction_count, ...
            max(1, round(sqrt(field.direction_count)))));
end

end


function testBilayerPurityControlsInterfaceDistance(testCase)

requests = make_requests();

low_purity = requests(2);
low_purity.condition_id = "bilayer_low_purity";
low_purity.purity_bin = 1;
low_purity.purity_range = [0.5 0.7];

high_purity = requests(2);
high_purity.condition_id = "bilayer_high_purity";
high_purity.purity_bin = 3;
high_purity.purity_range = [0.9 0.98];

conditions = ...
    reqml.campaigns.materializePhysicalConditions( ...
        [low_purity; high_purity], ...
        PlannerSeed=5001);

distances = zeros(2,1);

for index = 1:2
    angle = conditions(index).geometry.normal_angle_rad;

    normal = [
        cos(angle)
        sin(angle)
        ];

    center = [0.025; 0.025];

    center_projection = dot(normal, center);

    distances(index) = abs( ...
        conditions(index).geometry.offset_m - ...
        center_projection);
end

verifyGreaterThan(testCase, ...
    distances(2), ...
    distances(1));

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
    "sws_bin", 1, ...
    "frequency_bin", 1, ...
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
requests(1).diffusivity_bin = 1;
requests(1).diffusivity_range = [0.00 0.05];
requests(1).nominal_angular_coverage_range = ...
    [0.00 0.05];

requests(2).condition_id = "cond_bil";
requests(2).geometry_family = "bilayer";
requests(2).field_regime = "intermediate";
requests(2).diffusivity_bin = 2;
requests(2).diffusivity_range = [0.20 0.40];
requests(2).nominal_angular_coverage_range = ...
    [0.20 0.40];

requests(3).condition_id = "cond_inc";
requests(3).geometry_family = "circular_inclusion";
requests(3).field_regime = "broad";
requests(3).diffusivity_bin = 3;
requests(3).diffusivity_range = [0.70 1.00];
requests(3).nominal_angular_coverage_range = ...
    [0.70 1.00];

end
