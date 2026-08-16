function result = compare_homo10_kwave_stiff_q_feature_shift(options)
%COMPARE_HOMO10_KWAVE_STIFF_Q_FEATURE_SHIFT Compare depth-dependent Q0 response.
% Uses completed SOURCE-X/Uz k-Wave data and the frozen experimental result.
% It does not run simulations, retrain Q0, or alter either input artifact.

arguments
    options.ExperimentalAnalysisFile {mustBeTextScalar} = ""
    options.KwaveSampleFile {mustBeTextScalar} = ""
    options.SourcePolarization (1,1) string {mustBeMember(options.SourcePolarization,["X","Z"])} = "X"
    options.ModelFile {mustBeTextScalar} = ""
    options.OutputRoot {mustBeTextScalar} = ""
    options.RandomSeed (1,1) double {mustBeInteger} = 20260227
    options.TopCount (1,1) double {mustBeInteger,mustBePositive} = 15
    options.UseParallel (1,1) logical = true
end
root=string(fileparts(fileparts(fileparts(mfilename('fullpath')))));
addpath(fullfile(root,'src'));
experimental_file=resolve_default(options.ExperimentalAnalysisFile,fullfile(root, ...
    'outputs','diagnostics','homo10_q_feature_shift_v1', ...
    'homo10_q_feature_shift_results.mat'));
component_index=5;
if options.SourcePolarization=="Z",component_index=2;end
kwave_file=resolve_default(options.KwaveSampleFile,fullfile(root,'outputs', ...
    'benchmarks','experimental_bilayer_400hz_source_polarization_v1', ...
    'component_samples',sprintf('%02d_axial_total.mat',component_index)));
model_file=resolve_default(options.ModelFile,fullfile(root,'outputs', ...
    'homogeneous_cartesian_q0_v2','training','final_frozen_q0_v2', ...
    'model_bundle.mat'));
output_root=resolve_default(options.OutputRoot,fullfile(root,'outputs', ...
    'diagnostics',sprintf('homo10_vs_kwave_source_%s_stiff_feature_shift_v1', ...
    lower(options.SourcePolarization))));
if isfolder(output_root)
    error('reqml:diagnostics:OutputExists', ...
        'Diagnostic output already exists; refusing overwrite: %s',output_root);
end
assert_input(experimental_file);assert_input(kwave_file);assert_input(model_file);
mkdir(output_root);mkdir(fullfile(output_root,'figures'));

saved=load(experimental_file,'analysis_result');experimental=saved.analysis_result;
bundle=load(model_file,'model','model_metadata','predictor_names');
names=string(bundle.predictor_names(:));
if ~isequal(names,string(experimental.model_audit.predictor_names(:)))
    error('reqml:diagnostics:PredictorMismatch', ...
        'Experimental diagnostic and frozen model predictor contracts differ.');
end

data=reqml.io.load_wavefield_sample(kwave_file);
if data.frequency_hz~=400 || string(data.component)~="axial_total"
    error('reqml:diagnostics:WrongKwaveInput', ...
        'Expected completed 400-Hz SOURCE-X H_STIFF axial_total (Uz) sample.');
end
verify_source_stiff(root,data,options.SourcePolarization);
q0=reqml.benchmarks.sourcePolarization.predictQ0Data(data,bundle, ...
    M=2,StepPixels=1,UseParallel=options.UseParallel);
examples=q0.patch_examples;pred=q0.patch_predictions;
final_q=double(pred.q_pred);final_cs=double(pred.cs_pred_m_s);
x_mm=1e3*double(examples.x_center_m);z_mm=1e3*double(examples.z_center_m);
valid=isfinite(final_q)&isfinite(final_cs);
deep=x_mm>=12&x_mm<=26&z_mm>=26&z_mm<=29&valid;
shallow=x_mm>=12&x_mm<=26&z_mm>=18&z_mm<=21&valid;
if ~any(deep)||~any(shallow)
    error('reqml:diagnostics:EmptyRegion', ...
        'A prespecified k-Wave comparison region contains no valid predictions.');
