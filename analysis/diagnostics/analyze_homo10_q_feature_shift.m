function result = analyze_homo10_q_feature_shift(options)
%ANALYZE_HOMO10_Q_FEATURE_SHIFT Diagnose frozen-Q0 GOOD versus LOW regions.
% This analysis never changes the model, features, data, or public API.

arguments
    options.ResultFile {mustBeTextScalar} = ...
        "/Users/sara/Library/CloudStorage/Box-Box/Research/Papers/REQ/data/Experiments/2026Feb27_homo_10perc_sp/Results_test1_400Hz/REQML_homo10_400Hz_results.mat"
    options.ModelFile {mustBeTextScalar} = ""
    options.OutputRoot {mustBeTextScalar} = ""
    options.RandomSeed (1,1) double {mustBeInteger} = 20260227
    options.TopCount (1,1) double {mustBeInteger,mustBePositive} = 15
end
root=string(fileparts(fileparts(fileparts(mfilename('fullpath')))));
addpath(fullfile(root,'src'));
model_file=string(options.ModelFile);
if strlength(model_file)==0
    model_file=fullfile(root,'outputs','homogeneous_cartesian_q0_v2', ...
        'training','final_frozen_q0_v2','model_bundle.mat');
end
output_root=string(options.OutputRoot);
if strlength(output_root)==0
    output_root=fullfile(root,'outputs','diagnostics', ...
        'homo10_q_feature_shift_v1');
end
if isfolder(output_root)
    error('reqml:diagnostics:OutputExists', ...
        'Diagnostic output already exists; refusing overwrite: %s',output_root);
end
mkdir(output_root); mkdir(fullfile(output_root,'figures'));

bundle=load(model_file,'model','model_metadata','predictor_names');
predictor_names=string(bundle.predictor_names(:)); model=bundle.model;
loaded=load(options.ResultFile,'r2'); r2=loaded.r2;
examples=r2.patch_examples; final=r2.patch_predictions;
if height(examples)~=height(final)
    error('reqml:diagnostics:PredictionAlignment', ...
        'patch_examples and patch_predictions must have identical row counts.');
end
required_final=["q_pred","cs_pred_m_s"];
if ~all(ismember(required_final,string(final.Properties.VariableNames)))
    error('reqml:diagnostics:MissingFinalPredictions', ...
        'r2.patch_predictions must contain final q_pred and cs_pred_m_s.');
end
contract=reqml.training.validate_predictor_contract( ...
    examples,predictor_names,reqml.training.q0_predictor_registry());
if ~contract.valid
    error('reqml:diagnostics:PredictorContract',contract.summary);
end

x_mm=1e3*double(examples.x_center_m); z_mm=1e3*double(examples.z_center_m);
final_q=double(final.q_pred); final_cs=double(final.cs_pred_m_s);
prediction_valid=isfinite(final_q)&isfinite(final_cs);
good=x_mm>=12&x_mm<=26&z_mm>=26&z_mm<=29&prediction_valid;
low=x_mm>=12&x_mm<=26&z_mm>=18&z_mm<=21&prediction_valid;
if ~any(good)||~any(low)
    error('reqml:diagnostics:EmptyRegion','GOOD or LOW region contains no valid predictions.');
end

n=numel(predictor_names); median_good=nan(n,1);median_low=nan(n,1);
n_good=zeros(n,1);n_low=zeros(n,1);pooled_scale=nan(n,1);effect=nan(n,1);
rho_q=nan(n,1);rho_cs=nan(n,1);
for i=1:n
    x=double(examples.(predictor_names(i))); g=x(good);l=x(low);
    g=g(isfinite(g));l=l(isfinite(l));n_good(i)=numel(g);n_low(i)=numel(l);
    if ~isempty(g),median_good(i)=median(g);end
    if ~isempty(l),median_low(i)=median(l);end
    sg=robust_sigma(g);sl=robust_sigma(l);pooled_scale(i)=sqrt((sg^2+sl^2)/2);
    if isfinite(pooled_scale(i))&&pooled_scale(i)>0
        effect(i)=(median_low(i)-median_good(i))/pooled_scale(i);
    end
    combined=good|low;
    rho_q(i)=safe_spearman(x(combined),final_q(combined));
    rho_cs(i)=safe_spearman(x(combined),final_cs(combined));
end

native_importance=nan(n,1);importance_description= ...
    "Unavailable for this fitted model type.";
if lower(string(model.model_type))=="bagged_trees" && ...
        ismethod(model.ensemble,'predictorImportance')
    native_importance=double(predictorImportance(model.ensemble)).';
    importance_description=[ ...
        "Tree split importance: reductions in mean squared error due to " + ...
        "splits, aggregated over the bagged regression trees. This is " + ...
        "training-model split importance, not permutation importance."];
