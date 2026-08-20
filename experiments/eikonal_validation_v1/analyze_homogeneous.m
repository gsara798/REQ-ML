function result = analyze_homogeneous()

repo_root = string(fileparts(fileparts(fileparts(mfilename("fullpath")))));

eval_root = fullfile( ...
    repo_root, ...
    "outputs","validation","eikonal_validation_v1","evaluation");

runs_root = fullfile(eval_root,"runs");
summary_file = fullfile(eval_root,"run_summary.csv");
assert(isfile(summary_file), "Missing %s", summary_file);

S = readtable(summary_file);
S = S(string(S.geometry)=="homogeneous",:);

assert(~isempty(S), "No homogeneous rows found in run_summary.csv");

% Recover scientific design_id from the campaign summary.
campaign_summary_file = fullfile( ...
    repo_root, ...
    "outputs","validation","eikonal_validation_v1","simulations", ...
    "homogeneous","eikonal_validation_v1_homogeneous", ...
    "campaign_summary.json");

campaign_summary = jsondecode(fileread(campaign_summary_file));
campaign_runs = campaign_summary.runs;

run_id_lookup = strings(numel(campaign_runs),1);
design_id_lookup = strings(numel(campaign_runs),1);

for j = 1:numel(campaign_runs)
    run_id_lookup(j) = string(campaign_runs(j).run_id);
    design_id_lookup(j) = string(campaign_runs(j).design_id);
end

n = height(S);

cs_true = nan(n,1);
field_regime = strings(n,1);
scientific_design_id = strings(n,1);

mape = nan(n,1);
bias = nan(n,1);

cs_pred_median = nan(n,1);
cs_pred_q25 = nan(n,1);
cs_pred_q75 = nan(n,1);

for i = 1:n
    run_id = string(S.design_id(i));

    match = find(run_id_lookup == run_id, 1);
    assert(~isempty(match), "Could not map run_id %s to design_id.", run_id);

    design_id = design_id_lookup(match);
    scientific_design_id(i) = design_id;

    mat_file = fullfile(runs_root, run_id, "patch_metrics.mat");
    assert(isfile(mat_file), "Missing %s", mat_file);

    loaded = load(mat_file, "T", "metadata");
    T = loaded.T;

    valid = logical(T.sws_valid);
    Tv = T(valid,:);

    mape(i) = mean(Tv.cs_absolute_error_percent, "omitnan");
    bias(i) = mean(Tv.cs_error_percent, "omitnan");

    cs_true(i) = unique(Tv.cs_true_m_s);
    if numel(unique(Tv.cs_true_m_s)) ~= 1
        error("Run %s is not homogeneous in truth cs.", design_id);
    end

    cs_pred_median(i) = median(Tv.cs_pred_m_s, "omitnan");
    cs_pred_q25(i) = prctile(Tv.cs_pred_m_s, 25);
    cs_pred_q75(i) = prctile(Tv.cs_pred_m_s, 75);

    field_regime(i) = infer_field_regime(design_id);
end

A = table( ...
    scientific_design_id, ...
    string(S.design_id), ...
    double(S.frequency_hz), ...
    cs_true, ...
    field_regime, ...
    mape, ...
    bias, ...
    cs_pred_median, ...
    cs_pred_q25, ...
    cs_pred_q75, ...
    VariableNames=[ ...
        "design_id","run_id","frequency_hz","cs_true_m_s","field_regime", ...
        "mape_percent","bias_percent", ...
        "cs_pred_median_m_s","cs_pred_q25_m_s","cs_pred_q75_m_s"]);

out_tables = fullfile(eval_root,"homogeneous_analysis");
out_figs = fullfile(out_tables,"figures");

if ~isfolder(out_figs), mkdir(out_figs); end

writetable(A, fullfile(out_tables,"homogeneous_summary.csv"));

xlsx_file = fullfile(out_tables,"homogeneous_metrics.xlsx");
if isfile(xlsx_file), delete(xlsx_file); end

writetable(A, xlsx_file, "Sheet","Summary");

for cs = unique(A.cs_true_m_s).'
    d = A(A.cs_true_m_s==cs,:);
    writetable(d, xlsx_file, "Sheet","cs_"+string(cs));
end

make_mape_figure(A, fullfile(out_figs,"homogeneous_mape_vs_frequency.png"));
make_cs_figure(A, fullfile(out_figs,"homogeneous_cs_vs_frequency.png"));

result = struct();
result.summary = A;
result.output_root = out_tables;

disp(A);

end

function regime = infer_field_regime(design_id)

d = string(lower(design_id));

if contains(d, "directional")
    regime = "directional";
elseif contains(d, "intermediate")
    regime = "intermediate";
elseif contains(d, "diffuse_like")
    regime = "diffuse_like";
else
    error("Could not infer field_regime from design_id: %s", design_id);
end

end

function make_mape_figure(A, output_file)

cs_levels = unique(A.cs_true_m_s);
cs_levels = sort(cs_levels);
regimes = ["directional","intermediate","diffuse_like"];

fig = figure("Visible","off","Color","w","Position",[100 100 1400 420]);
tiledlayout(1,numel(cs_levels),"TileSpacing","compact","Padding","compact");

for k = 1:numel(cs_levels)
    nexttile;
    hold on;

    for r = 1:numel(regimes)
        d = A(A.cs_true_m_s==cs_levels(k) & A.field_regime==regimes(r),:);
        d = sortrows(d, "frequency_hz");
        plot(d.frequency_hz, d.mape_percent, "-o", "LineWidth", 1.5, ...
            "DisplayName", regimes(r));
    end

    xlabel("Frequency (Hz)");
    ylabel("MAPE (%)");
    title(sprintf("Homogeneous, true c_s = %.0f m/s", cs_levels(k)));
    grid on;
    legend("Location","best");
end

exportgraphics(fig, output_file, "Resolution", 250);
close(fig);

end

function make_cs_figure(A, output_file)

cs_levels = unique(A.cs_true_m_s);
cs_levels = sort(cs_levels);
regimes = ["directional","intermediate","diffuse_like"];

fig = figure("Visible","off","Color","w","Position",[100 100 1400 420]);
tiledlayout(1,numel(cs_levels),"TileSpacing","compact","Padding","compact");

for k = 1:numel(cs_levels)
    nexttile;
    hold on;

    yline(cs_levels(k), "--", "LineWidth", 1.2, ...
        "DisplayName", sprintf("truth = %.0f", cs_levels(k)));

    for r = 1:numel(regimes)
        d = A(A.cs_true_m_s==cs_levels(k) & A.field_regime==regimes(r),:);
        d = sortrows(d, "frequency_hz");

        y = d.cs_pred_median_m_s;
        lo = y - d.cs_pred_q25_m_s;
        hi = d.cs_pred_q75_m_s - y;

        errorbar(d.frequency_hz, y, lo, hi, "-o", ...
            "LineWidth", 1.5, ...
            "DisplayName", regimes(r));
    end

    xlabel("Frequency (Hz)");
    ylabel("Predicted c_s (m/s)");
    title(sprintf("Homogeneous, true c_s = %.0f m/s", cs_levels(k)));
    grid on;
    legend("Location","best");
end

exportgraphics(fig, output_file, "Resolution", 250);
close(fig);

end