end

[kwave_stats,kwave_cf]=analyze_shift(examples,deep,shallow,final_q, ...
    final_cs,bundle.model,names,options.RandomSeed);
exp_stats=experimental.feature_statistics;
exp_cf=experimental.counterfactual;
comparison=build_comparison(exp_stats,kwave_stats,exp_cf,kwave_cf);
regions=[dataset_regions("EXPERIMENT_HOMO10",experimental.region_summary); ...
    table(repmat("KWAVE_H_STIFF_SOURCE_"+options.SourcePolarization+"_UZ",2,1), ...
    ["DEEP_Z26_29";"SHALLOW_Z18_21"], ...
    [nnz(deep);nnz(shallow)],[median(final_q(deep));median(final_q(shallow))], ...
    [median(final_cs(deep));median(final_cs(shallow))], ...
    'VariableNames',{'dataset','region','N','median_final_q_pred', ...
    'median_final_cs_pred_m_s'})];
regional_shift=regional_shift_table(regions);

writetable(regions,fullfile(output_root,'region_summary.csv'));
writetable(regional_shift,fullfile(output_root,'regional_depth_shift.csv'));
writetable(kwave_stats,fullfile(output_root,'kwave_feature_statistics.csv'));
writetable(kwave_cf,fullfile(output_root,'kwave_counterfactual_q_effects.csv'));
writetable(comparison,fullfile(output_root,'experiment_vs_kwave_features.csv'));
make_region_figure(regions,fullfile(output_root,'figures','regional_q_and_sws.png'));
make_scatter_figure(comparison,'experimental_robust_effect', ...
    'kwave_robust_effect','Depth-shift robust effects', ...
    fullfile(output_root,'figures','robust_effect_experiment_vs_kwave.png'));
make_scatter_figure(comparison,'experimental_delta_q_counterfactual', ...
    'kwave_delta_q_counterfactual','One-feature counterfactual response', ...
    fullfile(output_root,'figures','counterfactual_experiment_vs_kwave.png'));
make_heatmap(comparison,options.TopCount, ...
    fullfile(output_root,'figures','top_depth_shift_comparison.png'));

finite_effect=isfinite(comparison.experimental_robust_effect)& ...
    isfinite(comparison.kwave_robust_effect);
effect_rho=safe_spearman(comparison.experimental_robust_effect(finite_effect), ...
    comparison.kwave_robust_effect(finite_effect));
effect_sign_agreement=mean(sign(comparison.experimental_robust_effect(finite_effect))== ...
    sign(comparison.kwave_robust_effect(finite_effect)));
finite_cf=isfinite(comparison.experimental_delta_q_counterfactual)& ...
    isfinite(comparison.kwave_delta_q_counterfactual);
counterfactual_rho=safe_spearman( ...
    comparison.experimental_delta_q_counterfactual(finite_cf), ...
    comparison.kwave_delta_q_counterfactual(finite_cf));
comparison_summary=struct('robust_effect_spearman',effect_rho, ...
    'robust_effect_sign_agreement_fraction',effect_sign_agreement, ...
    'counterfactual_spearman',counterfactual_rho, ...
    'comparison_region_x_mm',[12 26], ...
    'shallow_region_z_mm',[18 21],'deep_region_z_mm',[26 29]);
result=struct('schema_name','reqml_homo10_kwave_stiff_feature_shift', ...
    'schema_version','1.0','experimental_analysis_file',experimental_file, ...
    'kwave_sample_file',kwave_file,'model_file',model_file, ...
    'kwave_condition','H_STIFF','source_polarization',options.SourcePolarization, ...
    'observed_component','Uz','M',2,'frequency_hz',400, ...
    'kwave_input_validation',data.validation, ...
    'kwave_source_config',data.sources.config, ...
    'region_summary',regions,'regional_depth_shift',regional_shift, ...
    'kwave_feature_statistics',kwave_stats, ...
    'kwave_counterfactual',kwave_cf,'feature_comparison',comparison, ...
    'comparison_summary',comparison_summary, ...
    'created_utc',string(datetime('now','TimeZone','UTC')));
