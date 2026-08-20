function result = analyze_inclusion_interface_profiles()

repo_root = string(fileparts(fileparts(fileparts(mfilename("fullpath")))));
eval_root = fullfile(repo_root,"outputs","validation","eikonal_validation_v1","evaluation");
runs_root = fullfile(eval_root,"runs");

S = readtable(fullfile(eval_root,"run_summary.csv"));
S = S(string(S.geometry)=="circular_inclusion",:);
assert(height(S)==24,"Expected 24 inclusion runs, found %d.",height(S));

campaign_summary_file = fullfile( ...
    repo_root,"outputs","validation","eikonal_validation_v1", ...
    "simulations","circular_inclusion","eikonal_validation_v1_circular_inclusion", ...
    "campaign_summary.json");

C = jsondecode(fileread(campaign_summary_file));

n_runs = numel(C.runs);
run_id_lookup = strings(n_runs,1);
design_id_lookup = strings(n_runs,1);
run_dir_lookup = strings(n_runs,1);

for j = 1:n_runs
    run_id_lookup(j) = string(C.runs(j).run_id);
    design_id_lookup(j) = string(C.runs(j).design_id);
    run_dir_lookup(j) = string(C.runs(j).run_directory);
end

edges_mm = -20:1:20;

profile_rows = cell(0,1);
width_rows = cell(0,1);

for i = 1:height(S)

    % In this evaluation, S.design_id stores the evaluation run_id.
    run_id = string(S.design_id(i));

    m = find(run_id_lookup == run_id,1);
    assert(~isempty(m),"Could not map run_id %s",run_id);

    design_id = design_id_lookup(m);
    sim_run_dir = run_dir_lookup(m);

    target_cs = infer_target_cs(design_id);
    regime = infer_field_regime(design_id);
    f = double(S.frequency_hz(i));

    fprintf("[%02d/%02d] %s | %s | %d Hz | %s\n", ...
        i,height(S),run_id,design_id,f,regime);

    % Load patch metrics
    d = load(fullfile(runs_root,run_id,"patch_metrics.mat"),"T");
    T = d.T;
    T = T(logical(T.sws_valid),:);

    % Load original sample to infer exact circle geometry
    sample_file = fullfile(sim_run_dir,"data","wavefield_sample.mat");
    data = reqml.io.load_wavefield_sample(sample_file);
    [cx_m, cz_m, radius_m] = infer_circle_geometry(data);

    x = double(T.x_center_m);
    z = double(T.z_center_m);

    % Positive inside inclusion, negative in background
    signed_distance_mm = 1e3 * (radius_m - hypot(x - cx_m, z - cz_m));

    bins = discretize(signed_distance_mm, edges_mm);

    for b = 1:(numel(edges_mm)-1)
        mask = bins == b;
        if nnz(mask) < 5
            continue;
        end

        Tb = T(mask,:);

        profile_rows{end+1,1} = struct( ...
            "run_id", run_id, ...
            "design_id", design_id, ...
            "target_sws_m_s", target_cs, ...
            "frequency_hz", f, ...
            "field_regime", regime, ...
            "distance_mm", mean(edges_mm(b:b+1)), ...
            "patch_count", height(Tb), ...
            "cs_pred_mean_m_s", mean(double(Tb.cs_pred_m_s),"omitnan"), ...
            "cs_pred_median_m_s", median(double(Tb.cs_pred_m_s),"omitnan"), ...
            "cs_pred_q25_m_s", prctile(double(Tb.cs_pred_m_s),25), ...
            "cs_pred_q75_m_s", prctile(double(Tb.cs_pred_m_s),75), ...
            "cs_true_mean_m_s", mean(double(Tb.cs_true_m_s),"omitnan"), ...
            "mape_percent", mean(double(Tb.cs_absolute_error_percent),"omitnan"), ...
            "median_ape_percent", median(double(Tb.cs_absolute_error_percent),"omitnan"), ...
            "bias_percent", mean(double(Tb.cs_error_percent),"omitnan"), ...
            "purity_median", median(double(Tb.truth_material_purity),"omitnan"));
    end

    transition_width_mm = estimate_transition_width( ...
        signed_distance_mm, double(T.cs_pred_m_s), target_cs);

    boundary_mask = abs(signed_distance_mm) <= 1.5;
    boundary_mape = mean(double(T.cs_absolute_error_percent(boundary_mask)),"omitnan");
    boundary_bias = mean(double(T.cs_error_percent(boundary_mask)),"omitnan");

    width_rows{end+1,1} = struct( ...
        "run_id", run_id, ...
        "design_id", design_id, ...
        "target_sws_m_s", target_cs, ...
        "frequency_hz", f, ...
        "field_regime", regime, ...
        "transition_width_10_90_mm", transition_width_mm, ...
        "boundary_mape_percent", boundary_mape, ...
        "boundary_bias_percent", boundary_bias);
