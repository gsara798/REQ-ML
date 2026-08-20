function result = analyze_inclusion_pure_regions()

repo_root = string(fileparts(fileparts(fileparts(mfilename("fullpath")))));

eval_root = fullfile( ...
    repo_root,"outputs","validation","eikonal_validation_v1","evaluation");

runs_root = fullfile(eval_root,"runs");
summary_file = fullfile(eval_root,"run_summary.csv");

S = readtable(summary_file);
S = S(string(S.geometry)=="circular_inclusion",:);

assert(height(S)==24, ...
    "Expected 24 circular inclusion runs, found %d.",height(S));

%% Recover scientific design IDs

campaign_summary_file = fullfile( ...
    repo_root,"outputs","validation","eikonal_validation_v1", ...
    "simulations","circular_inclusion", ...
    "eikonal_validation_v1_circular_inclusion", ...
    "campaign_summary.json");

campaign_summary = jsondecode(fileread(campaign_summary_file));
campaign_runs = campaign_summary.runs;

run_id_lookup = strings(numel(campaign_runs),1);
design_id_lookup = strings(numel(campaign_runs),1);

for j = 1:numel(campaign_runs)
    run_id_lookup(j) = string(campaign_runs(j).run_id);
    design_id_lookup(j) = string(campaign_runs(j).design_id);
end

%% Analyze pure regions

rows = cell(0,1);

for i = 1:height(S)

    run_id = string(S.design_id(i));

    match = find(run_id_lookup==run_id,1);
    assert(~isempty(match), ...
        "Could not map run_id %s.",run_id);

    design_id = design_id_lookup(match);

    mat_file = fullfile(runs_root,run_id,"patch_metrics.mat");
    loaded = load(mat_file,"T");
    T = loaded.T;

    valid = logical(T.sws_valid);
    pure = abs(double(T.truth_material_purity)-1) <= 1e-12;

    T = T(valid & pure,:);

    assert(~isempty(T), ...
        "No valid purity=1 patches for %s.",design_id);

    regime = infer_field_regime(design_id);
    target_cs = infer_target_cs(design_id);
    frequency_hz = double(S.frequency_hz(i));

    bg = T(abs(T.cs_true_m_s-2)<1e-12,:);
    inc = T(abs(T.cs_true_m_s-target_cs)<1e-12,:);

    assert(~isempty(bg), ...
        "No pure background patches for %s.",design_id);
    assert(~isempty(inc), ...
        "No pure inclusion patches for %s.",design_id);

    rows{end+1,1} = summarize_region( ...
        design_id,run_id,"background", ...
        2,target_cs,frequency_hz,regime,bg);

    rows{end+1,1} = summarize_region( ...
        design_id,run_id,"inclusion", ...
        target_cs,target_cs,frequency_hz,regime,inc);
end

A = struct2table(vertcat(rows{:}));
A = sortrows(A, ...
    ["target_sws_m_s","region","frequency_hz","field_regime"]);

%% Outputs

out_root = fullfile(eval_root,"inclusion_pure_analysis");
out_figs = fullfile(out_root,"figures");

if ~isfolder(out_figs), mkdir(out_figs); end

writetable(A,fullfile(out_root,"inclusion_pure_summary.csv"));

xlsx_file = fullfile(out_root,"inclusion_pure_regions_metrics.xlsx");
if isfile(xlsx_file), delete(xlsx_file); end

writetable(A,xlsx_file,"Sheet","Summary");
writetable(A(A.region=="background",:),xlsx_file,"Sheet","Background");
writetable(A(A.region=="inclusion",:),xlsx_file,"Sheet","Inclusion");

%% Figures

make_region_cs_figure( ...
    A(A.region=="background",:), ...
    fullfile(out_figs,"background_cs_vs_frequency.png"), ...
    "background");

make_region_mape_figure( ...
    A(A.region=="background",:), ...
    fullfile(out_figs,"background_mape_vs_frequency.png"), ...
    "background");

make_region_cs_figure( ...
    A(A.region=="inclusion",:), ...
    fullfile(out_figs,"inclusion_cs_vs_frequency.png"), ...
    "inclusion");

make_region_mape_figure( ...
    A(A.region=="inclusion",:), ...
    fullfile(out_figs,"inclusion_mape_vs_frequency.png"), ...
    "inclusion");

disp(A);

result = struct();
result.summary = A;
result.output_root = out_root;

