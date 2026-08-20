function result = analyze_cs_vs_aperture()

repo_root = string(fileparts(fileparts(fileparts(mfilename("fullpath")))));

study_root = fullfile( ...
    repo_root,"outputs","validation", ...
    "angular_aperture_inplane_sweep_v1");

eval_root = fullfile(study_root,"evaluation");

R = readtable(fullfile(eval_root,"run_summary.csv"));

assert(~isempty(R),"run_summary.csv is empty.");

P_values = unique(R.in_plane_count);
M_values = unique(R.M);

analysis_root = fullfile(eval_root,"cs_vs_aperture");
fig_root = fullfile(analysis_root,"figures");

if ~isfolder(fig_root), mkdir(fig_root); end

%% Aggregate across realizations
rows = {};

for P = P_values.'
    for M = M_values.'

        alpha_values = unique( ...
            R.solid_angle_fraction( ...
                R.in_plane_count==P & R.M==M));

        for alpha = alpha_values.'

            d = R( ...
                R.in_plane_count==P & ...
                R.M==M & ...
                abs(R.solid_angle_fraction-alpha)<1e-12,:);

            row = struct();

            row.in_plane_count = P;
            row.in_plane_fraction = unique(d.in_plane_fraction);
            row.M = M;
            row.solid_angle_fraction = alpha;
            row.solid_angle_sr = unique(d.solid_angle_sr);
            row.realization_count = height(d);

            % truth should be constant here, but keep it explicit
            if ismember("cs_true_m_s", string(d.Properties.VariableNames))
                row.cs_true_m_s = median(d.cs_true_m_s,"omitnan");
            else
                row.cs_true_m_s = 2.0;
            end

            % aggregate from run-level medians
            row.cs_pred_median_m_s = median(d.cs_pred_median_m_s,"omitnan");
            row.cs_pred_q25_m_s = prctile(d.cs_pred_median_m_s,25);
            row.cs_pred_q75_m_s = prctile(d.cs_pred_median_m_s,75);

            if ismember("mape_percent", string(d.Properties.VariableNames))
                row.mape_percent_mean = mean(d.mape_percent,"omitnan");
                row.mape_percent_median = median(d.mape_percent,"omitnan");
            else
                row.mape_percent_mean = NaN;
                row.mape_percent_median = NaN;
            end

            rows{end+1,1} = row; %#ok<AGROW>
        end
    end
end

C = struct2table(vertcat(rows{:}));
C = sortrows(C, ["in_plane_count","M","solid_angle_fraction"]);

writetable(C, fullfile(analysis_root,"condition_summary.csv"));

xlsx = fullfile(analysis_root,"cs_vs_aperture_summary.xlsx");
if isfile(xlsx), delete(xlsx); end
writetable(C, xlsx, "Sheet","All");

for P = P_values.'
    writetable(C(C.in_plane_count==P,:), xlsx, "Sheet","P"+string(P));
end

%% Figures: one per in-plane count
for P = P_values.'

    fig = figure( ...
        "Visible","off", ...
        "Color","w", ...
        "Position",[100 100 1200 470]);

    tl = tiledlayout(1,2, ...
        "TileSpacing","compact", ...
        "Padding","compact");

    for mi = 1:numel(M_values)

        M = M_values(mi);

        c = C(C.in_plane_count==P & C.M==M,:);
        r = R(R.in_plane_count==P & R.M==M,:);

        ax = nexttile;
        hold(ax,"on");

        % faint realization-level medians
        scatter( ...
            r.solid_angle_fraction, ...
            r.cs_pred_median_m_s, ...
            18, ...
            "o", ...
            "MarkerEdgeAlpha",0.18, ...
            "HandleVisibility","off");

        % aggregated median +/- IQR
        y = c.cs_pred_median_m_s;
        lo = y - c.cs_pred_q25_m_s;
        hi = c.cs_pred_q75_m_s - y;

        errorbar( ...
            c.solid_angle_fraction, ...
            y, lo, hi, ...
            "-o", ...
            "LineWidth",1.8, ...
            "MarkerSize",5, ...
            "DisplayName","Q0 median");

        % truth line
        yline(c.cs_true_m_s(1),"--", ...
            "LineWidth",1.5, ...
            "DisplayName","truth");

        xlabel("\Omega / 4\pi");
        ylabel("Predicted c_s (m/s)");
        title(sprintf("M = %d",M));

        xlim([0 1]);

        % adaptive y-limits with small padding
        ymin = min([r.cs_pred_median_m_s; c.cs_true_m_s]) - 0.02;
        ymax = max([r.cs_pred_median_m_s; c.cs_true_m_s]) + 0.02;
        ylim([ymin ymax]);

        grid on;
        box on;
        legend("Location","best");
    end

    title(tl, sprintf( ...
        "N = 2000, N_{in-plane} = %d (%.1f%%), c_s = 2 m/s", ...
        P,100*P/2000));

    file = fullfile( ...
        fig_root, ...
        sprintf("cs_vs_aperture_P%04d.png",P));

    exportgraphics(fig,file,"Resolution",250);
    close(fig);
end

%% Console summary
fprintf("\ncs vs aperture analysis\n");
fprintf("=======================\n");

for P = P_values.'

    fprintf("\nP = %d (%.1f%% in-plane)\n",P,100*P/2000);

    for M = M_values.'
        d = C(C.in_plane_count==P & C.M==M,:);

        fprintf("  M=%d | mean MAPE = %.3f %% | ", ...
            M,mean(d.mape_percent_mean,"omitnan"));

        fprintf("cs_pred(full sphere) = %.4f m/s\n", ...
            d.cs_pred_median_m_s(end));
    end
end

fprintf("\nFigures saved to:\n%s\n",fig_root);

result = struct();
result.run_summary = R;
result.condition_summary = C;
result.output_root = analysis_root;

end