end

P = struct2table(vertcat(profile_rows{:}));
W = struct2table(vertcat(width_rows{:}));

out_root = fullfile(eval_root,"inclusion_interface_analysis");
fig_root = fullfile(out_root,"figures");
if ~isfolder(fig_root), mkdir(fig_root); end

writetable(P, fullfile(out_root,"inclusion_interface_profiles.csv"));
writetable(W, fullfile(out_root,"inclusion_transition_summary.csv"));

xlsx = fullfile(out_root,"inclusion_interface_metrics.xlsx");
if isfile(xlsx), delete(xlsx); end
writetable(P, xlsx, "Sheet","Profiles");
writetable(W, xlsx, "Sheet","TransitionSummary");

make_profile_figures(P, fig_root);
make_transition_width_figure(W, fullfile(fig_root,"transition_width_vs_frequency.png"));
make_boundary_mape_figure(W, fullfile(fig_root,"boundary_mape_vs_frequency.png"));

result = struct("profiles",P,"summary",W,"output_root",out_root);

disp(W);

end

function [cx_m, cz_m, radius_m] = infer_circle_geometry(data)

material = double(data.truth.material_id_zx);
ids = unique(material(:));
ids = ids(isfinite(ids));

counts = zeros(size(ids));
for k = 1:numel(ids)
    counts(k) = nnz(material == ids(k));
end

[~, bg_idx] = max(counts);
bg_id = ids(bg_idx);

inc_mask = material ~= bg_id;
assert(any(inc_mask,"all"),"Could not find inclusion mask from truth.material_id_zx");

x = double(data.axes.x_m);
z = double(data.axes.z_m);
[XX, ZZ] = meshgrid(x, z);

cx_m = mean(XX(inc_mask),"omitnan");
cz_m = mean(ZZ(inc_mask),"omitnan");

pixel_area = double(data.dx_m) * double(data.dz_m);
area_m2 = nnz(inc_mask) * pixel_area;
radius_m = sqrt(area_m2 / pi);

end

function regime = infer_field_regime(id)
d = lower(string(id));
if contains(d,"directional")
    regime = "directional";
elseif contains(d,"intermediate")
    regime = "intermediate";
elseif contains(d,"diffuse_like")
    regime = "diffuse_like";
else
    error("Cannot infer field_regime from %s",id);
end
end

function cs = infer_target_cs(id)
d = lower(string(id));
if contains(d,"_t3_")
    cs = 3;
elseif contains(d,"_t4_")
    cs = 4;
else
    error("Cannot infer target cs from %s",id);
end
end

function width_mm = estimate_transition_width(distance_mm, cs_pred, target_cs)

edges = -20:0.5:20;
centers = (edges(1:end-1) + edges(2:end)) / 2;
bins = discretize(distance_mm, edges);

med = nan(size(centers));
for i = 1:numel(centers)
    if nnz(bins == i) >= 5
        med(i) = median(cs_pred(bins == i),"omitnan");
    end
end

valid = isfinite(med);
x = centers(valid);
y = med(valid);

if numel(y) < 5
    width_mm = NaN;
    return;
end

y = movmedian(y,3,"omitnan");

low = 2 + 0.1*(target_cs - 2);
high = 2 + 0.9*(target_cs - 2);

