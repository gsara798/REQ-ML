
%% analyze_stage_c2_projected_diffuse3d_probe.m
% Analysis for Stage C2 projected-diffuse 3D probe.
% This script reads runner outputs, writes compact diagnostic summaries, and
% regenerates clean figures with readable labels and small titles.

clear; clc; close all;
format compact;

root_dir = fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))));
addpath(root_dir);
root_dir = setup_reqml();
reqml.templates.setup_style();
set(groot,'defaultAxesFontSize',8,'defaultTextFontSize',8, ...
    'defaultLegendFontSize',7,'defaultAxesTitleFontSizeMultiplier',1.0);

CFG = load_config(root_dir);
OUT = fullfile(root_dir, char(CFG.OutputRoot));
TABLE_DIR = fullfile(OUT, 'tables');
FIG_DIR = fullfile(OUT, 'figures', 'analysis');
if exist(FIG_DIR,'dir') ~= 7, mkdir(FIG_DIR); end

patchCsv = fullfile(TABLE_DIR, 'stage_c2_patch_level_predictions.csv');
diagCsv = fullfile(TABLE_DIR, 'stage_c2_projected_angular_diagnostics.csv');
assert(exist(patchCsv,'file') == 2, 'Missing patch table: %s', patchCsv);
T = readtable(patchCsv, 'TextType','string');
if exist(diagCsv,'file') == 2
    D = readtable(diagCsv, 'TextType','string');
else
    D = table();
end

fprintf('\nStage C2 analysis\n');
fprintf('Patch/model rows: %d\n', height(T));
fprintf('Conditions with angular diagnostics: %d\n', height(D));

% Required summaries.
writetable(summarize_metrics(T, "model_name"), fullfile(TABLE_DIR, 'stage_c2_summary_by_model.csv'));
writetable(summarize_metrics(T, "field_regime"), fullfile(TABLE_DIR, 'stage_c2_summary_by_field_regime.csv'));
writetable(summarize_metrics(T, "geometry"), fullfile(TABLE_DIR, 'stage_c2_summary_by_geometry.csv'));
writetable(summarize_metrics(T, "f0"), fullfile(TABLE_DIR, 'stage_c2_summary_by_frequency.csv'));
writetable(summarize_metrics(T, ["geometry","field_regime"]), fullfile(TABLE_DIR, 'stage_c2_condition_summary.csv'));
writetable(summarize_metrics(T, ["model_name","roi_label","field_regime"]), fullfile(TABLE_DIR, 'stage_c2_summary_by_roi_field.csv'));
Tdist = add_distance_bins(T);
Tdist = Tdist(Tdist.distance_bin ~= "not_applicable", :);
if ~isempty(Tdist)
    writetable(summarize_metrics(Tdist, ["model_name","distance_bin","field_regime"]), fullfile(TABLE_DIR, 'stage_c2_summary_by_distance_field.csv'));
end
if ~isempty(D)
    Q = summarize_q_vs_isotropy(T, D);
    writetable(Q, fullfile(TABLE_DIR, 'stage_c2_q_vs_isotropy.csv'));
end

main = T(T.model_name == "q_spectrum_plus_composition", :);
summaryField = summarize_metrics(main, "field_regime");
[~,ord] = sort(field_order(summaryField.field_regime));
summaryField = summaryField(ord,:);

plot_metric_by_field(summaryField, 'mean_q_pred', 'Mean predicted q', fullfile(FIG_DIR, 'stage_c2_mean_q_by_field.png'));
plot_metric_by_field(summaryField, 'MAPE_pct', 'MAPE (%)', fullfile(FIG_DIR, 'stage_c2_mape_by_field.png'));
plot_metric_by_field(summaryField, 'bias_pct', 'Signed bias (%)', fullfile(FIG_DIR, 'stage_c2_bias_by_field.png'), true);

if ~isempty(D)
    plot_isotropy_by_field(D, FIG_DIR);
    plot_q_vs_isotropy(main, D, FIG_DIR);
    plot_angular_energy(D, FIG_DIR);
end

