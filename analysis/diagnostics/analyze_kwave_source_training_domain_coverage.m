function result = analyze_kwave_source_training_domain_coverage(options)
%ANALYZE_KWAVE_SOURCE_TRAINING_DOMAIN_COVERAGE Frozen-Q0 predictor OOD audit.
% Compares existing homogeneous H_STIFF SOURCE-Z/Uz and SOURCE-X/Uz fields
% with the frozen Q0 v2 training center/scale. No simulation or inference is
% run, and H10 GOOD/LOW are included only as predictor-domain references.

arguments
    options.H10AnalysisFile {mustBeTextScalar} = ""
    options.H10ResultFile {mustBeTextScalar} = ""
    options.SourceZSampleFile {mustBeTextScalar} = ""
    options.SourceXSampleFile {mustBeTextScalar} = ""
    options.OutputRoot {mustBeTextScalar} = ""
    options.UseParallel (1,1) logical = true
end
root=string(fileparts(fileparts(fileparts(mfilename('fullpath')))));
addpath(fullfile(root,'src'));
h10_analysis=default_path(options.H10AnalysisFile,fullfile(root,'outputs', ...
    'diagnostics','homo10_q_feature_shift_v1','homo10_q_feature_shift_results.mat'));
h10_result=default_path(options.H10ResultFile, ...
    "/Users/sara/Library/CloudStorage/Box-Box/Research/Papers/REQ/data/Experiments/2026Feb27_homo_10perc_sp/Results_test1_400Hz/REQML_homo10_400Hz_results.mat");
sample_root=fullfile(root,'outputs','benchmarks', ...
    'experimental_bilayer_400hz_source_polarization_v1','component_samples');
source_z_file=default_path(options.SourceZSampleFile, ...
    fullfile(sample_root,'02_axial_total.mat'));
source_x_file=default_path(options.SourceXSampleFile, ...
    fullfile(sample_root,'05_axial_total.mat'));
output_root=default_path(options.OutputRoot,fullfile(root,'outputs', ...
    'diagnostics','kwave_source_polarization_q0_training_domain_v1'));
inputs=[h10_analysis h10_result source_z_file source_x_file];
for file=inputs
    if ~isfile(file),error('reqml:diagnostics:MissingInput', ...
            'Required input does not exist: %s',file);end
end
if isfolder(output_root),error('reqml:diagnostics:OutputExists', ...
        'Diagnostic output already exists; refusing overwrite: %s',output_root);end
mkdir(output_root);mkdir(fullfile(output_root,'figures'));

h=load(h10_analysis,'analysis_result');h10=h.analysis_result;
training=h10.feature_statistics;
names=string(h10.model_audit.predictor_names(:));
if ~isequal(names,string(training.predictor(:)))
    error('reqml:diagnostics:TrainingStatisticsOrder', ...
        'H10 frozen-training statistics are not in the exact Q0 predictor order.');
end
center=double(training.training_mu(:));scale=double(training.training_sigma(:));
if any(~isfinite(center)|~isfinite(scale)|scale<=0)
    error('reqml:diagnostics:InvalidTrainingScale', ...
        'Frozen-training center/scale must be finite with positive scale.');
end

stored=load(h10_result,'r2');h10_examples=stored.r2.patch_examples;
good=h10_examples(double(h10.good_row_indices),:);
low=h10_examples(double(h10.low_row_indices),:);
source_z=extract_existing_examples(source_z_file,names,options.UseParallel,"Z");
source_x=extract_existing_examples(source_x_file,names,options.UseParallel,"X");
datasets={source_z,source_x,good,low};
labels=["KWAVE_SOURCE_Z_UZ","KWAVE_SOURCE_X_UZ","H10_GOOD","H10_LOW"];

summaries=cell(numel(labels),1);predictor_rows=cell(numel(labels),1);
patch_rows=cell(numel(labels),1);
for i=1:numel(labels)
    [z,valid]=standardize_examples(datasets{i},names,center,scale);
    [summaries{i},predictor_rows{i},patch_rows{i}]=summarize_dataset( ...
        z,valid,names,labels(i));
end
summary=vertcat(summaries{:});predictors=vertcat(predictor_rows{:});
patch_scores=vertcat(patch_rows{:});

writetable(summary,fullfile(output_root,'predictor_domain_coverage_summary.csv'));
writetable(predictors,fullfile(output_root,'predictor_domain_median_z.csv'));
writetable(patch_scores,fullfile(output_root,'patch_ood_scores.csv'));
make_heatmap(predictors,names,labels, ...
    fullfile(output_root,'figures','predictor_median_training_z_heatmap.png'));