d10 = interp_crossing(x, y, low);
d90 = interp_crossing(x, y, high);

if isnan(d10) || isnan(d90)
    width_mm = NaN;
else
    width_mm = abs(d90 - d10);
end

end

function d = interp_crossing(x, y, target)

d = NaN;
for i = 1:(numel(x)-1)
    if (y(i)-target)*(y(i+1)-target) <= 0 && y(i) ~= y(i+1)
        t = (target - y(i)) / (y(i+1) - y(i));
        d = x(i) + t*(x(i+1) - x(i));
        return;
    end
end

end

function make_profile_figures(P, fig_root)

targets = [3 4];
regimes = ["directional","intermediate","diffuse_like"];
freqs = [300 400 500 600];

for t = targets
    for r = regimes

        fig = figure("Visible","off","Color","w","Position",[100 100 1450 900]);
        tiledlayout(2,2,"TileSpacing","compact","Padding","compact");

        for k = 1:numel(freqs)
            f = freqs(k);
            nexttile; hold on;

            d = P(P.target_sws_m_s == t & ...
                  string(P.field_regime) == r & ...
                  P.frequency_hz == f,:);

            d = sortrows(d,"distance_mm");

            yyaxis left
            plot(d.distance_mm, d.cs_pred_median_m_s, "-o", "LineWidth", 1.4);
            ylabel("Predicted c_s (m/s)");
            yline(2,"--","LineWidth",1.0);
            yline(t,"--","LineWidth",1.0);

            yyaxis right
            plot(d.distance_mm, d.mape_percent, "-", "LineWidth", 1.2);
            ylabel("MAPE (%)");

            xline(0,":","LineWidth",1.2);

            xlabel("Signed distance to inclusion boundary (mm)");
            title(sprintf("%d Hz", f));
            grid on;
        end

        sgtitle(sprintf("Inclusion 2 -> %d m/s | %s", t, r), ...
            "Interpreter","none");

        exportgraphics(fig, fullfile(fig_root, ...
            sprintf("profile_t%d_%s.png", t, r)), ...
            "Resolution",250);
        close(fig);
    end
end

end

function make_transition_width_figure(W, output_file)

targets = [3 4];
regimes = ["directional","intermediate","diffuse_like"];

fig = figure("Visible","off","Color","w","Position",[100 100 1050 430]);
tiledlayout(1,2,"TileSpacing","compact","Padding","compact");

for k = 1:2
    target = targets(k);
    nexttile; hold on;

    for r = 1:numel(regimes)
        d = W(W.target_sws_m_s == target & string(W.field_regime) == regimes(r),:);
        d = sortrows(d,"frequency_hz");
        plot(d.frequency_hz, d.transition_width_10_90_mm, "-o", ...
            "LineWidth",1.5, "DisplayName",regimes(r));
    end

    xlabel("Frequency (Hz)");
    ylabel("Transition width 10-90 (mm)");
    title(sprintf("Inclusion 2 -> %d m/s", target));
    grid on;
    legend("Location","best");
end

exportgraphics(fig, output_file, "Resolution",250);
close(fig);

end

function make_boundary_mape_figure(W, output_file)

targets = [3 4];
regimes = ["directional","intermediate","diffuse_like"];

fig = figure("Visible","off","Color","w","Position",[100 100 1050 430]);
tiledlayout(1,2,"TileSpacing","compact","Padding","compact");

for k = 1:2
    target = targets(k);
    nexttile; hold on;

    for r = 1:numel(regimes)
        d = W(W.target_sws_m_s == target & string(W.field_regime) == regimes(r),:);
        d = sortrows(d,"frequency_hz");
        plot(d.frequency_hz, d.boundary_mape_percent, "-o", ...
            "LineWidth",1.5, "DisplayName",regimes(r));
    end

    xlabel("Frequency (Hz)");
    ylabel("Boundary MAPE (%)");
    title(sprintf("Inclusion 2 -> %d m/s", target));
    grid on;
    legend("Location","best");
end

exportgraphics(fig, output_file, "Resolution",250);
close(fig);

end