save(fullfile(output_root,'homo10_vs_kwave_feature_shift_results.mat'), ...
    'result','-v7.3');
print_summary(regions,regional_shift,comparison,comparison_summary);
result.output_root=output_root;
end

function value=resolve_default(value,default_value)
value=string(value);if strlength(value)==0,value=string(default_value);end
end

function assert_input(filename)
if ~isfile(filename)
    error('reqml:diagnostics:MissingInput','Required input does not exist: %s',filename);
end
end

function verify_source_stiff(root,data,source_polarization)
config=jsondecode(fileread(fullfile(root,'configs','benchmarks', ...
    'experimental_bilayer_400hz_source_polarization.json')));
conditions=config.conditions;
match=string({conditions.id})=="H_STIFF" & ...
    string({conditions.source_polarization})==source_polarization;
if nnz(match)~=1
    error('reqml:diagnostics:ConditionIdentity', ...
        'Expected exactly one configured SOURCE-%s H_STIFF condition.',source_polarization);
end
truth=double(data.truth.cs_m_s_zx);
if any(abs(truth(isfinite(truth))-3.05)>1e-10,'all')
    error('reqml:diagnostics:WrongKwaveTruth', ...
        'k-Wave input is not homogeneous stiff truth cs=3.05 m/s.');
end
polarization=double(data.sources.config.polarization_xz);
expected=[1 0];if source_polarization=="Z",expected=[0 1];end
if ~isequal(polarization,expected)
    error('reqml:diagnostics:WrongSourcePolarization', ...
        'Expected physical SOURCE-%s polarization_xz=[%g %g].', ...
        source_polarization,expected(1),expected(2));
end
end

function [stats,cf]=analyze_shift(examples,deep,shallow,q,cs,model,names,seed)
n=numel(names);md=nan(n,1);ms=nan(n,1);nd=zeros(n,1);ns=zeros(n,1);
scale=nan(n,1);effect=nan(n,1);rho_q=nan(n,1);rho_cs=nan(n,1);
for i=1:n
    x=double(examples.(names(i)));d=x(deep);s=x(shallow);
    d=d(isfinite(d));s=s(isfinite(s));nd(i)=numel(d);ns(i)=numel(s);
    if ~isempty(d),md(i)=median(d);end
    if ~isempty(s),ms(i)=median(s);end
    sd=robust_sigma(d);ss=robust_sigma(s);scale(i)=sqrt((sd^2+ss^2)/2);
    if isfinite(scale(i))&&scale(i)>0,effect(i)=(ms(i)-md(i))/scale(i);end
    both=deep|shallow;rho_q(i)=safe_spearman(x(both),q(both));
    rho_cs(i)=safe_spearman(x(both),cs(both));
end
importance=double(predictorImportance(model.ensemble)).';
stats=table((1:n).',names,nd,ns,md,ms,abs(ms-md),scale,effect,abs(effect), ...
    rho_q,abs(rho_q),rho_cs,abs(rho_cs),double(model.mu(:)), ...
    double(model.sigma(:)),importance,importance./sum(importance), ...
    'VariableNames',{'predictor_order','predictor','N_deep','N_shallow', ...
    'median_deep','median_shallow','absolute_median_difference', ...
    'pooled_robust_scale','robust_effect_shallow_minus_deep', ...
    'absolute_robust_effect','spearman_q_pred','absolute_spearman_q_pred', ...
    'spearman_cs_pred_m_s','absolute_spearman_cs_pred_m_s','training_mu', ...
    'training_sigma','native_split_importance','native_split_importance_fraction'});
