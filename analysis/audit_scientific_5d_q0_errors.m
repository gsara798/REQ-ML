function result = audit_scientific_5d_q0_errors(options)
%AUDIT_SCIENTIFIC_5D_Q0_ERRORS Audit cs-error behavior for Q0 model.
%
% Main outputs:
%   - one-way summaries by frequency / Dnom / purity / discretization
%   - heatmap summaries for key 2D interactions
%   - worst conditions
%   - worst 5D cells
%   - plots (boxplots, failure bars, heatmaps, scatter)
%
% Default model audited:
%   q_spectrum_bagged_v1

arguments
    options.TrainingRoot (1,1) string = ""
    options.ModelId (1,1) string = "q_spectrum_bagged_v1"
    options.PlotPartition (1,1) string = "test"
    options.OutputDirectory (1,1) string = ""
end

script_dir = fileparts(mfilename("fullpath"));
repo_root = fileparts(script_dir);

if strlength(options.TrainingRoot) == 0
    options.TrainingRoot = fullfile( ...
        repo_root, ...
        "outputs", ...
        "scientific_5d_training", ...
        "quantile_models_v1");
end

if strlength(options.OutputDirectory) == 0
    options.OutputDirectory = fullfile( ...
        options.TrainingRoot, ...
        "audit_q0_errors_v1");
end

plots_dir = fullfile(options.OutputDirectory, "plots");
tables_dir = fullfile(options.OutputDirectory, "tables");

ensure_folder(options.OutputDirectory);
ensure_folder(plots_dir);
ensure_folder(tables_dir);

prediction_file = locate_prediction_file(options.TrainingRoot);
fprintf("Using prediction file: %s\n", prediction_file);

T = readtable(prediction_file, TextType="string");

% -------------------------------------------------------------------------
% Resolve required columns
% -------------------------------------------------------------------------
var_model = resolve_variable_name(T, ["model_id","baseline_id"]);
var_partition = resolve_variable_name(T, ["partition"]);
var_cs_true = resolve_variable_name(T, ...
    ["truth_cs_center_m_s","true_cs_center_m_s","cs_true_m_s"]);
var_cs_pred = resolve_variable_name(T, ...
    ["cs_pred_m_s","cs_pred","predicted_cs_m_s", ...
     "predicted_sws_m_s","sws_pred_m_s"]);
var_freq = resolve_variable_name(T, ...
    ["frequency_hz","campaign_frequency_hz","SIM_f0"]);
var_purity = resolve_variable_name(T, ...
    ["truth_material_purity","achieved_purity"]);
var_dnom = resolve_variable_name(T, ...
    ["nominal_angular_coverage","achieved_dnom_bin"]);
var_dx = resolve_variable_name(T, ["GRID_dx_m","dx_m"]);
var_dz = resolve_variable_name(T, ["GRID_dz_m","dz_m"]);
var_condition = resolve_variable_name(T, ...
    ["campaign_condition_id","condition_id"]);
var_example = resolve_variable_name(T, ["example_id"], Required=false);
var_q_target = resolve_variable_name(T, ...
    ["q_true","q_target_from_center_truth","q_target"], ...
    Required=false);

% -------------------------------------------------------------------------
% Keep audited model + valid rows
% -------------------------------------------------------------------------
T.(var_model) = string(T.(var_model));
T.(var_partition) = lower(string(T.(var_partition)));

mask = T.(var_model) == options.ModelId;
mask = mask & isfinite(double(T.(var_cs_true)));
mask = mask & isfinite(double(T.(var_cs_pred)));
mask = mask & isfinite(double(T.(var_freq)));
mask = mask & isfinite(double(T.(var_purity)));
mask = mask & isfinite(double(T.(var_dnom)));
mask = mask & isfinite(double(T.(var_dx)));
mask = mask & isfinite(double(T.(var_dz)));

T = T(mask, :);

if isempty(T)
    error("reqml:EmptyAuditTable", ...
        "No valid rows found for model '%s'.", options.ModelId);
end

% -------------------------------------------------------------------------
% Constants from final 5-D scientific campaign
% -------------------------------------------------------------------------
freq_edges = [199 250 350 450 550 601];
purity_edges = [0.5 0.7 0.9 0.98 1.0];
dnom_edges = [0 0.01 0.05 0.2 0.5 1.0];
sws_edges = [1.5 2.0 2.5 3.0 3.5 4.0];
disc_pairs_m = [
    0.00025 0.00025
    0.00040 0.00040
    0.00050 0.00050
];
disc_tol = 1e-12;