end
native_importance_fraction=native_importance./sum(native_importance,'omitnan');
stats=table((1:n).',predictor_names,n_good,n_low,median_good,median_low, ...
    abs(median_low-median_good),pooled_scale,effect,abs(effect),rho_q, ...
    abs(rho_q),rho_cs,abs(rho_cs),double(model.mu(:)),double(model.sigma(:)), ...
    logical(model.constant_predictor_mask(:)),native_importance, ...
    native_importance_fraction, ...
    'VariableNames',{'predictor_order','predictor','N_good','N_low', ...
    'median_good','median_low','absolute_median_difference', ...
    'pooled_robust_scale','robust_effect_low_minus_good', ...
    'absolute_robust_effect','spearman_q_pred','absolute_spearman_q_pred', ...
    'spearman_cs_pred_m_s','absolute_spearman_cs_pred_m_s', ...
    'training_mu','training_sigma','constant_in_training', ...
    'native_split_importance','native_split_importance_fraction'});
stats.rank_absolute_robust_effect=rank_desc(stats.absolute_robust_effect);
stats.rank_absolute_spearman_q=rank_desc(stats.absolute_spearman_q_pred);
stats.rank_native_split_importance=rank_desc(stats.native_split_importance);

% Verify the exact production path before perturbing one predictor at a time.
low_examples=examples(low,:); original_production= ...
    reqml.deployment.predictQ0Examples(low_examples,model,predictor_names);
stored_low_q=final_q(low);
valid_reproduction=isfinite(stored_low_q)&isfinite(original_production.q_pred);
max_reproduction_error=max(abs(stored_low_q(valid_reproduction)- ...
    original_production.q_pred(valid_reproduction)),[],'omitnan');
if isempty(max_reproduction_error),max_reproduction_error=NaN;end
if ~isfinite(max_reproduction_error)||max_reproduction_error>1e-10
    error('reqml:diagnostics:ProductionMismatch', ...
        'Production inference does not reproduce stored final q (max error %.3g).', ...
        max_reproduction_error);
end

counterfactual=counterfactual_replacement(examples,good,low,final_q, ...
    model,predictor_names,options.RandomSeed);
stats=outerjoin(stats,counterfactual(:,{'predictor', ...
    'delta_q_counterfactual','absolute_delta_q_counterfactual'}), ...
    'Keys','predictor','MergeKeys',true,'Type','left');
stats=sortrows(stats,'predictor_order');

writetable(stats,fullfile(output_root,'feature_statistics.csv'));
writetable(counterfactual,fullfile(output_root,'counterfactual_q_effects.csv'));
make_rank_figure(stats,'absolute_robust_effect','robust_effect_low_minus_good', ...
    options.TopCount,fullfile(output_root,'figures','top_robust_effect.png'), ...
    'GOOD versus LOW robust effect','(median LOW - GOOD) / pooled robust scale');
make_rank_figure(stats,'absolute_spearman_q_pred','spearman_q_pred', ...
    options.TopCount,fullfile(output_root,'figures','top_q_correlation.png'), ...
    'Association with final q prediction','Spearman rho with final q');
make_rank_figure(stats,'absolute_delta_q_counterfactual','delta_q_counterfactual', ...
    options.TopCount,fullfile(output_root,'figures','top_counterfactual_delta_q.png'), ...
    'One-feature distribution replacement in LOW', ...
    'median q original LOW - median q counterfactual');
make_median_heatmap(stats,options.TopCount, ...
    fullfile(output_root,'figures','top_feature_standardized_medians.png'));

region_summary=table(["GOOD";"LOW_SWS"],[nnz(good);nnz(low)], ...
    [median(final_q(good));median(final_q(low))], ...
    [median(final_cs(good));median(final_cs(low))], ...
    'VariableNames',{'region','N','median_final_q_pred', ...
    'median_final_cs_pred_m_s'});
writetable(region_summary,fullfile(output_root,'region_summary.csv'));
model_audit=struct('model_file',model_file,'model_id',string(model.model_id), ...
    'model_type',string(model.model_type),'ensemble_class',string(class(model.ensemble)), ...
    'predictor_names',predictor_names,'predictor_count',n, ...
    'preprocessing','Xstandardized=(X-model.mu)./model.sigma', ...
    'prediction_clip_range',[.001 .999], ...
    'native_importance_description',importance_description, ...
    'max_stored_vs_production_q_error',max_reproduction_error);
analysis_result=struct('schema_name','reqml_homo10_q_feature_shift', ...
    'schema_version','1.0','result_file',string(options.ResultFile), ...
    'model_audit',model_audit,'region_summary',region_summary, ...
    'feature_statistics',stats,'counterfactual',counterfactual, ...
    'good_row_indices',find(good),'low_row_indices',find(low), ...
    'random_seed',options.RandomSeed,'created_utc', ...
    string(datetime('now','TimeZone','UTC')));
