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
output_root=resolve_path(string(config.paths.output_root),repo_root);
campaign_csv=string(options.CampaignRunsCsv);
if strlength(campaign_csv)==0
    campaign_csv=fullfile(string(config.paths.simulation_output_root), ...
        string(config.campaign_id),"campaign_runs.csv");
end
feat=reqml.config.default_feature_config( ...
    "M",double(config.req.M),"cs_guess",double(config.req.cs_guess_m_s));
dataset=reqml.datasets.build_dataset_from_campaign(campaign_csv,feat, ...
    DatasetId=string(config.campaign_id), ...
    CsGuessMPerS=double(config.req.cs_guess_m_s), ...
    WindowWavelengths=double(config.req.M), ...
    AutomaticHalfWindowStride=true, ...
    MinimumStridePixels=double(config.patch_sampling.minimum_stride_pixels), ...
    MaximumExamplesPerRun=double( ...
        config.patch_sampling.target_patches_per_run), ...
    ExampleSelectionSeedOffset=double( ...
        config.patch_sampling.selection_seed_offset), ...
    UseSampleParfor=logical(config.execution.use_sample_parfor), ...
    SaveOutputs=options.SaveOutputs, ...
    OutputDirectory=fullfile(output_root,"dataset"));
coverage=reqml.homogeneous.summarizeCoverage( ...
    design,campaign_csv,dataset.sample_summaries, ...
    TargetPatchesPerRun=double( ...
        config.patch_sampling.target_patches_per_run));
validation=reqml.homogeneous.validateDataset(dataset,design,coverage,config);
paths=struct();
if options.SaveOutputs
    coverage_dir=fullfile(output_root,"coverage");
    if ~isfolder(coverage_dir), mkdir(coverage_dir); end
    paths.run_coverage=fullfile(coverage_dir,"run_coverage.csv");
    paths.condition_coverage=fullfile(coverage_dir,"condition_coverage.csv");
    paths.validation=fullfile(coverage_dir,"dataset_validation.csv");
    writetable(coverage.runs,paths.run_coverage);
    writetable(coverage.conditions,paths.condition_coverage);
    writetable(validation.checks,paths.validation);
end
result=struct("dataset",dataset,"coverage",coverage, ...
    "validation",validation,"design",design,"paths",paths);
end


function value=resolve_path(value,root)
if startsWith(value,"${REPOSITORY_ROOT}/")
    value=fullfile(root,extractAfter(value,"${REPOSITORY_ROOT}/"));
end
end