make_patch_figure(patch_scores,labels, ...
    fullfile(output_root,'figures','patch_ood_score_distributions.png'));

z_row=summary(summary.dataset=="KWAVE_SOURCE_Z_UZ",:);
x_row=summary(summary.dataset=="KWAVE_SOURCE_X_UZ",:);
comparison=table(z_row.median_absolute_z,x_row.median_absolute_z, ...
    z_row.p95_absolute_z,x_row.p95_absolute_z, ...
    z_row.fraction_absolute_z_gt_2,x_row.fraction_absolute_z_gt_2, ...
    z_row.fraction_absolute_z_gt_3,x_row.fraction_absolute_z_gt_3, ...
    z_row.median_patch_max_absolute_z,x_row.median_patch_max_absolute_z, ...
    'VariableNames',{'source_z_median_absolute_z','source_x_median_absolute_z', ...
    'source_z_p95_absolute_z','source_x_p95_absolute_z', ...
    'source_z_fraction_gt_2','source_x_fraction_gt_2', ...
    'source_z_fraction_gt_3','source_x_fraction_gt_3', ...
    'source_z_median_patch_max_z','source_x_median_patch_max_z'});
result=struct('schema_name','reqml_kwave_source_training_domain_coverage', ...
    'schema_version','1.0','standardization_definition', ...
    'z=(predictor-training_mu)/training_sigma from frozen H10 diagnostic', ...
    'predictor_names',names,'training_center',center,'training_scale',scale, ...
    'summary',summary,'predictor_statistics',predictors, ...
    'patch_scores',patch_scores,'source_z_vs_x',comparison, ...
    'source_z_sample_file',source_z_file,'source_x_sample_file',source_x_file, ...
    'h10_analysis_file',h10_analysis,'created_utc', ...
    string(datetime('now','TimeZone','UTC')));
save(fullfile(output_root,'training_domain_coverage_results.mat'),'result','-v7.3');
disp('Frozen-Q0 predictor-domain coverage summary:');disp(summary);
disp('Direct SOURCE-Z versus SOURCE-X summary:');disp(comparison);
print_top_predictors(predictors,labels);
result.output_root=output_root;
end

function path=default_path(value,default_value)
path=string(value);if strlength(path)==0,path=string(default_value);end
end

function examples=extract_existing_examples(filename,names,use_parallel,source)
data=reqml.io.load_wavefield_sample(filename);
if data.frequency_hz~=400||string(data.component)~="axial_total"
    error('reqml:diagnostics:WrongKwaveInput', ...
        'Expected a completed 400-Hz axial_total (Uz) sample: %s',filename);
end
expected=[0 1];if source=="X",expected=[1 0];end
if ~isequal(double(data.sources.config.polarization_xz),expected)|| ...
        any(abs(double(data.truth.cs_m_s_zx)-3.05)>1e-10,'all')
    error('reqml:diagnostics:WrongKwaveCondition', ...
        'Expected homogeneous H_STIFF SOURCE-%s with polarization [%g %g].', ...
        source,expected(1),expected(2));
end
feature_config=reqml.config.default_feature_config(M=2,cs_guess=3);
dataset=reqml.datasets.extract_examples_from_sample(data,feature_config, ...
    DatasetId="training_domain_coverage",SampleId=string(data.sample_file), ...
    StepX=1,StepZ=1,StoreReqCurves=false,UseWindowParfor=use_parallel, ...
    RequireTruth=false);
examples=dataset.examples;
examples.campaign_frequency_hz=repmat(double(data.frequency_hz),height(examples),1);
contract=reqml.training.validate_predictor_contract(examples,names, ...
    reqml.training.q0_predictor_registry());
if ~contract.valid,error('reqml:diagnostics:PredictorContract',contract.summary);end
end