plot_geometry_field_heatmap(main, 'MAPE', FIG_DIR);
plot_geometry_field_heatmap(main, 'bias', FIG_DIR);
plot_frequency_field(main, FIG_DIR);
plot_roi_field_diagnostics(main, FIG_DIR);
plot_distance_field_diagnostics(add_distance_bins(main), FIG_DIR);
plot_homogeneous_q_oracle(T, OUT);
write_readme(OUT, T, D, CFG);

S = summarize_metrics(T, "model_name");
disp(S(:, {'model_name','N','MAPE_pct','bias_pct','high20_frac','mean_q_pred'}));
fprintf('Stage C2 analysis complete. Figures: %s\n', FIG_DIR);

function CFG = load_config(root_dir)
fn = fullfile(root_dir, 'configs', 'eikonal_validation', 'stage_c2_projected_diffuse3d_probe.json');
CFG = jsondecode(fileread(fn));
CFG.OutputRoot = string(CFG.OutputRoot);
end

function S = summarize_metrics(T, groups)
if ischar(groups) || isstring(groups), groups = string(groups); end
[G, keys] = findgroups(T(:, cellstr(groups)));
N = splitapply(@numel, T.abs_error_pct, G);
MAPE_pct = splitapply(@(x) mean(x,'omitnan'), T.abs_error_pct, G);
median_APE_pct = splitapply(@(x) median(x,'omitnan'), T.abs_error_pct, G);
bias_pct = splitapply(@(x) mean(x,'omitnan'), T.signed_error_pct, G);
high10_frac = splitapply(@(x) mean(x > 10,'omitnan'), T.abs_error_pct, G);
high20_frac = splitapply(@(x) mean(x > 20,'omitnan'), T.abs_error_pct, G);
mean_sws_pred = splitapply(@(x) mean(x,'omitnan'), T.SWS_pred, G);
mean_sws_true = splitapply(@(x) mean(x,'omitnan'), T.SWS_true, G);
mean_q_pred = splitapply(@(x) mean(x,'omitnan'), T.q_pred, G);
S = [keys table(N, MAPE_pct, median_APE_pct, bias_pct, high10_frac, high20_frac, mean_sws_pred, mean_sws_true, mean_q_pred)];
end

function Q = summarize_q_vs_isotropy(T, D)
main = T(T.model_name == "q_spectrum_plus_composition", :);
S = summarize_metrics(main, ["condition_id","geometry","f0","field_regime"]);
Q = innerjoin(S, D, 'Keys', {'condition_id','geometry','f0','field_regime'});
end

function o = field_order(f)
f = string(f);
o = zeros(size(f));
for i = 1:numel(f)
    s = f(i);
    if s == "single_source_lateral", o(i)=1;
    elseif contains(s,"balanced_projected_diffuse_3D_32src"), o(i)=5;
    elseif contains(s,"balanced_projected_diffuse_3D_64src"), o(i)=6;
    elseif contains(s,"4src"), o(i)=2 + contains(s,"layoutB")*0.1;
    elseif contains(s,"8src"), o(i)=3 + contains(s,"layoutB")*0.1;
    elseif contains(s,"16src"), o(i)=4 + contains(s,"layoutB")*0.1;
    else, o(i)=99;
    end
end
end

function lbl = pretty_field(f)
lbl = string(f);
lbl = replace(lbl, "single_source_lateral", "single source");
lbl = replace(lbl, "diffuse_like_", "diffuse-like ");
lbl = replace(lbl, "balanced_projected_diffuse_3D_", "projected 3D ");
lbl = replace(lbl, "_", " ");
end

function lbl = pretty_roi(r)
lbl = string(r);
lbl = replace(lbl, "homogeneous_center", "homogeneous center");
lbl = replace(lbl, "homogeneous_other", "homogeneous other");
lbl = replace(lbl, "inclusion_center", "inclusion center");
lbl = replace(lbl, "inclusion_core", "inclusion core");
lbl = replace(lbl, "background_far", "background far");
lbl = replace(lbl, "interface_0_1mm", "interface 0-1 mm");
lbl = replace(lbl, "interface_1_2mm", "interface 1-2 mm");
lbl = replace(lbl, "interface_2_4mm", "interface 2-4 mm");
lbl = replace(lbl, "interface_4_8mm", "interface 4-8 mm");
lbl = replace(lbl, "_", " ");
end