save(fullfile(output_root,'homo10_q_feature_shift_results.mat'), ...
    'analysis_result','-v7.3');
print_summary(region_summary,stats,counterfactual,importance_description);
result=analysis_result;result.output_root=output_root;
end

function s=robust_sigma(x)
if isempty(x),s=NaN;return,end
m=median(x);s=1.4826*median(abs(x-m));
end

function rho=safe_spearman(x,y)
valid=isfinite(x)&isfinite(y);x=x(valid);y=y(valid);
if numel(x)<3||numel(unique(x))<2||numel(unique(y))<2,rho=NaN;return,end
rho=corr(x,y,'Type','Spearman','Rows','complete');
end

function rank=rank_desc(value)
rank=nan(size(value));valid=find(isfinite(value));
[~,order]=sort(value(valid),'descend');rank(valid(order))=(1:numel(valid)).';
end

function out=counterfactual_replacement(examples,good,low,final_q,model,names,seed)
n=numel(names);rows=cell(n,1);base=examples(low,:);original=final_q(low);
for i=1:n
    good_values=double(examples.(names(i)));good_values=good_values(good&isfinite(good_values));
    cf=base;original_values=double(cf.(names(i)));replace=isfinite(original_values);
    if isempty(good_values)||~any(replace)
        qcf=nan(height(cf),1);
    else
        rng(seed+i,'twister');sampled=good_values(randi(numel(good_values),nnz(replace),1));
        original_values(replace)=sampled;cf.(names(i))=original_values;
        prediction=reqml.deployment.predictQ0Examples(cf,model,names);qcf=prediction.q_pred;
    end
    valid=isfinite(original)&isfinite(qcf);
    original_median=median(original(valid),'omitnan');cf_median=median(qcf(valid),'omitnan');
    delta=original_median-cf_median;
    rows{i}=table(i,names(i),nnz(valid),original_median,cf_median,delta,abs(delta), ...
        'VariableNames',{'predictor_order','predictor','N','median_q_original_low', ...
        'median_q_after_good_distribution','delta_q_counterfactual', ...
        'absolute_delta_q_counterfactual'});
end
out=vertcat(rows{:});out.rank_absolute_delta_q=rank_desc(out.absolute_delta_q_counterfactual);
end

function make_rank_figure(t,rank_field,value_field,count,filename,title_text,xlabel_text)
t=t(isfinite(t.(rank_field)),:);t=sortrows(t,rank_field,'descend');
t=t(1:min(count,height(t)),:);t=flipud(t);
fig=figure('Visible','off','Color','w','Position',[100 100 1250 700]);
barh(categorical(t.predictor,t.predictor),t.(value_field));grid on;
xline(0,'k-');xlabel(xlabel_text);title(title_text,'Interpreter','none');
exportgraphics(fig,filename,'Resolution',220);close(fig);
end

function make_median_heatmap(t,count,filename)
t=t(isfinite(t.absolute_robust_effect),:);t=sortrows(t,'absolute_robust_effect','descend');
t=t(1:min(count,height(t)),:);
values=[(t.median_good-t.training_mu)./t.training_sigma, ...
    (t.median_low-t.training_mu)./t.training_sigma];
fig=figure('Visible','off','Color','w','Position',[100 100 700 760]);
h=heatmap(["GOOD","LOW_SWS"],t.predictor,values);h.ColorLimits=[-3 3];
h.Title='Regional medians standardized by frozen training distribution';
h.XLabel='region';h.YLabel='predictor';
exportgraphics(fig,filename,'Resolution',220);close(fig);
end

function print_summary(regions,stats,cf,importance_description)
disp('Final prediction regional summary:');disp(regions);
disp('Top features by absolute robust GOOD-versus-LOW effect:');
q=stats(isfinite(stats.absolute_robust_effect),:);
q=sortrows(q,'absolute_robust_effect','descend');
disp(q(1:min(10,height(q)),{'predictor','median_good','median_low', ...
    'robust_effect_low_minus_good','spearman_q_pred'}));
disp('Top features by absolute Spearman correlation with final q:');
q=stats(isfinite(stats.absolute_spearman_q_pred),:);
q=sortrows(q,'absolute_spearman_q_pred','descend');
disp(q(1:min(10,height(q)),{'predictor','spearman_q_pred', ...
    'robust_effect_low_minus_good'}));
disp('Top model responses to one-feature GOOD-distribution replacement:');
q=cf(isfinite(cf.absolute_delta_q_counterfactual),:);
q=sortrows(q,'absolute_delta_q_counterfactual','descend');
disp(q(1:min(10,height(q)),{'predictor','delta_q_counterfactual', ...
    'median_q_after_good_distribution'}));
fprintf('Native importance: %s\n',importance_description);
end