function [z,valid]=standardize_examples(examples,names,center,scale)
n=height(examples);p=numel(names);x=nan(n,p);
for i=1:p,x(:,i)=double(examples.(names(i)));end
z=(x-center.')./scale.';valid=isfinite(z);
if ~all(valid,'all')
    error('reqml:diagnostics:NonfinitePredictor', ...
        'All actual Q0 predictor observations must be finite for this audit.');
end
end

function [summary,predictors,patches]=summarize_dataset(z,valid,names,label)
absolute_z=abs(z(valid));median_abs=median(absolute_z);p95=prctile(absolute_z,95);
fraction2=mean(absolute_z>2);fraction3=mean(absolute_z>3);maximum=max(absolute_z);
predictor_median=median(z,1);predictor_median_abs=median(abs(z),1);
predictor_p95_abs=prctile(abs(z),95,1);predictor_max_abs=max(abs(z),[],1);
[~,order]=sort(predictor_median_abs,'descend');top=order(1:min(15,numel(order)));
top_values=predictor_median_abs(top).';
top_text=join(compose("%s=%.4g",names(top),top_values),"; ");
patch_median=median(abs(z),2);patch_max=max(abs(z),[],2);
summary=table(label,size(z,1),size(z,2),numel(absolute_z),median_abs,p95, ...
    fraction2,fraction3,maximum,median(patch_median),prctile(patch_median,95), ...
    max(patch_median),median(patch_max),prctile(patch_max,95),max(patch_max), ...
    top_text,'VariableNames',{'dataset','N_patches','N_predictors', ...
    'N_predictor_observations','median_absolute_z','p95_absolute_z', ...
    'fraction_absolute_z_gt_2','fraction_absolute_z_gt_3','maximum_absolute_z', ...
    'median_patch_median_absolute_z','p95_patch_median_absolute_z', ...
    'max_patch_median_absolute_z','median_patch_max_absolute_z', ...
    'p95_patch_max_absolute_z','max_patch_max_absolute_z', ...
    'top15_predictors_by_median_absolute_z'});
predictors=table(repmat(label,numel(names),1),(1:numel(names)).',names, ...
    predictor_median.',predictor_median_abs.',predictor_p95_abs.', ...
    predictor_max_abs.','VariableNames',{'dataset','predictor_order','predictor', ...
    'median_training_z','median_absolute_training_z', ...
    'p95_absolute_training_z','maximum_absolute_training_z'});
patches=table(repmat(label,size(z,1),1),(1:size(z,1)).',patch_median,patch_max, ...
    'VariableNames',{'dataset','patch_index','median_absolute_training_z', ...
    'maximum_absolute_training_z'});
end

function make_heatmap(t,names,labels,filename)
values=nan(numel(names),numel(labels));
for i=1:numel(labels)
    q=t(t.dataset==labels(i),:);q=sortrows(q,'predictor_order');
    values(:,i)=q.median_training_z;
end
[~,order]=sort(max(abs(values),[],2),'descend');values=values(order,:);
display_names=replace(names(order),'_','\_');limit=max(3,prctile(abs(values(:)),98));
fig=figure('Visible','off','Color','w','Position',[100 100 1050 1800]);
display_datasets=["k-Wave Z->Uz","k-Wave X->Uz","H10 GOOD","H10 LOW"];
h=heatmap(display_datasets,display_names,values);
h.ColorLimits=[-limit limit];h.CellLabelColor='none';
h.Colormap=diverging_colormap(256);
h.Title='Median predictor value standardized to frozen Q0 v2 training';
h.XLabel='dataset';h.YLabel='Q0 predictor (sorted by maximum median deviation)';
exportgraphics(fig,filename,'Resolution',220);close(fig);
end

function make_patch_figure(t,labels,filename)
fig=figure('Visible','off','Color','w','Position',[100 100 1350 600]);
tiledlayout(1,2,'TileSpacing','compact','Padding','compact');
display_labels=["k-Wave Z->Uz","k-Wave X->Uz","H10 GOOD","H10 LOW"];
groups=categorical(t.dataset,labels,display_labels);
nexttile;boxchart(groups,t.median_absolute_training_z);
grid on;ylabel('median |training z| across predictors');title('Patch median OOD score');
xtickangle(25);
nexttile;boxchart(groups,t.maximum_absolute_training_z);
grid on;ylabel('maximum |training z| across predictors');title('Patch maximum OOD score');
xtickangle(25);sgtitle('Frozen Q0 v2 patch-level predictor-domain coverage');
exportgraphics(fig,filename,'Resolution',220);close(fig);
end

function map=diverging_colormap(n)
half=floor(n/2);
blue=[linspace(.12,1,half).' linspace(.35,1,half).' ones(half,1)];
red=[ones(n-half,1) linspace(1,.20,n-half).' linspace(1,.12,n-half).'];
map=[blue;red];
end

function print_top_predictors(t,labels)
for label=labels
    q=t(t.dataset==label,:);q=sortrows(q,'median_absolute_training_z','descend');
    fprintf('\n%s top predictors by median |training z|:\n',label);
    disp(q(1:min(15,height(q)),{'predictor','median_training_z', ...
        'median_absolute_training_z','p95_absolute_training_z'}));
end
end