cf=counterfactual_replacement(examples,deep,shallow,q,model,names,seed);
end

function s=robust_sigma(x)
if isempty(x),s=NaN;return,end
s=1.4826*median(abs(x-median(x)));
end

function rho=safe_spearman(x,y)
valid=isfinite(x)&isfinite(y);x=x(valid);y=y(valid);
if numel(x)<3||numel(unique(x))<2||numel(unique(y))<2,rho=NaN;return,end
rho=corr(x,y,'Type','Spearman','Rows','complete');
end

function out=counterfactual_replacement(examples,deep,shallow,q,model,names,seed)
n=numel(names);rows=cell(n,1);base=examples(shallow,:);original=q(shallow);
for i=1:n
    donor=double(examples.(names(i)));donor=donor(deep&isfinite(donor));
    cf=base;values=double(cf.(names(i)));replace=isfinite(values);
    if isempty(donor)||~any(replace)
        qcf=nan(height(cf),1);
    else
        rng(seed+i,'twister');values(replace)=donor(randi(numel(donor),nnz(replace),1));
        cf.(names(i))=values;
        prediction=reqml.deployment.predictQ0Examples(cf,model,names);
        qcf=prediction.q_pred;
    end
    ok=isfinite(original)&isfinite(qcf);m0=median(original(ok),'omitnan');
    m1=median(qcf(ok),'omitnan');delta=m0-m1;
    rows{i}=table(i,names(i),nnz(ok),m0,m1,delta,abs(delta), ...
        'VariableNames',{'predictor_order','predictor','N', ...
        'median_q_original_shallow','median_q_after_deep_distribution', ...
        'delta_q_counterfactual','absolute_delta_q_counterfactual'});
end
out=vertcat(rows{:});
end

function t=dataset_regions(dataset,source)
region=string(source.region);region(region=="GOOD")="DEEP_Z26_29";
region(region=="LOW_SWS")="SHALLOW_Z18_21";
t=table(repmat(string(dataset),height(source),1),region,source.N, ...
    source.median_final_q_pred,source.median_final_cs_pred_m_s, ...
    'VariableNames',{'dataset','region','N','median_final_q_pred', ...
    'median_final_cs_pred_m_s'});
end

function out=regional_shift_table(t)
datasets=unique(t.dataset,'stable');rows=cell(numel(datasets),1);
for i=1:numel(datasets)
    q=t(t.dataset==datasets(i),:);d=q(q.region=="DEEP_Z26_29",:);
    s=q(q.region=="SHALLOW_Z18_21",:);
    rows{i}=table(datasets(i),s.median_final_q_pred-d.median_final_q_pred, ...
        s.median_final_cs_pred_m_s-d.median_final_cs_pred_m_s, ...
        'VariableNames',{'dataset','delta_q_shallow_minus_deep', ...
        'delta_cs_shallow_minus_deep_m_s'});
end
out=vertcat(rows{:});
end

function out=build_comparison(e,k,ecf,kcf)
out=table(string(e.predictor),e.predictor_order, ...
    e.robust_effect_low_minus_good,k.robust_effect_shallow_minus_deep, ...
    e.spearman_q_pred,k.spearman_q_pred,e.native_split_importance_fraction, ...
    'VariableNames',{'predictor','predictor_order','experimental_robust_effect', ...
    'kwave_robust_effect','experimental_spearman_q','kwave_spearman_q', ...
    'native_split_importance_fraction'});
out=outerjoin(out,table(string(ecf.predictor),ecf.delta_q_counterfactual, ...
    'VariableNames',{'predictor','experimental_delta_q_counterfactual'}), ...
    'Keys','predictor','MergeKeys',true,'Type','left');
out=outerjoin(out,table(string(kcf.predictor),kcf.delta_q_counterfactual, ...
    'VariableNames',{'predictor','kwave_delta_q_counterfactual'}), ...
    'Keys','predictor','MergeKeys',true,'Type','left');
