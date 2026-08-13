function dataset=buildDualMDatasetFromCampaign(campaign_csv,config,options)
%BUILDDUALMDATASETFROMCAMPAIGN Extract M=2 and M=3 from each wavefield once.
% Physical samples are reused across analysis M values; simulations are not.

arguments
    campaign_csv {mustBeTextScalar}
    config (1,1) struct
    options.SaveOutputs (1,1) logical = true
    options.OutputDirectory {mustBeTextScalar} = ""
end
M_values=reqml.homogeneous.resolveReqMValues(config);
parts=cell(numel(M_values),1); summaries=cell(numel(M_values),1);
target=resolve_target(config);
for index=1:numel(M_values)
    M=M_values(index);
    feat=reqml.config.default_feature_config("M",M, ...
        "cs_guess",double(config.req.cs_guess_m_s));
    current=reqml.datasets.build_dataset_from_campaign(campaign_csv,feat, ...
        DatasetId=string(config.campaign_id)+"_M"+string(M), ...
        CsGuessMPerS=double(config.req.cs_guess_m_s),WindowWavelengths=M, ...
        AutomaticHalfWindowStride=true, ...
        MinimumStridePixels=double(config.patch_sampling.minimum_stride_pixels), ...
        MaximumExamplesPerRun=target, ...
        ExampleSelectionSeedOffset=double(config.patch_sampling.selection_seed_offset)+1000*M, ...
        UseSampleParfor=logical(config.execution.use_sample_parfor), ...
        SaveOutputs=false);
    examples=current.examples;
    examples.example_id=string(examples.example_id)+"__M"+string(M);
    examples.dataset_id(:)=string(config.campaign_id);
    examples.sample_id=string(examples.sample_id)+"__M"+string(M);
    parts{index}=examples;
    summary=current.sample_summaries; summary.REQ_M=repmat(M,height(summary),1);
    summaries{index}=summary;
    if index==1
        physical_sample_count=current.sample_count;
        physical_inventory=current.inventory;
    end
end
examples=vertcat(parts{:}); sample_summaries=vertcat(summaries{:});
if numel(unique(string(examples.example_id)))~=height(examples)
    error("reqml:DuplicateDualMExampleId","Dual-M example IDs are not unique.");
end
counts=groupsummary(examples,"REQ_M");
if numel(unique(counts.GroupCount))~=1
    error("reqml:UnbalancedDualMDataset","M-specific example counts are unequal.");
end
dataset=struct("schema_name","reqml_homogeneous_dual_M_dataset", ...
    "schema_version","2.0","dataset_id",string(config.campaign_id), ...
    "campaign_runs_csv",string(campaign_csv),"sample_count",physical_sample_count, ...
    "analysis_sample_count",height(sample_summaries),"example_count",height(examples), ...
    "inventory",physical_inventory,"sample_summaries",sample_summaries, ...
    "examples",examples,"REQ_M_values",M_values, ...
    "feature_config",struct("M_values",M_values,"cs_guess",double(config.req.cs_guess_m_s)), ...
    "build_config",struct("target_patches_per_run_per_M",target, ...
    "shared_physical_wavefield",true));
dataset.summary=reqml.datasets.summarize_dataset(dataset);
dataset.variable_registry=reqml.schema.dataset_variable_registry(examples);
dataset.manifest=struct("schema_name","reqml_homogeneous_dual_M_dataset_manifest", ...
    "schema_version","2.0","dataset_id",dataset.dataset_id, ...
    "campaign_runs_csv",dataset.campaign_runs_csv,"physical_sample_count",dataset.sample_count, ...
    "analysis_sample_count",dataset.analysis_sample_count,"example_count",dataset.example_count, ...
    "REQ_M_values",M_values,"cs_guess_m_s",double(config.req.cs_guess_m_s), ...
    "shared_physical_wavefield",true,"created_utc",string(datetime("now","TimeZone","UTC")));
dataset.paths=struct();
if options.SaveOutputs
    output=string(options.OutputDirectory); if ~isfolder(output), mkdir(output); end
    dataset.paths.examples=fullfile(output,"examples.mat");
    dataset.paths.sample_summaries=fullfile(output,"sample_summaries.csv");
    dataset.paths.variable_registry=fullfile(output,"variable_registry.csv");
    dataset.paths.manifest=fullfile(output,"dataset_manifest.json");
    save(dataset.paths.examples,"examples","-v7.3");
    writetable(sample_summaries,dataset.paths.sample_summaries);
    writetable(dataset.variable_registry,dataset.paths.variable_registry);
    write_json(dataset.paths.manifest,dataset.manifest);
end
end

function target=resolve_target(config)
if isfield(config.patch_sampling,"target_patches_per_run_per_M")
    target=double(config.patch_sampling.target_patches_per_run_per_M);
else
    target=double(config.patch_sampling.target_patches_per_run);
end
end

function write_json(path,value)
fid=fopen(path,"w"); if fid<0, error("reqml:CannotWriteDualMDataset","Cannot write %s",path); end
cleanup=onCleanup(@() fclose(fid)); fprintf(fid,"%s\n",jsonencode(value,PrettyPrint=true));
end
