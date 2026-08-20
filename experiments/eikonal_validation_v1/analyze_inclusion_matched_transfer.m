function result = analyze_inclusion_matched_transfer()

repo_root = string(fileparts(fileparts(fileparts(mfilename("fullpath")))));

eval_root = fullfile( ...
    repo_root,"outputs","validation","eikonal_validation_v1","evaluation");

hom_file = fullfile( ...
    eval_root,"homogeneous_analysis","homogeneous_summary.csv");

inc_file = fullfile( ...
    eval_root,"inclusion_pure_analysis","inclusion_pure_summary.csv");

assert(isfile(hom_file),"Missing %s",hom_file);
assert(isfile(inc_file),"Missing %s",inc_file);

H = readtable(hom_file);
I = readtable(inc_file);

rows = cell(height(I),1);

for i = 1:height(I)

    local_cs = double(I.cs_true_m_s(i));
    f = double(I.frequency_hz(i));
    regime = string(I.field_regime(i));

    match = ...
        H.cs_true_m_s == local_cs & ...
        H.frequency_hz == f & ...
        string(H.field_regime) == regime;

    assert(nnz(match)==1, ...
        "Expected one homogeneous match for cs=%.1f, f=%d, regime=%s.", ...
        local_cs,f,regime);

    h = H(match,:);

    row = struct();

    row.design_id = string(I.design_id(i));
    row.region = string(I.region(i));
    row.target_sws_m_s = double(I.target_sws_m_s(i));
    row.local_true_sws_m_s = local_cs;
    row.frequency_hz = f;
    row.field_regime = regime;

    row.hetero_mape_percent = double(I.mape_percent(i));
    row.homogeneous_mape_percent = double(h.mape_percent);
    row.delta_mape_percent = ...
        row.hetero_mape_percent - row.homogeneous_mape_percent;

    row.hetero_bias_percent = double(I.bias_percent(i));
    row.homogeneous_bias_percent = double(h.bias_percent);
    row.delta_bias_percent = ...
        row.hetero_bias_percent - row.homogeneous_bias_percent;

    row.hetero_cs_pred_median_m_s = ...
        double(I.cs_pred_median_m_s(i));

    row.homogeneous_cs_pred_median_m_s = ...
        double(h.cs_pred_median_m_s);

    row.delta_cs_pred_m_s = ...
        row.hetero_cs_pred_median_m_s - ...
        row.homogeneous_cs_pred_median_m_s;

    rows{i} = row;
end

A = struct2table(vertcat(rows{:}));

out_root = fullfile(eval_root,"inclusion_matched_transfer");
out_figs = fullfile(out_root,"figures");

if ~isfolder(out_figs), mkdir(out_figs); end

writetable(A,fullfile(out_root,"matched_transfer_summary.csv"));

xlsx_file = fullfile(out_root,"matched_transfer_metrics.xlsx");
if isfile(xlsx_file), delete(xlsx_file); end

writetable(A,xlsx_file,"Sheet","Summary");
writetable(A(A.region=="background",:),xlsx_file,"Sheet","Background");
writetable(A(A.region=="inclusion",:),xlsx_file,"Sheet","Inclusion");

make_delta_mape_figure( ...
    A(A.region=="background",:), ...
    fullfile(out_figs,"background_delta_mape.png"), ...
    "background");

make_delta_mape_figure( ...
    A(A.region=="inclusion",:), ...
    fullfile(out_figs,"inclusion_delta_mape.png"), ...
    "inclusion");

make_delta_bias_figure( ...
    A(A.region=="background",:), ...
    fullfile(out_figs,"background_delta_bias.png"), ...
    "background");

make_delta_bias_figure( ...
    A(A.region=="inclusion",:), ...
    fullfile(out_figs,"inclusion_delta_bias.png"), ...
    "inclusion");

disp(A);

fprintf("\nMean delta MAPE by region:\n");
disp(groupsummary(A,"region","mean","delta_mape_percent"));

fprintf("\nMean delta MAPE by region and regime:\n");
disp(groupsummary(A,["region","field_regime"],"mean","delta_mape_percent"));

result = struct();
result.summary = A;
result.output_root = out_root;

end


function make_delta_mape_figure(A,output_file,region)

targets = [3 4];
regimes = ["directional","intermediate","diffuse_like"];

fig = figure( ...
    "Visible","off", ...
    "Color","w", ...
    "Position",[100 100 1100 430]);

tiledlayout(1,2,"TileSpacing","compact","Padding","compact");

for k = 1:2

    target = targets(k);
    nexttile;
    hold on;

    yline(0,"--","LineWidth",1.2);

    for r = 1:numel(regimes)

        d = A( ...
            A.target_sws_m_s==target & ...
            string(A.field_regime)==regimes(r),:);

        d = sortrows(d,"frequency_hz");

        plot( ...
            d.frequency_hz, ...
            d.delta_mape_percent, ...
            "-o", ...
            "LineWidth",1.5, ...
            "DisplayName",regimes(r));
    end

    xlabel("Frequency (Hz)");
    ylabel("\DeltaMAPE (percentage points)");

    if region=="background"
        title(sprintf("Pure background, inclusion 2 -> %d m/s",target));
    else
        title(sprintf("Pure inclusion, true c_s = %d m/s",target));
    end

    grid on;
    legend("Location","best");

end

exportgraphics(fig,output_file,"Resolution",250);
close(fig);

end


function make_delta_bias_figure(A,output_file,region)

targets = [3 4];
regimes = ["directional","intermediate","diffuse_like"];

fig = figure( ...
    "Visible","off", ...
    "Color","w", ...
    "Position",[100 100 1100 430]);

tiledlayout(1,2,"TileSpacing","compact","Padding","compact");

for k = 1:2

    target = targets(k);
    nexttile;
    hold on;

    yline(0,"--","LineWidth",1.2);

    for r = 1:numel(regimes)

        d = A( ...
            A.target_sws_m_s==target & ...
            string(A.field_regime)==regimes(r),:);

        d = sortrows(d,"frequency_hz");

        plot( ...
            d.frequency_hz, ...
            d.delta_bias_percent, ...
            "-o", ...
            "LineWidth",1.5, ...
            "DisplayName",regimes(r));
    end

    xlabel("Frequency (Hz)");
    ylabel("\DeltaBias (percentage points)");

    if region=="background"
        title(sprintf("Pure background, inclusion 2 -> %d m/s",target));
    else
        title(sprintf("Pure inclusion, true c_s = %d m/s",target));
    end

    grid on;
    legend("Location","best");

end

exportgraphics(fig,output_file,"Resolution",250);
close(fig);

end