out=sortrows(out,'predictor_order');
out.effect_same_direction=sign(out.experimental_robust_effect)==sign(out.kwave_robust_effect);
end

function make_region_figure(t,filename)
datasets=unique(t.dataset,'stable');fig=figure('Visible','off','Color','w', ...
    'Position',[100 100 1100 460]);
for panel=1:2
    subplot(1,2,panel);hold on;grid on;
    for i=1:numel(datasets)
        q=t(t.dataset==datasets(i),:);[~,order]=ismember( ...
            ["SHALLOW_Z18_21";"DEEP_Z26_29"],q.region);q=q(order,:);
        if panel==1,y=q.median_final_q_pred;ylabel('median final q');
        else,y=q.median_final_cs_pred_m_s;ylabel('median predicted SWS (m/s)');end
        plot(1:2,y,'-o','LineWidth',1.8,'DisplayName',datasets(i));
    end
    xlim([.8 2.2]);xticks(1:2);xticklabels({'z 18-21 mm','z 26-29 mm'});
    legend('Interpreter','none','Location','best');
end
sgtitle('Prespecified matched physical regions');exportgraphics(fig,filename,'Resolution',220);
close(fig);
end

function make_scatter_figure(t,xfield,yfield,title_text,filename)
valid=isfinite(t.(xfield))&isfinite(t.(yfield));x=t.(xfield)(valid);y=t.(yfield)(valid);
fig=figure('Visible','off','Color','w','Position',[100 100 720 650]);
scatter(x,y,35,t.native_split_importance_fraction(valid),'filled');grid on;hold on;
lims=[min([x;y;0]) max([x;y;0])];if diff(lims)==0,lims=lims+[-1 1];end
plot(lims,lims,'k--');xline(0,'k:');yline(0,'k:');axis square;
xlabel('experiment: shallow - deep');ylabel('k-Wave: shallow - deep');
title(sprintf('%s (Spearman %.3f)',title_text,safe_spearman(x,y)));
cb=colorbar;cb.Label.String='native Q0 split importance fraction';
exportgraphics(fig,filename,'Resolution',220);close(fig);
end

function make_heatmap(t,count,filename)
score=max(abs(t.experimental_robust_effect),abs(t.kwave_robust_effect));
valid=isfinite(score);t=t(valid,:);score=score(valid);[~,order]=sort(score,'descend');
t=t(order(1:min(count,numel(order))),:);
values=[t.experimental_robust_effect t.kwave_robust_effect];
fig=figure('Visible','off','Color','w','Position',[100 100 760 760]);
h=heatmap(["experiment","k-Wave control/Uz"],replace(t.predictor,"_","\_"),values);
h.ColorLimits=[-max(abs(values),[],'all') max(abs(values),[],'all')];
h.Title='Robust predictor shift: shallow minus deep';
exportgraphics(fig,filename,'Resolution',220);close(fig);
end

function print_summary(regions,shift,comparison,summary)
disp('Matched regional predictions:');disp(regions);disp('Depth shifts:');disp(shift);
fprintf('Predictor robust-effect Spearman experiment vs k-Wave: %.4f\n', ...
    summary.robust_effect_spearman);
fprintf('Predictor effect-sign agreement: %.1f%%\n', ...
    100*summary.robust_effect_sign_agreement_fraction);
fprintf('Counterfactual-effect Spearman: %.4f\n',summary.counterfactual_spearman);
score=abs(comparison.experimental_robust_effect-comparison.kwave_robust_effect);
[~,order]=sort(score,'descend','MissingPlacement','last');
disp('Largest experiment/k-Wave depth-shift differences:');
disp(comparison(order(1:min(10,height(comparison))), ...
    {'predictor','experimental_robust_effect','kwave_robust_effect', ...
    'experimental_delta_q_counterfactual','kwave_delta_q_counterfactual'}));
end