end


function row = summarize_region( ...
    design_id,run_id,region,true_cs,target_cs,f,regime,T)

pred = double(T.cs_pred_m_s);
ape = double(T.cs_absolute_error_percent);
err = double(T.cs_error_percent);

row = struct();

row.design_id = string(design_id);
row.run_id = string(run_id);

row.region = string(region);

row.target_sws_m_s = target_cs;
row.frequency_hz = f;
row.field_regime = string(regime);

row.cs_true_m_s = true_cs;

row.patch_count = height(T);

row.cs_pred_mean_m_s = mean(pred,"omitnan");
row.cs_pred_median_m_s = median(pred,"omitnan");
row.cs_pred_std_m_s = std(pred,0,"omitnan");

row.cs_pred_q25_m_s = prctile(pred,25);
row.cs_pred_q75_m_s = prctile(pred,75);

row.mape_percent = mean(ape,"omitnan");
row.bias_percent = mean(err,"omitnan");

row.median_ape_percent = median(ape,"omitnan");

end


function regime = infer_field_regime(design_id)

d = lower(string(design_id));

if contains(d,"directional")
    regime = "directional";
elseif contains(d,"intermediate")
    regime = "intermediate";
elseif contains(d,"diffuse_like")
    regime = "diffuse_like";
else
    error("Cannot infer field regime from %s.",design_id);
end

end


function cs = infer_target_cs(design_id)

d = lower(string(design_id));

if contains(d,"_t3_")
    cs = 3;
elseif contains(d,"_t4_")
    cs = 4;
else
    error("Cannot infer target SWS from %s.",design_id);
end

end


function make_region_cs_figure(A,output_file,region)

targets = [3 4];
regimes = ["directional","intermediate","diffuse_like"];

fig = figure( ...
    "Visible","off", ...
    "Color","w", ...
    "Position",[100 100 1050 430]);

tiledlayout(1,2, ...
    "TileSpacing","compact", ...
    "Padding","compact");

for k = 1:2

    target = targets(k);
    nexttile;
    hold on;

    dtarget = A(A.target_sws_m_s==target,:);

    true_cs = unique(dtarget.cs_true_m_s);
    assert(numel(true_cs)==1);

    yline(true_cs,"--", ...
        "LineWidth",1.2, ...
        "DisplayName","truth = "+string(true_cs));

    for r = 1:numel(regimes)

        d = dtarget(dtarget.field_regime==regimes(r),:);
        d = sortrows(d,"frequency_hz");

        y = d.cs_pred_median_m_s;
        lo = y-d.cs_pred_q25_m_s;
        hi = d.cs_pred_q75_m_s-y;

        errorbar( ...
            d.frequency_hz,y,lo,hi,"-o", ...
            "LineWidth",1.5, ...
            "DisplayName",regimes(r));
    end

    xlabel("Frequency (Hz)");
    ylabel("Predicted c_s (m/s)");

    if region=="background"
        title(sprintf("Background, inclusion 2 -> %d m/s",target));
    else
        title(sprintf("Inclusion core, true c_s = %d m/s",target));
    end

    grid on;
    legend("Location","best");

end

exportgraphics(fig,output_file,"Resolution",250);
close(fig);

end


function make_region_mape_figure(A,output_file,region)

targets = [3 4];
regimes = ["directional","intermediate","diffuse_like"];

fig = figure( ...
    "Visible","off", ...
    "Color","w", ...
    "Position",[100 100 1050 430]);

tiledlayout(1,2, ...
    "TileSpacing","compact", ...
    "Padding","compact");

for k = 1:2

    target = targets(k);
    nexttile;
    hold on;

    for r = 1:numel(regimes)

        d = A( ...
            A.target_sws_m_s==target & ...
            A.field_regime==regimes(r),:);

        d = sortrows(d,"frequency_hz");

        plot( ...
            d.frequency_hz, ...
            d.mape_percent, ...
            "-o", ...
            "LineWidth",1.5, ...
            "DisplayName",regimes(r));
    end

    xlabel("Frequency (Hz)");
    ylabel("MAPE (%)");

    if region=="background"
        title(sprintf("Background, inclusion 2 -> %d m/s",target));
    else
        title(sprintf("Inclusion core, true c_s = %d m/s",target));
    end

    grid on;
    legend("Location","best");

end

exportgraphics(fig,output_file,"Resolution",250);
close(fig);

end