freq_labels = make_interval_labels(freq_edges);
purity_labels = make_interval_labels(purity_edges);
dnom_labels = make_interval_labels(dnom_edges);
sws_labels = make_interval_labels(sws_edges);
disc_labels = [
    "0.25 x 0.25 mm"
    "0.40 x 0.40 mm"
    "0.50 x 0.50 mm"
];

% -------------------------------------------------------------------------
% Enrich table
% -------------------------------------------------------------------------
cs_true = double(T.(var_cs_true));
cs_pred = double(T.(var_cs_pred));

T.cs_error_m_s = cs_pred - cs_true;
T.cs_abs_error_m_s = abs(T.cs_error_m_s);
T.cs_pe_pct = 100 * (T.cs_error_m_s ./ cs_true);
T.cs_ape_pct = abs(T.cs_pe_pct);

T.frequency_bin = discretize(double(T.(var_freq)), freq_edges);
T.frequency_label = assign_labels(T.frequency_bin, freq_labels);

T.purity_bin = discretize(double(T.(var_purity)), purity_edges);
T.purity_label = assign_labels(T.purity_bin, purity_labels);

if var_dnom == "achieved_dnom_bin"
    T.dnom_bin = double(T.(var_dnom));
    dnom_labels = compose("Dnom bin %d", (1:5)');
    T.dnom_label = assign_labels(T.dnom_bin, dnom_labels);
else
    T.dnom_bin = discretize(double(T.(var_dnom)), dnom_edges);
    T.dnom_label = assign_labels(T.dnom_bin, dnom_labels);
end

T.sws_bin = discretize(double(T.(var_cs_true)), sws_edges);
T.sws_label = assign_labels(T.sws_bin, sws_labels);

[T.discretization_bin, T.discretization_label] = assign_discretization( ...
    double(T.(var_dx)), ...
    double(T.(var_dz)), ...
    disc_pairs_m, ...
    disc_labels, ...
    disc_tol);

T.cell_5d_key = compose( ...
    "s%02d_f%02d_p%02d_d%02d_g%02d", ...
    T.sws_bin, ...
    T.frequency_bin, ...
    T.purity_bin, ...
    T.dnom_bin, ...
    T.discretization_bin);

if strlength(var_q_target) > 0
    T.q_target_value = double(T.(var_q_target));
else
    T.q_target_value = nan(height(T),1);
end

% Save enriched table
writetable(T, fullfile(tables_dir, "q0_enriched_predictions.csv"));

% -------------------------------------------------------------------------
% One-way summaries
% -------------------------------------------------------------------------
summary_frequency = summarize_one_way(T, var_partition, "frequency_label");
summary_dnom = summarize_one_way(T, var_partition, "dnom_label");
summary_purity = summarize_one_way(T, var_partition, "purity_label");
summary_discretization = summarize_one_way(T, var_partition, "discretization_label");
summary_sws = summarize_one_way(T, var_partition, "sws_label");

writetable(summary_frequency, ...
    fullfile(tables_dir, "summary_by_frequency.csv"));
writetable(summary_dnom, ...
    fullfile(tables_dir, "summary_by_dnom.csv"));
writetable(summary_purity, ...
    fullfile(tables_dir, "summary_by_purity.csv"));
writetable(summary_discretization, ...
    fullfile(tables_dir, "summary_by_discretization.csv"));
writetable(summary_sws, ...
    fullfile(tables_dir, "summary_by_sws.csv"));

% -------------------------------------------------------------------------
% Two-way summaries
% -------------------------------------------------------------------------
plot_partition = lower(string(options.PlotPartition));
Tplot = T(T.(var_partition) == plot_partition, :);

if isempty(Tplot)
    error("reqml:EmptyAuditPartition", ...
        "No rows found for partition '%s'.", plot_partition);
end

summary_freq_purity = summarize_two_way( ...
    Tplot, "frequency_label", "purity_label");
summary_freq_dnom = summarize_two_way( ...
    Tplot, "frequency_label", "dnom_label");
summary_purity_dnom = summarize_two_way( ...
    Tplot, "purity_label", "dnom_label");

writetable(summary_freq_purity, ...
    fullfile(tables_dir, "summary_frequency_x_purity.csv"));
writetable(summary_freq_dnom, ...
    fullfile(tables_dir, "summary_frequency_x_dnom.csv"));
writetable(summary_purity_dnom, ...
    fullfile(tables_dir, "summary_purity_x_dnom.csv"));

% -------------------------------------------------------------------------
% Worst conditions / worst 5D cells / worst examples
% -------------------------------------------------------------------------
worst_conditions = summarize_one_way(Tplot, var_condition, var_condition);
worst_conditions = sortrows(worst_conditions, ...
    ["mape_cs_pct","p95_ape_cs_pct","row_count"], ...
    ["descend","descend","descend"]);
writetable(worst_conditions, ...
    fullfile(tables_dir, "worst_conditions.csv"));

worst_cells = summarize_one_way(Tplot, "cell_5d_key", "cell_5d_key");
worst_cells = sortrows(worst_cells, ...
    ["mape_cs_pct","p95_ape_cs_pct","row_count"], ...
    ["descend","descend","descend"]);
writetable(worst_cells, ...
    fullfile(tables_dir, "worst_5d_cells.csv"));

if strlength(var_example) > 0
    worst_examples = sortrows(Tplot, "cs_ape_pct", "descend");
    worst_examples = worst_examples(1:min(100,height(worst_examples)), :);
    writetable(worst_examples, ...
        fullfile(tables_dir, "worst_100_examples.csv"));
end

% -------------------------------------------------------------------------
% Quantile range summary
% -------------------------------------------------------------------------
if all(isfinite(T.q_target_value))
    q_percentiles = [0 0.1 1 5 25 50 75 95 99 99.9 100]';
    q_values = prctile(T.q_target_value, q_percentiles);
    q_summary = table(q_percentiles, q_values, ...
        VariableNames=["percentile","q_target"]);
    writetable(q_summary, ...
        fullfile(tables_dir, "q_target_percentiles_all_rows.csv"));

    q_by_partition = summarize_quantile_by_partition(T, var_partition);
    writetable(q_by_partition, ...
        fullfile(tables_dir, "q_target_percentiles_by_partition.csv"));
end

% -------------------------------------------------------------------------
% Plots: boxplots
% -------------------------------------------------------------------------
make_boxplot( ...
    Tplot.cs_ape_pct, ...
    Tplot.frequency_label, ...
    freq_labels, ...
    sprintf("Q0 c_s APE by frequency (%s)", plot_partition), ...
    "Absolute percentage error of c_s (%)", ...
    fullfile(plots_dir, "box_cs_ape_by_frequency_test.png"));

make_boxplot( ...
    Tplot.cs_ape_pct, ...
    Tplot.dnom_label, ...
    dnom_labels, ...
    sprintf("Q0 c_s APE by Dnom (%s)", plot_partition), ...
    "Absolute percentage error of c_s (%)", ...
    fullfile(plots_dir, "box_cs_ape_by_dnom_test.png"));

make_boxplot( ...
    Tplot.cs_ape_pct, ...
    Tplot.purity_label, ...
    purity_labels, ...
    sprintf("Q0 c_s APE by purity (%s)", plot_partition), ...
    "Absolute percentage error of c_s (%)", ...
    fullfile(plots_dir, "box_cs_ape_by_purity_test.png"));

make_boxplot( ...
    Tplot.cs_ape_pct, ...
    Tplot.discretization_label, ...
    disc_labels, ...
    sprintf("Q0 c_s APE by discretization (%s)", plot_partition), ...
    "Absolute percentage error of c_s (%)", ...
    fullfile(plots_dir, "box_cs_ape_by_discretization_test.png"));

% -------------------------------------------------------------------------
% Plots: failure bars
% -------------------------------------------------------------------------
make_failure_barplot( ...
    summary_frequency(summary_frequency.partition == plot_partition,:), ...
    "group_label", ...
    freq_labels, ...
    sprintf("Q0 failure rates by frequency (%s)", plot_partition), ...
    fullfile(plots_dir, "failure_rates_by_frequency_test.png"));

make_failure_barplot( ...
    summary_dnom(summary_dnom.partition == plot_partition,:), ...
    "group_label", ...
    dnom_labels, ...
    sprintf("Q0 failure rates by Dnom (%s)", plot_partition), ...
    fullfile(plots_dir, "failure_rates_by_dnom_test.png"));

make_failure_barplot( ...
    summary_purity(summary_purity.partition == plot_partition,:), ...
    "group_label", ...
    purity_labels, ...
    sprintf("Q0 failure rates by purity (%s)", plot_partition), ...
    fullfile(plots_dir, "failure_rates_by_purity_test.png"));

make_failure_barplot( ...
    summary_discretization(summary_discretization.partition == plot_partition,:), ...
    "group_label", ...
    disc_labels, ...
    sprintf("Q0 failure rates by discretization (%s)", plot_partition), ...
    fullfile(plots_dir, "failure_rates_by_discretization_test.png"));

% -------------------------------------------------------------------------
% Plots: heatmaps
% -------------------------------------------------------------------------
make_heatmap_plot( ...
    summary_freq_purity, ...
    "x_label", "y_label", "median_ape_cs_pct", ...
    freq_labels, purity_labels, ...
    "Median APE of c_s (%)", ...
    sprintf("Q0 median APE: frequency x purity (%s)", plot_partition), ...
    fullfile(plots_dir, "heatmap_frequency_x_purity_median_ape_test.png"));

make_heatmap_plot( ...
    summary_freq_dnom, ...
    "x_label", "y_label", "median_ape_cs_pct", ...
    freq_labels, dnom_labels, ...
    "Median APE of c_s (%)", ...
    sprintf("Q0 median APE: frequency x Dnom (%s)", plot_partition), ...
    fullfile(plots_dir, "heatmap_frequency_x_dnom_median_ape_test.png"));

make_heatmap_plot( ...
    summary_purity_dnom, ...
    "x_label", "y_label", "median_ape_cs_pct", ...
    purity_labels, dnom_labels, ...
    "Median APE of c_s (%)", ...
    sprintf("Q0 median APE: purity x Dnom (%s)", plot_partition), ...
    fullfile(plots_dir, "heatmap_purity_x_dnom_median_ape_test.png"));

make_heatmap_plot( ...
    summary_freq_purity, ...
    "x_label", "y_label", "pct_gt10", ...
    freq_labels, purity_labels, ...
    "% of examples with APE > 10%", ...
    sprintf("Q0 failure >10%%: frequency x purity (%s)", plot_partition), ...
    fullfile(plots_dir, "heatmap_frequency_x_purity_gt10_test.png"));

make_heatmap_plot( ...
    summary_freq_dnom, ...
    "x_label", "y_label", "pct_gt10", ...
    freq_labels, dnom_labels, ...
    "% of examples with APE > 10%", ...
    sprintf("Q0 failure >10%%: frequency x Dnom (%s)", plot_partition), ...
    fullfile(plots_dir, "heatmap_frequency_x_dnom_gt10_test.png"));

% -------------------------------------------------------------------------
% Scatter true vs predicted
% -------------------------------------------------------------------------
make_scatter_plot( ...
    double(Tplot.(var_cs_true)), ...
    double(Tplot.(var_cs_pred)), ...
    Tplot.cs_ape_pct, ...
    sprintf("Q0 true vs predicted c_s (%s)", plot_partition), ...
    fullfile(plots_dir, "scatter_cs_true_vs_pred_test.png"));

% -------------------------------------------------------------------------
% Manifest / console summary
% -------------------------------------------------------------------------
result = struct();
result.model_id = options.ModelId;
result.training_root = options.TrainingRoot;
result.output_directory = options.OutputDirectory;
result.plot_partition = plot_partition;
result.row_count = height(T);
result.plot_partition_row_count = height(Tplot);
result.tables_directory = tables_dir;
result.plots_directory = plots_dir;

disp("===== AUDIT COMPLETE =====");
disp(result);

fprintf("\nTop worst 10 cells:\n");
disp(worst_cells(1:min(10,height(worst_cells)), :));

fprintf("\nTop worst 10 conditions:\n");
disp(worst_conditions(1:min(10,height(worst_conditions)), :));

end

% =========================================================================
% Helpers
% =========================================================================

function ensure_folder(path_str)
if ~isfolder(path_str)
    mkdir(path_str);
end
end

function file = locate_prediction_file(training_root)
candidates = [
    fullfile(training_root, "tables", "quantile_predictions.csv")
    fullfile(training_root, "tables", "q_predictions.csv")
    fullfile(training_root, "tables", "predictions.csv")
];
for i = 1:numel(candidates)
    if isfile(candidates(i))
        file = candidates(i);
        return;
    end
end

listing = dir(fullfile(training_root, "tables", "*prediction*.csv"));
if ~isempty(listing)
    file = fullfile(listing(1).folder, listing(1).name);
    return;
end

error("reqml:PredictionFileNotFound", ...
    "Could not locate a prediction CSV under %s/tables", training_root);
end

function name = resolve_variable_name(T, candidates, options)
arguments
    T table
    candidates (:,1) string
    options.Required (1,1) logical = true
end

vars = string(T.Properties.VariableNames);
lower_vars = lower(vars);

for i = 1:numel(candidates)
    idx = find(lower_vars == lower(candidates(i)), 1, "first");
    if ~isempty(idx)
        name = vars(idx);
        return;
    end
end

if options.Required
    error("reqml:MissingVariable", ...
        "Could not resolve any of these variables: %s", ...
        strjoin(candidates, ", "));
else
    name = "";
end
end

function labels = make_interval_labels(edges)
labels = strings(numel(edges)-1,1);
for i = 1:(numel(edges)-1)
    left = edges(i);
    right = edges(i+1);
    if i < numel(edges)-1
        labels(i) = "[" + format_edge(left) + "," + format_edge(right) + ")";
    else
        labels(i) = "[" + format_edge(left) + "," + format_edge(right) + "]";
    end
end
end

function txt = format_edge(x)
if abs(x - round(x)) < 1e-12
    txt = string(round(x));
elseif abs(x) >= 1
    txt = string(strip(sprintf("%.3f", x), "right", "0"));
    if endsWith(txt, ".")
        txt = extractBefore(txt, strlength(txt));
    end
else
    txt = string(strip(sprintf("%.4f", x), "right", "0"));
    if endsWith(txt, ".")
        txt = extractBefore(txt, strlength(txt));
    end
end
end

function labels = assign_labels(bin, ordered_labels)
labels = repmat("out_of_range", numel(bin), 1);
valid = bin >= 1 & bin <= numel(ordered_labels);
labels(valid) = ordered_labels(bin(valid));
end

function [bin, label] = assign_discretization(dx, dz, pairs_m, pair_labels, tol)
bin = zeros(numel(dx),1);
label = repmat("out_of_range", numel(dx), 1);

for i = 1:size(pairs_m,1)
    mask = abs(dx - pairs_m(i,1)) <= tol & abs(dz - pairs_m(i,2)) <= tol;
    bin(mask) = i;
    label(mask) = pair_labels(i);
end
end

function summary = summarize_one_way(T, group_var, label_var)
group_values = string(T.(group_var));
label_values = string(T.(label_var));

[G, group_values, label_values] = findgroups(group_values, label_values);

summary = table();
summary.partition = group_values;
summary.group_label = label_values;
summary.row_count = splitapply(@numel, T.cs_ape_pct, G);
summary.mae_cs_m_s = splitapply(@mean, T.cs_abs_error_m_s, G);
summary.rmse_cs_m_s = splitapply(@(x) sqrt(mean(x.^2)), T.cs_error_m_s, G);
summary.bias_cs_m_s = splitapply(@mean, T.cs_error_m_s, G);
summary.median_ape_cs_pct = splitapply(@median, T.cs_ape_pct, G);
summary.mape_cs_pct = splitapply(@mean, T.cs_ape_pct, G);
summary.p90_ape_cs_pct = splitapply(@(x) prctile(x,90), T.cs_ape_pct, G);
summary.p95_ape_cs_pct = splitapply(@(x) prctile(x,95), T.cs_ape_pct, G);
summary.max_ape_cs_pct = splitapply(@max, T.cs_ape_pct, G);
summary.bias_percent = splitapply(@mean, T.cs_pe_pct, G);
summary.pct_gt5 = splitapply(@(x) 100*mean(x > 5), T.cs_ape_pct, G);
summary.pct_gt10 = splitapply(@(x) 100*mean(x > 10), T.cs_ape_pct, G);
summary.pct_gt20 = splitapply(@(x) 100*mean(x > 20), T.cs_ape_pct, G);
summary.underestimate_pct = splitapply(@(x) 100*mean(x < 0), T.cs_pe_pct, G);

summary = sortrows(summary, ["partition","group_label"]);
end

function summary = summarize_two_way(T, x_var, y_var)
x = string(T.(x_var));
y = string(T.(y_var));

[G, xg, yg] = findgroups(x, y);

summary = table();
summary.x_label = xg;
summary.y_label = yg;
summary.row_count = splitapply(@numel, T.cs_ape_pct, G);
summary.mape_cs_pct = splitapply(@mean, T.cs_ape_pct, G);
summary.median_ape_cs_pct = splitapply(@median, T.cs_ape_pct, G);
summary.p90_ape_cs_pct = splitapply(@(z) prctile(z,90), T.cs_ape_pct, G);
summary.p95_ape_cs_pct = splitapply(@(z) prctile(z,95), T.cs_ape_pct, G);
summary.pct_gt10 = splitapply(@(z) 100*mean(z > 10), T.cs_ape_pct, G);
summary.pct_gt20 = splitapply(@(z) 100*mean(z > 20), T.cs_ape_pct, G);

summary = sortrows(summary, ["y_label","x_label"]);
end

function out = summarize_quantile_by_partition(T, partition_var)
partitions = unique(string(T.(partition_var)));
p = [0 0.1 1 5 25 50 75 95 99 99.9 100]';

out = table();
for i = 1:numel(partitions)
    mask = string(T.(partition_var)) == partitions(i) & isfinite(T.q_target_value);
    values = prctile(T.q_target_value(mask), p);
    block = table( ...
        repmat(partitions(i), numel(p), 1), ...
        p, values, ...
        'VariableNames', ["partition","percentile","q_target"]);
    out = [out; block]; %#ok<AGROW>
end
end

function make_boxplot(y, group_labels, ordered_labels, plot_title, y_label, output_file)
mask = isfinite(y) & group_labels ~= "out_of_range";
y = y(mask);
group_labels = string(group_labels(mask));

xcat = categorical(group_labels, ordered_labels, ordered_labels);

f = figure("Visible","off", "Position", [100 100 1200 500]);
boxchart(xcat, y);
grid on;
ylabel(y_label);
title(plot_title, Interpreter="none");
xtickangle(35);
exportgraphics(f, output_file, Resolution=180);
close(f);
end

function make_failure_barplot(summary, label_var, ordered_labels, plot_title, output_file)
labels = string(summary.(label_var));
gt10 = nan(numel(ordered_labels),1);
gt20 = nan(numel(ordered_labels),1);

for i = 1:numel(ordered_labels)
    idx = find(labels == ordered_labels(i), 1, "first");
    if ~isempty(idx)
        gt10(i) = summary.pct_gt10(idx);
        gt20(i) = summary.pct_gt20(idx);
    end
end

f = figure("Visible","off", "Position", [100 100 1200 500]);
bar([gt10 gt20], "grouped");
grid on;
ylabel("Percent of examples (%)");
title(plot_title, Interpreter="none");
legend({">10%"," >20%"}, Location="northwest");
set(gca, "XTick", 1:numel(ordered_labels), "XTickLabel", ordered_labels);
xtickangle(35);
exportgraphics(f, output_file, Resolution=180);
close(f);
end

function make_heatmap_plot(summary, x_var, y_var, value_var, x_order, y_order, color_label, plot_title, output_file)
M = nan(numel(y_order), numel(x_order));

for r = 1:height(summary)
    xlab = string(summary.(x_var)(r));
    ylab = string(summary.(y_var)(r));
    xi = find(x_order == xlab, 1, "first");
    yi = find(y_order == ylab, 1, "first");
    if ~isempty(xi) && ~isempty(yi)
        M(yi, xi) = summary.(value_var)(r);
    end
end

f = figure("Visible","off", "Position", [100 100 1200 550]);
imagesc(M);
colorbar;
colormap(parula);
title(plot_title, Interpreter="none");
xlabel(strrep(x_var, "_", " "));
ylabel(strrep(y_var, "_", " "));
set(gca, ...
    "XTick", 1:numel(x_order), ...
    "XTickLabel", x_order, ...
    "YTick", 1:numel(y_order), ...
    "YTickLabel", y_order);
xtickangle(35);

cb = colorbar;
ylabel(cb, color_label);

for yi = 1:size(M,1)
    for xi = 1:size(M,2)
        if ~isnan(M(yi,xi))
            text(xi, yi, sprintf("%.1f", M(yi,xi)), ...
                "HorizontalAlignment","center", ...
                "Color","w", ...
                "FontSize",8);
        end
    end
end

exportgraphics(f, output_file, Resolution=180);
close(f);
end

function make_scatter_plot(x, y, c, plot_title, output_file)
f = figure("Visible","off", "Position", [100 100 700 650]);
scatter(x, y, 14, c, "filled");
grid on;
hold on;
xmin = min([x(:); y(:)]);
xmax = max([x(:); y(:)]);
plot([xmin xmax], [xmin xmax], "k--", "LineWidth", 1.2);
xlabel("True c_s (m/s)");
ylabel("Predicted c_s (m/s)");
title(plot_title, Interpreter="none");
cb = colorbar;
ylabel(cb, "APE of c_s (%)");
axis equal;
xlim([xmin xmax]);
ylim([xmin xmax]);
exportgraphics(f, output_file, Resolution=180);
close(f);
end
