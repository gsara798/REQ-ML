function result=runV2DiscretizationValidation(config_file,options)
%RUNV2DISCRETIZATIONVALIDATION Generate/evaluate the new 0.30-mm v2 set.
arguments
    config_file {mustBeTextScalar}
    options.ModelBundle {mustBeTextScalar} = ""
end
config_file=string(config_file); base=jsondecode(fileread(config_file)); cfg=base;
v=base.validation_0p30mm; cfg.campaign_id=string(v.campaign_id);
cfg.design.cs_m_s=double(v.cs_m_s); cfg.design.frequency_hz=double(v.frequency_hz);
cfg.design.spacing_m=double(v.spacing_m); cfg.design.base_realizations_per_condition=double(v.realizations_per_condition);
cfg.design.base_seed=double(v.base_seed);
cfg.design.allow_angular_subset=true;
levels=double(v.angular_levels(:)); cfg.field_regimes=base.field_regimes( ...
    ismember(double([base.field_regimes.angular_level]),levels));
root=string(fileparts(fileparts(fileparts(fileparts(mfilename("fullpath"))))));
output_root=reqml.config.resolveWorkspacePath(string(base.paths.output_root),RepositoryRoot=root);
study_root=fullfile(output_root,"generalization","dx0p30");
design=reqml.homogeneous.materializeCartesianDesign(cfg);
written=reqml.homogeneous.writeCartesianCampaign(config_file, ...
    OutputDirectory=fullfile(study_root,"campaign"),Design=design,CampaignId=cfg.campaign_id);
framework=reqml.config.resolveWorkspacePath(string(base.paths.simulation_framework_root),RepositoryRoot=root);
addpath(fullfile(framework,"src")); cleanup=onCleanup(@() rmpath(fullfile(framework,"src")));
simulation=simcampaigns.runCampaign(written.paths.campaign_json,Resume=true,ContinueOnError=false);
csv=fullfile(simulation.campaign_directory,"campaign_runs.csv");
dataset=reqml.homogeneous.buildDualMDatasetFromCampaign(csv,cfg, ...
    OutputDirectory=fullfile(study_root,"dataset"));
coverage=reqml.homogeneous.summarizeCoverage(design,csv,dataset.sample_summaries, ...
    TargetPatchesPerRun=double(base.patch_sampling.target_patches_per_run_per_M),MValues=[2;3]);
if ~coverage.complete || coverage.geometry_mismatch_count~=0
    error("reqml:V2DiscretizationCoverageFailed","0.30-mm coverage or geometry audit failed.");
end
model_file=string(options.ModelBundle); if strlength(model_file)==0, model_file=fullfile(output_root,"training","final_frozen_q0_v2","model_bundle.mat"); end
evaluation=evaluate_dataset(dataset.examples,design.conditions,model_file);
if ~isfolder(fullfile(study_root,"tables")), mkdir(fullfile(study_root,"tables")); end
writetable(evaluation.overall,fullfile(study_root,"tables","overall.csv"));
writetable(evaluation.by_M,fullfile(study_root,"tables","by_M.csv"));
writetable(evaluation.by_sws,fullfile(study_root,"tables","by_sws.csv"));
writetable(evaluation.by_angular,fullfile(study_root,"tables","by_angular.csv"));
writetable(coverage.runs,fullfile(study_root,"tables","coverage_by_run_M.csv"));
test_mape=evaluation.overall.sws_mape;
gate=table(3,test_mape,test_mape<=3,VariableNames=["threshold_mape","observed_mape","pass"]);
writetable(gate,fullfile(study_root,"discretization_gate.csv"));
result=struct("design",design,"simulation",simulation,"dataset",dataset, ...
    "coverage",coverage,"evaluation",evaluation,"gate",gate,"study_root",study_root);
clear cleanup
end

function out=evaluate_dataset(e,conditions,model_file)
loaded=load(model_file,"model","predictor_names"); names=string(loaded.predictor_names(:));
X=reqml.training.build_numeric_predictor_matrix(e,names);
q_true=double(e.q_target_from_center_truth); q_pred=reqml.training.predict_regression_model(loaded.model,X,ClipRange=[.001 .999]);
sws=reqml.evaluation.convert_q_predictions_to_sws(e,q_pred);
[found,loc]=ismember(string(e.campaign_condition_id),conditions.condition_id); if ~all(found), error("reqml:UnknownV2ValidationCondition","Unknown validation condition."); end
c=conditions(loc,:); p=table(repmat("test",height(e),1),double(e.REQ_M), ...
    c.cs_m_s,c.frequency_hz,c.angular_level,q_true,q_pred,q_pred-q_true, ...
    sws.cs_error_m_s,sws.cs_error_percent,sws.cs_absolute_error_percent,sws.sws_valid, ...
    VariableNames=["partition","REQ_M","cs_m_s","frequency_hz","angular_level", ...
    "q_true","q_pred","q_error","cs_error_m_s","cs_error_percent", ...
    "cs_absolute_error_percent","sws_valid"]);
out=struct(); out.overall=reqml.homogeneous.summarizeQ0ByGroup(p,["partition"]);
out.by_M=reqml.homogeneous.summarizeQ0ByGroup(p,["REQ_M"]);
out.by_sws=reqml.homogeneous.summarizeQ0ByGroup(p,["cs_m_s","REQ_M"]);
out.by_angular=reqml.homogeneous.summarizeQ0ByGroup(p,["angular_level","REQ_M"]);
end
