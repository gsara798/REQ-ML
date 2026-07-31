function tests = test_write_adaptive_batch
%TEST_WRITE_ADAPTIVE_BATCH Test grouped adaptive campaign artifacts.

tests = functiontests(localfunctions);

end


function setupOnce(~)

root = fileparts(fileparts(fileparts( ...
    mfilename("fullpath"))));

addpath(fullfile(root, "src"));

end


function testWritesOneCampaignPerGeometryFamily(testCase)

output_directory = string(tempname);
cleanup = onCleanup(@() cleanup_directory(output_directory));

conditions = [
    make_condition("cond_hom", "homogeneous")
    make_condition("cond_bil", "bilayer")
    make_condition("cond_inc", "circular_inclusion")
    ];

config = make_campaign_config();

paths = reqml.campaigns.writeAdaptiveBatch( ...
    conditions, ...
    config, ...
    OutputDirectory=output_directory, ...
    BatchId="batch_001", ...
    PlannerSeed=17001);

verifyTrue(testCase, isfile(paths.plan));

verifyEqual(testCase, ...
    height(paths.simulation_campaigns), ...
    3);

verifyTrue(testCase, ...
    all(isfile(paths.simulation_campaigns.path)));

verifyEqual(testCase, ...
    sort(paths.simulation_campaigns.geometry_family), ...
    sort([ ...
        "homogeneous"
        "bilayer"
        "circular_inclusion"
        ]));

for index = 1:height(paths.simulation_campaigns)
    campaign = jsondecode(fileread( ...
        paths.simulation_campaigns.path(index)));

    verifyEqual(testCase, ...
        string(campaign.base_config), ...
        paths.simulation_campaigns.base_config(index));

    verifyEqual(testCase, ...
        numel(campaign.runs), ...
        2);
end

clear cleanup

end


function testDoesNotMixBilayerAndCircleOverrides(testCase)

output_directory = string(tempname);
cleanup = onCleanup(@() cleanup_directory(output_directory));

conditions = [
    make_condition("cond_bil", "bilayer")
    make_condition("cond_inc", "circular_inclusion")
    ];

paths = reqml.campaigns.writeAdaptiveBatch( ...
    conditions, ...
    make_campaign_config(), ...
    OutputDirectory=output_directory, ...
    BatchId="batch_002", ...
    PlannerSeed=1);

bilayer_path = paths.simulation_campaigns.path( ...
    paths.simulation_campaigns.geometry_family == "bilayer");

circle_path = paths.simulation_campaigns.path( ...
    paths.simulation_campaigns.geometry_family == ...
        "circular_inclusion");

bilayer = jsondecode(fileread(bilayer_path));
circle = jsondecode(fileread(circle_path));

bilayer_paths = string( ...
    {bilayer.runs(1).overrides.path})';

circle_paths = string( ...
    {circle.runs(1).overrides.path})';

verifyTrue(testCase, ...
    ismember( ...
        "medium.objects[1].normal_angle_rad", ...
        bilayer_paths));

verifyFalse(testCase, ...
    ismember( ...
        "medium.objects[1].radius_m", ...
        bilayer_paths));

verifyTrue(testCase, ...
    ismember( ...
        "medium.objects[1].radius_m", ...
        circle_paths));

verifyFalse(testCase, ...
    ismember( ...
        "medium.objects[1].normal_angle_rad", ...
        circle_paths));

clear cleanup

end


function config = make_campaign_config()

root = "configs/swsynth/scientific/" + ...
    "reqml_eikonal_training_v1/";

config = struct();
config.backend = "swsynth";
config.campaign_name = "adaptive_test";

config.base_config_mapping = struct( ...
    "homogeneous", root + "homogeneous_base.json", ...
    "bilayer", root + "bilayer_base.json", ...
    "circular_inclusion", ...
        root + "circular_inclusion_base.json");

end


function condition = make_condition(id, family)

condition = struct();

condition.condition_id = id;
condition.realization_count = 2;
condition.seed = 12345 + strlength(id);

condition.geometry = struct( ...
    "family", family, ...
    "radius_m", 0.008, ...
    "center_xz_m", [0.02 0.03], ...
    "normal_angle_rad", 0.5, ...
    "offset_m", 0.025);

condition.material = struct( ...
    "background_cs_m_s", 2.0, ...
    "object_cs_m_s", 3.0);

condition.wavefield = struct( ...
    "frequency_hz", 400, ...
    "direction_count", 16, ...
    "in_plane_count", 4, ...
    "solid_angle_sr", pi);

condition.requested_coverage = struct();

end


function cleanup_directory(directory)

if isfolder(directory)
    rmdir(directory, "s");
end

end
