function result = buildDatasetFromConfig(config_file, options)
%BUILDDATASETFROMCONFIG Build, report, and gate the Cartesian Q0 dataset.

arguments
    config_file {mustBeTextScalar}
    options.CampaignRunsCsv {mustBeTextScalar} = ""
    options.Design struct = struct()
    options.SaveOutputs (1,1) logical = true
end

config_file=string(config_file);
config=jsondecode(fileread(config_file));
design=options.Design;
if isempty(fieldnames(design))
    design=reqml.homogeneous.materializeCartesianDesign(config);
end
repo_root=string(fileparts(fileparts(fileparts(fileparts( ...
    mfilename("fullpath"))))));
output_root=reqml.config.resolveWorkspacePath( ...
    string(config.paths.output_root),RepositoryRoot=repo_root);
campaign_csv=string(options.CampaignRunsCsv);
if strlength(campaign_csv)==0
    simulation_output_root=reqml.config.resolveWorkspacePath( ...
        string(config.paths.simulation_output_root),RepositoryRoot=repo_root);
    campaign_csv=fullfile(simulation_output_root, ...
        string(config.campaign_id),"campaign_runs.csv");
end
M_values=reqml.homogeneous.resolveReqMValues(config);
if numel(M_values)>1
    dataset=reqml.homogeneous.buildDualMDatasetFromCampaign(campaign_csv,config, ...
        SaveOutputs=options.SaveOutputs,OutputDirectory=fullfile(output_root,"dataset"));
else
    feat=reqml.config.default_feature_config("M",M_values, ...
        "cs_guess",double(config.req.cs_guess_m_s));
    dataset=reqml.datasets.build_dataset_from_campaign(campaign_csv,feat, ...
        DatasetId=string(config.campaign_id),CsGuessMPerS=double(config.req.cs_guess_m_s), ...
        WindowWavelengths=M_values,AutomaticHalfWindowStride=true, ...
        MinimumStridePixels=double(config.patch_sampling.minimum_stride_pixels), ...
        MaximumExamplesPerRun=resolve_target(config), ...
        ExampleSelectionSeedOffset=double(config.patch_sampling.selection_seed_offset), ...
        UseSampleParfor=logical(config.execution.use_sample_parfor), ...
        SaveOutputs=options.SaveOutputs,OutputDirectory=fullfile(output_root,"dataset"));
end
coverage=reqml.homogeneous.summarizeCoverage( ...
    design,campaign_csv,dataset.sample_summaries, ...
    TargetPatchesPerRun=double( ...
        resolve_target(config)),MValues=M_values);
validation=reqml.homogeneous.validateDataset(dataset,design,coverage,config);
paths=struct();
if options.SaveOutputs
    coverage_dir=fullfile(output_root,"coverage");
    if ~isfolder(coverage_dir), mkdir(coverage_dir); end
    paths.run_coverage=fullfile(coverage_dir,"run_coverage.csv");
    paths.condition_coverage=fullfile(coverage_dir,"condition_coverage.csv");
    paths.validation=fullfile(coverage_dir,"dataset_validation.csv");
    paths.patch_geometry_audit=fullfile(coverage_dir, ...
        "patch_geometry_audit.csv");
    paths.patch_geometry_mismatches=fullfile(coverage_dir, ...
        "patch_geometry_mismatches.csv");
    writetable(coverage.runs,paths.run_coverage);
    writetable(coverage.conditions,paths.condition_coverage);
    writetable(validation.checks,paths.validation);
    writetable(coverage.geometry_audit,paths.patch_geometry_audit);
    writetable(coverage.geometry_audit(~coverage.geometry_audit.geometry_match,:), ...
        paths.patch_geometry_mismatches);
end
result=struct("dataset",dataset,"coverage",coverage, ...
    "validation",validation,"design",design,"paths",paths);
end

function target=resolve_target(config)
if isfield(config.patch_sampling,"target_patches_per_run_per_M")
    target=double(config.patch_sampling.target_patches_per_run_per_M);
else
    target=double(config.patch_sampling.target_patches_per_run);
end
end
