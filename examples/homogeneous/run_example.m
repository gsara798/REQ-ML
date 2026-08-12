% Homogeneous wavefield -> current REQ Q0 SWS map.
cs = 2.0;
f0 = 400;
field_regime = "directional"; % directional | intermediate | diffuse
M = 2;                       % 2 | 3

example_dir = fileparts(mfilename("fullpath"));
reqml_root = fileparts(fileparts(example_dir));
run(fullfile(reqml_root, "setup_reqml.m"));
simulation_root = string(getenv("SWSIM_ROOT"));
if strlength(simulation_root) == 0
    simulation_root = fullfile(fileparts(reqml_root), ...
        "shear-wave-simulation-framework");
end
addpath(fullfile(simulation_root, "src"));

output_root = fullfile(reqml_root, "outputs", "examples");
campaign_file = fullfile(output_root, "homogeneous_campaign.json");
campaign = reqml.examples.buildSimulationCampaign("homogeneous", ...
    OutputDirectory=output_root, Cs=cs, FrequencyHz=f0, ...
    FieldRegime=field_regime);
reqml.examples.writeCampaignJson(campaign_file, campaign);
report = simcampaigns.runCampaign(campaign_file, Resume=true, ContinueOnError=false);
sample_file = fullfile(report.runs(1).run_directory, "data", "wavefield_sample.mat");
result = reqml.predictSWS(sample_file, M=M);

figure; imagesc(result.x_mm, result.z_mm, result.cs_map);
axis image; colorbar; xlabel("x (mm)"); ylabel("z (mm)");
title(sprintf("REQ Q0 homogeneous SWS, M=%d", M));
