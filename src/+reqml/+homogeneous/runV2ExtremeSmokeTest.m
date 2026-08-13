function result=runV2ExtremeSmokeTest(config_file)
%RUNV2EXTREMESMOKETEST Simulate two v2 extremes and extract M=2 and M=3.
arguments
    config_file {mustBeTextScalar}
end
config_file=string(config_file); config=jsondecode(fileread(config_file));
full=reqml.homogeneous.materializeCartesianDesign(config);
keep=(full.conditions.cs_m_s==1 & full.conditions.frequency_hz==200 & ...
    full.conditions.dx_m==.0005 & full.conditions.angular_level==1) | ...
    (full.conditions.cs_m_s==4 & full.conditions.frequency_hz==600 & ...
    full.conditions.dx_m==.00025 & full.conditions.angular_level==7);
design=full; design.conditions=full.conditions(keep,:);
design.runs=full.runs(ismember(full.runs.condition_id,design.conditions.condition_id),:);
design.condition_count=height(design.conditions); design.run_count=height(design.runs);
design.campaign_id=string(config.campaign_id)+"_extreme_smoke";
root=string(fileparts(fileparts(fileparts(fileparts(mfilename("fullpath"))))));
output_root=reqml.config.resolveWorkspacePath(string(config.paths.output_root),RepositoryRoot=root);
smoke_root=fullfile(output_root,"smoke");
written=reqml.homogeneous.writeCartesianCampaign(config_file, ...
    OutputDirectory=fullfile(smoke_root,"campaign"),Design=design,CampaignId=design.campaign_id);
framework=reqml.config.resolveWorkspacePath(string(config.paths.simulation_framework_root),RepositoryRoot=root);
addpath(fullfile(framework,"src")); cleanup=onCleanup(@() rmpath(fullfile(framework,"src")));
simulation=simcampaigns.runCampaign(written.paths.campaign_json, ...
    Resume=logical(config.execution.resume_runs),ContinueOnError=false);
campaign_csv=fullfile(simulation.campaign_directory,"campaign_runs.csv");
dataset=reqml.homogeneous.buildDualMDatasetFromCampaign(campaign_csv,config, ...
    OutputDirectory=fullfile(smoke_root,"dataset"));
target=double(config.patch_sampling.target_patches_per_run_per_M);
coverage=reqml.homogeneous.summarizeCoverage(design,campaign_csv, ...
    dataset.sample_summaries,TargetPatchesPerRun=target,MValues=[2;3]);
assert_smoke(dataset,coverage,design,target);
coverage_dir=fullfile(smoke_root,"coverage"); if ~isfolder(coverage_dir), mkdir(coverage_dir); end
writetable(coverage.runs,fullfile(coverage_dir,"run_coverage.csv"));
writetable(coverage.conditions,fullfile(coverage_dir,"condition_coverage.csv"));
writetable(coverage.geometry_audit,fullfile(coverage_dir,"patch_geometry_audit.csv"));
result=struct("design",design,"written_campaign",written,"simulation",simulation, ...
    "dataset",dataset,"coverage",coverage,"smoke_root",smoke_root);
clear cleanup
end

function assert_smoke(dataset,coverage,design,target)
expected=design.run_count*2*target;
if design.condition_count~=2 || design.run_count~=6 || ~coverage.complete || ...
        dataset.example_count~=expected || coverage.geometry_mismatch_count~=0
    error("reqml:HomogeneousV2SmokeCoverageFailed", ...
        "V2 smoke expected 2 conditions, 6 physical runs, %d examples, and zero geometry mismatches.",expected);
end
e=dataset.examples;
if ~isequal(sort(unique(double(e.REQ_M))),[2;3]) || ...
        any(abs(double(e.truth_material_purity)-1)>1e-12) || ...
        any(abs(double(e.REQ_cs_guess_m_s)-3)>1e-12)
    error("reqml:HomogeneousV2SmokeInvariantFailed","V2 smoke violated dual-M homogeneous invariants.");
end
counts=groupsummary(e,["campaign_run_id","REQ_M"]);
if any(counts.GroupCount~=target)
    error("reqml:HomogeneousV2SmokeQuotaFailed","Every physical run/M must contain exactly %d patches.",target);
end
end
