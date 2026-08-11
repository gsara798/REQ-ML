function result=runV2DevelopmentGeneralization(config_file)
%RUNV2DEVELOPMENTGENERALIZATION Train fixed models for the three v2 splits.
arguments
    config_file {mustBeTextScalar}
end
config_file=string(config_file); config=jsondecode(fileread(config_file));
root=string(fileparts(fileparts(fileparts(fileparts(mfilename("fullpath"))))));
output=reqml.config.resolveWorkspacePath(string(config.paths.output_root),RepositoryRoot=root);
dataset=fullfile(output,"dataset","examples.mat");
result=struct();
r=reqml.homogeneous.trainQ0FromConfig(config_file, ...
    DatasetPath=dataset,SplitPath=fullfile(output,"splits","in_domain","training_split_assignments.mat"), ...
    OutputDirectory=fullfile(output,"training",string(config.training.model_id)), ...
    ModelId=string(config.training.model_id));
result.in_domain=compact_result(r); clear r
r=reqml.homogeneous.trainQ0FromConfig(config_file, ...
    DatasetPath=dataset,SplitPath=fullfile(output,"splits","alternating_sws","training_split_assignments.mat"), ...
    OutputDirectory=fullfile(output,"generalization","alternating_sws"), ...
    ModelId=string(config.training.model_id)+"_alternating_sws");
result.alternating_sws=compact_result(r); clear r
r=reqml.homogeneous.trainQ0FromConfig(config_file, ...
    DatasetPath=dataset,SplitPath=fullfile(output,"splits","alternating_angular","training_split_assignments.mat"), ...
    OutputDirectory=fullfile(output,"generalization","alternating_angular"), ...
    ModelId=string(config.training.model_id)+"_alternating_angular");
result.alternating_angular=compact_result(r); clear r
result.gates=assess_gates(result);
writetable(result.gates,fullfile(output,"generalization","development_gates.csv"));
end

function value=compact_result(value)
% Models and row-level predictions are already persisted by the trainer.
% Do not retain three sets of five fold ensembles and full prediction tables
% in memory while running the sequential development experiments.
value=rmfield(value,["trained","predictions"]);
end

function gates=assess_gates(result)
names=["alternating_sws";"alternating_angular"];
threshold=[3;4]; mape=nan(2,1); bias=nan(2,1);
for i=1:2
    metrics=result.(names(i)).sws_metrics;
    row=metrics.partition=="test";
    mape(i)=metrics.sws_mape(row); bias(i)=metrics.sws_bias_percent(row);
end
pass=mape<=threshold;
gates=table(names,threshold,mape,bias,pass, ...
    VariableNames=["gate","threshold_mape","observed_mape","observed_bias_percent","pass"]);
end