function T = add_distance_bins(T)
if ~ismember("distance_to_interface_m", string(T.Properties.VariableNames))
    T.distance_bin = repmat("not_available", height(T), 1);
    return;
end
dmm = 1e3 * T.distance_to_interface_m;
bins = [-inf 0 1 2 4 8 inf];
names = ["not_applicable","0-1 mm","1-2 mm","2-4 mm","4-8 mm",">8 mm"];
T.distance_bin = strings(height(T),1);
for i = 1:numel(names)
    T.distance_bin(:) = "not_applicable";
end
for i = 1:numel(names)
    idx = dmm > bins(i) & dmm <= bins(i+1);
    if i == 1
        idx = ~isfinite(dmm) | dmm <= 0;
    end
    T.distance_bin(idx) = names(i);
end
end

function plot_metric_by_field(S, metric, ylab, fn, addZero)
if nargin < 5, addZero = false; end
fig = figure('Color','w','Position',[100 100 900 360], 'Visible','off');
bar(S.(metric)); grid on;
set(gca,'XTick',1:height(S),'XTickLabel',pretty_field(S.field_regime),'XTickLabelRotation',30);
ylabel(ylab); title(ylab + " by field regime", 'FontSize', 12);
if addZero, yline(0,'k-','LineWidth',1); end
exportgraphics(fig, fn, 'Resolution', 180); close(fig);
end

function plot_isotropy_by_field(D, figDir)
[G,K] = findgroups(D.field_regime);
E = splitapply(@(x) mean(x,'omitnan'), D.angular_entropy, G);
CV = splitapply(@(x) mean(x,'omitnan'), D.angular_cv, G);
PM = splitapply(@(x) mean(x,'omitnan'), D.angular_peak_to_mean, G);
S = table(K, E, CV, PM, 'VariableNames', {'field_regime','entropy','cv','peak_to_mean'});
[~,ord] = sort(field_order(S.field_regime)); S = S(ord,:);
fig = figure('Color','w','Position',[100 100 1200 360], 'Visible','off');
tiledlayout(1,3,'Padding','compact','TileSpacing','compact');
metrics = {'entropy','cv','peak_to_mean'}; labs = {'Angular entropy','Angular CV','Peak / mean angular energy'};
for i=1:3
    nexttile; bar(S.(metrics{i})); grid on; title(labs{i},'FontSize',10);
    set(gca,'XTick',1:height(S),'XTickLabel',pretty_field(S.field_regime),'XTickLabelRotation',35);
end
exportgraphics(fig, fullfile(figDir, 'stage_c2_projected_isotropy_by_field.png'), 'Resolution', 180); close(fig);
end

function plot_q_vs_isotropy(T, D, figDir)
Q = summarize_q_vs_isotropy(T, D);
[gid, names] = findgroups(Q.field_regime);
fig = figure('Color','w','Position',[100 100 1150 360], 'Visible','off');
tiledlayout(1,3,'Padding','compact','TileSpacing','compact');
nexttile; scatter_grouped(Q.angular_entropy, Q.mean_q_pred, gid, names); grid on; xlabel('Angular entropy'); ylabel('Mean predicted q'); title('q vs angular entropy','FontSize',10);
nexttile; scatter_grouped(Q.angular_peak_to_mean, Q.mean_q_pred, gid, names); grid on; xlabel('Peak / mean angular energy'); ylabel('Mean predicted q'); title('q vs angular dominance','FontSize',10);
nexttile; scatter_grouped(Q.angular_entropy, Q.bias_pct, gid, names); grid on; xlabel('Angular entropy'); ylabel('Signed bias (%)'); title('Bias vs angular entropy','FontSize',10); yline(0,'k-');
exportgraphics(fig, fullfile(figDir, 'stage_c2_q_bias_vs_isotropy.png'), 'Resolution', 180); close(fig);
end

function scatter_grouped(x, y, gid, names)
hold on; cmap = lines(max(gid));
for ii = 1:max(gid)
    idx = gid == ii;
    scatter(x(idx), y(idx), 36, cmap(ii,:), 'filled', 'DisplayName', pretty_field(names(ii)));
end
legend('Location','bestoutside');
end

function plot_angular_energy(D, figDir)
cols = startsWith(string(D.Properties.VariableNames), 'Etheta_');
if ~any(cols), return; end
Ecols = string(D.Properties.VariableNames(cols));
K = unique(D.field_regime, 'stable');
M = nan(numel(K), numel(Ecols));
for ii = 1:numel(K)
    idx = D.field_regime == K(ii);
    M(ii,:) = mean(D{idx, cellstr(Ecols)}, 1, 'omitnan');
end
[~,ord] = sort(field_order(K)); K = K(ord); M = M(ord,:);
theta = linspace(-pi, pi, numel(Ecols));
fig = figure('Color','w','Position',[100 100 950 420], 'Visible','off'); hold on;
for i=1:numel(K), plot(theta, M(i,:), '-o', 'LineWidth', 1.1, 'DisplayName', pretty_field(K(i))); end
grid on; xlabel('Angle in x-z plane (rad)'); ylabel('Normalized angular energy'); title('Mean angular energy distribution','FontSize',12); legend('Location','eastoutside');
exportgraphics(fig, fullfile(figDir, 'stage_c2_mean_angular_energy_by_field.png'), 'Resolution', 180); close(fig);
end

function plot_geometry_field_heatmap(T, kind, figDir)
if kind == "MAPE"
    valueName = 'MAPE_pct'; ttl = 'MAPE (%)'; fn = 'stage_c2_geometry_field_mape_heatmap.png';
else
    valueName = 'bias_pct'; ttl = 'Signed bias (%)'; fn = 'stage_c2_geometry_field_bias_heatmap.png';
end
S = summarize_metrics(T, ["geometry","field_regime"]);
geoms = unique(S.geometry,'stable'); fields = unique(S.field_regime,'stable'); [~,ord]=sort(field_order(fields)); fields=fields(ord);
M = nan(numel(geoms), numel(fields));
for i=1:numel(geoms), for j=1:numel(fields)
    idx = S.geometry==geoms(i) & S.field_regime==fields(j);
    if any(idx), M(i,j)=S.(valueName)(find(idx,1)); end
end, end
fig = figure('Color','w','Position',[100 100 1050 420], 'Visible','off'); imagesc(M); colorbar; colormap(parula); title(ttl + " by geometry and field",'FontSize',12);
set(gca,'XTick',1:numel(fields),'XTickLabel',pretty_field(fields),'XTickLabelRotation',35,'YTick',1:numel(geoms),'YTickLabel',replace(geoms,'_',' '));
exportgraphics(fig, fullfile(figDir, fn), 'Resolution', 180); close(fig);
end

function plot_frequency_field(T, figDir)
S = summarize_metrics(T, ["field_regime","f0"]);
fields = unique(S.field_regime,'stable'); [~,ord]=sort(field_order(fields)); fields=fields(ord);
fig = figure('Color','w','Position',[100 100 1000 420], 'Visible','off'); hold on;
for f = fields(:)'
    A = S(S.field_regime==f,:); [~,ii]=sort(A.f0); A=A(ii,:);
    plot(A.f0, A.MAPE_pct, '-o', 'LineWidth',1.2, 'DisplayName', pretty_field(f));
end
grid on; xlabel('Frequency (Hz)'); ylabel('MAPE (%)'); title('Frequency dependence by field regime','FontSize',12); legend('Location','eastoutside');
exportgraphics(fig, fullfile(figDir, 'stage_c2_mape_vs_frequency_by_field.png'), 'Resolution', 180); close(fig);
end

function plot_roi_field_diagnostics(T, figDir)
if ~ismember("roi_label", string(T.Properties.VariableNames)), return; end
T = T(T.roi_label ~= "" & T.roi_label ~= "unknown", :);
if isempty(T), return; end
S = summarize_metrics(T, ["roi_label","field_regime"]);
roiOrder = ["homogeneous_center","homogeneous_other","background_far", ...
    "inclusion_center","inclusion_core","interface_0_1mm","interface_1_2mm", ...
    "interface_2_4mm","interface_4_8mm"];
fields = unique(S.field_regime,'stable'); [~,fo] = sort(field_order(fields)); fields = fields(fo);
rois = roiOrder(ismember(roiOrder, S.roi_label));
extra = setdiff(unique(S.roi_label,'stable'), rois, 'stable');
rois = [rois extra'];
if isempty(rois), return; end

Bias = nan(numel(rois), numel(fields));
MAPE = nan(numel(rois), numel(fields));
for i = 1:numel(rois)
    for j = 1:numel(fields)
        idx = S.roi_label == rois(i) & S.field_regime == fields(j);
        if any(idx)
            Bias(i,j) = S.bias_pct(find(idx,1));
            MAPE(i,j) = S.MAPE_pct(find(idx,1));
        end
    end
end

fig = figure('Color','w','Position',[80 80 1250 520], 'Visible','off');
tiledlayout(1,2,'Padding','compact','TileSpacing','compact');
nexttile;
bar(Bias); grid on; yline(0,'k-','LineWidth',1);
set(gca,'XTick',1:numel(rois),'XTickLabel',pretty_roi(rois),'XTickLabelRotation',30);
ylabel('Signed error / bias (%)'); title('Signed error by ROI and field','FontSize',11);
legend(pretty_field(fields),'Location','eastoutside');
nexttile;
bar(MAPE); grid on;
set(gca,'XTick',1:numel(rois),'XTickLabel',pretty_roi(rois),'XTickLabelRotation',30);
ylabel('MAPE (%)'); title('Absolute error by ROI and field','FontSize',11);
legend(pretty_field(fields),'Location','eastoutside');
exportgraphics(fig, fullfile(figDir, 'stage_c2_roi_error_by_field.png'), 'Resolution', 180);
close(fig);
end

function plot_distance_field_diagnostics(T, figDir)
if ~ismember("distance_bin", string(T.Properties.VariableNames)), return; end
T = T(T.distance_bin ~= "not_applicable" & T.distance_bin ~= "", :);
if isempty(T), return; end
S = summarize_metrics(T, ["distance_bin","field_regime"]);
binOrder = ["0-1 mm","1-2 mm","2-4 mm","4-8 mm",">8 mm"];
bins = binOrder(ismember(binOrder, S.distance_bin));
fields = unique(S.field_regime,'stable'); [~,fo] = sort(field_order(fields)); fields = fields(fo);
if isempty(bins) || isempty(fields), return; end
fig = figure('Color','w','Position',[80 80 1150 460], 'Visible','off');
tiledlayout(1,2,'Padding','compact','TileSpacing','compact');
nexttile; hold on;
for f = fields(:)'
    y = nan(size(bins));
    for i = 1:numel(bins)
        idx = S.distance_bin == bins(i) & S.field_regime == f;
        if any(idx), y(i) = S.bias_pct(find(idx,1)); end
    end
    plot(1:numel(bins), y, '-o', 'LineWidth', 1.2, 'DisplayName', pretty_field(f));
end
grid on; zline = yline(0,'k-'); zline.HandleVisibility = 'off';
set(gca,'XTick',1:numel(bins),'XTickLabel',bins,'XTickLabelRotation',25);
xlabel('Distance to interface'); ylabel('Signed error / bias (%)'); title('Signed error vs distance to interface','FontSize',11);
legend('Location','eastoutside');
nexttile; hold on;
for f = fields(:)'
    y = nan(size(bins));
    for i = 1:numel(bins)
        idx = S.distance_bin == bins(i) & S.field_regime == f;
        if any(idx), y(i) = S.MAPE_pct(find(idx,1)); end
    end
    plot(1:numel(bins), y, '-o', 'LineWidth', 1.2, 'DisplayName', pretty_field(f));
end
grid on; set(gca,'XTick',1:numel(bins),'XTickLabel',bins,'XTickLabelRotation',25);
xlabel('Distance to interface'); ylabel('MAPE (%)'); title('Absolute error vs distance to interface','FontSize',11);
legend('Location','eastoutside');
exportgraphics(fig, fullfile(figDir, 'stage_c2_error_vs_distance_by_field.png'), 'Resolution', 180);
close(fig);
end

function plot_homogeneous_q_oracle(T, outDir)
if ~all(ismember(["q_oracle","q_pred","q_error","SWS_true"], string(T.Properties.VariableNames)))
    return;
end
H = T(T.model_name == "q_spectrum_plus_composition" & startsWith(T.geometry, "homogeneous"), :);
H = H(isfinite(H.q_oracle) & isfinite(H.q_pred), :);
if isempty(H), return; end
Smetrics = summarize_metrics(H, ["geometry","f0","field_regime","N_sources"]);
[G,K] = findgroups(H(:, {'geometry','f0','field_regime','N_sources'}));
mean_q_oracle = splitapply(@(x) mean(x,'omitnan'), H.q_oracle, G);
mean_q_error = splitapply(@(x) mean(x,'omitnan'), H.q_error, G);
Qstats = [K table(mean_q_oracle, mean_q_error)];
S = innerjoin(Smetrics, Qstats, 'Keys', {'geometry','f0','field_regime','N_sources'});
[~,ord] = sort(field_order(S.field_regime)); S = S(ord,:);
figDir = fullfile(outDir, 'figures', 'q_oracle_homogeneous');
if exist(figDir,'dir') ~= 7, mkdir(figDir); end

fields = S.field_regime;
fig = figure('Color','w','Position',[80 80 1200 430], 'Visible','off');
tiledlayout(1,2,'Padding','compact','TileSpacing','compact');
nexttile; hold on;
plot(1:height(S), S.mean_q_pred, '-o', 'LineWidth', 1.4, 'DisplayName', 'mean q predicted');
plot(1:height(S), S.mean_q_oracle, '--s', 'LineWidth', 1.4, 'DisplayName', 'mean q oracle');
grid on; set(gca,'XTick',1:height(S),'XTickLabel',pretty_field(fields),'XTickLabelRotation',25);
geomLabel = homogeneous_speed_label(S.geometry(1));
ylabel('REQ quantile q'); title(sprintf('Homogeneous c_s = %s, f = %g Hz', geomLabel, S.f0(1)), 'FontSize', 11);
legend('Location','southwest');
nexttile;
yyaxis left;
bar(S.mean_q_error); ylabel('mean(q_{pred} - q_{oracle})');
yyaxis right;
plot(1:height(S), S.bias_pct, '-o', 'LineWidth', 1.4); ylabel('SWS signed bias (%)');
grid on; zline = yline(0,'k-'); zline.HandleVisibility = 'off';
set(gca,'XTick',1:height(S),'XTickLabel',pretty_field(fields),'XTickLabelRotation',25);
title('q error and SWS bias', 'FontSize', 11);
sgtitle('Stage C2 homogeneous oracle-q diagnostic', 'FontSize', 13);
exportgraphics(fig, fullfile(figDir, 'stageC2_homogeneous_q_pred_vs_q_oracle.png'), 'Resolution', 200);
exportgraphics(fig, fullfile(figDir, 'stageC2_homogeneous_q_pred_vs_q_oracle.pdf'), 'ContentType','vector');
close(fig);
end

function label = homogeneous_speed_label(geometryName)
% Convert compact homogeneous geometry ids into readable speed labels.
s = char(geometryName);
tok = regexp(s, 'homogeneous_cs(?<speed>[0-9p]+)', 'names', 'once');
if isempty(tok)
    label = char(replace(string(geometryName), "_", " "));
    return;
end
speedText = strrep(tok.speed, 'p', '.');
label = sprintf('%s m/s', speedText);
end

function write_readme(OUT, T, D, CFG)
fid = fopen(fullfile(OUT, 'README_results.md'), 'a');
fprintf(fid, '\n## Analysis Figures\n\n');
fprintf(fid, 'Additional analysis figures were regenerated by `analyze_stage_c2_projected_diffuse3d_probe.m` under `figures/analysis/`.\n\n');
if ~isempty(D)
    fprintf(fid, 'The angular diagnostics table contains %d condition-level rows. Higher entropy indicates more isotropic projected angular energy.\n', height(D));
end
fclose(fid);
end
