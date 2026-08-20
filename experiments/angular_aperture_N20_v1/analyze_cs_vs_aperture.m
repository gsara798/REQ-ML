function result = analyze_cs_vs_aperture()

repo_root = string(fileparts(fileparts(fileparts(mfilename("fullpath")))));

study_root = fullfile( ...
    repo_root,"outputs","validation","angular_aperture_N20_v1");

eval_root = fullfile(study_root,"evaluation");

R = readtable(fullfile(eval_root,"run_summary.csv"));

cs_values = unique(R.cs_true_m_s);
P_values = unique(R.in_plane_count);
M_values = unique(R.M);

analysis_root = fullfile(eval_root,"cs_vs_aperture");
fig_root = fullfile(analysis_root,"figures");

if ~isfolder(fig_root), mkdir(fig_root); end

rows = {};

for cs = cs_values.'
    for P = P_values.'
        for M = M_values.'

            alpha_values = unique( ...
                R.solid_angle_fraction( ...
                    R.cs_true_m_s==cs & ...
                    R.in_plane_count==P & ...
                    R.M==M));

            for alpha = alpha_values.'

                d = R( ...
                    R.cs_true_m_s==cs & ...
                    R.in_plane_count==P & ...
                    R.M==M & ...
                    abs(R.solid_angle_fraction-alpha)<1e-12,:);

                assert(height(d)==3, ...
                    "Expected 3 realizations.");

                row = struct();

                row.cs_true_m_s = cs;
                row.in_plane_count = P;
                row.in_plane_fraction = unique(d.in_plane_fraction);
                row.M = M;
                row.solid_angle_fraction = alpha;
                row.solid_angle_sr = unique(d.solid_angle_sr);
                row.realization_count = height(d);

                row.cs_pred_median_m_s = ...
                    median(d.cs_pred_median_m_s,"omitnan");
                row.cs_pred_q25_m_s = ...
                    prctile(d.cs_pred_median_m_s,25);
                row.cs_pred_q75_m_s = ...
                    prctile(d.cs_pred_median_m_s,75);

                row.mape_mean_percent = ...
                    mean(d.mape_percent,"omitnan");
                row.mape_median_percent = ...
                    median(d.mape_percent,"omitnan");

                row.bias_mean_percent = ...
                    mean(d.bias_percent,"omitnan");

                rows{end+1,1} = row; %#ok<AGROW>
            end
        end
    end
end

C = struct2table(vertcat(rows{:}));

C = sortrows(C, ...
    ["cs_true_m_s","in_plane_count","M","solid_angle_fraction"]);

writetable(C,fullfile(analysis_root,"condition_summary.csv"));

xlsx = fullfile(analysis_root,"cs_vs_aperture_summary.xlsx");
if isfile(xlsx), delete(xlsx); end
writetable(C,xlsx,"Sheet","All");

%% One figure per cs and P
for cs = cs_values.'
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

            c = C( ...
                C.cs_true_m_s==cs & ...
                C.in_plane_count==P & ...
                C.M==M,:);

            r = R( ...
                R.cs_true_m_s==cs & ...
                R.in_plane_count==P & ...
                R.M==M,:);

            ax = nexttile;
            hold(ax,"on");

            % realization-level medians
            scatter( ...
                r.solid_angle_fraction, ...
                r.cs_pred_median_m_s, ...
                16, ...
                "Marker","o", ...
                "MarkerEdgeAlpha",0.20, ...
                "HandleVisibility","off");

            % aggregate median +/- IQR
            y = c.cs_pred_median_m_s;
            lo = y-c.cs_pred_q25_m_s;
            hi = c.cs_pred_q75_m_s-y;

            errorbar( ...
                c.solid_angle_fraction,y,lo,hi, ...
                "-o", ...
                "LineWidth",1.8, ...
                "MarkerSize",5, ...
                "DisplayName","Q0 median");

            % truth
            yline(cs,"--", ...
                "LineWidth",1.4, ...
                "DisplayName","truth");

            xlabel("\Omega / 4\pi");
            ylabel("Predicted c_s (m/s)");
            title(sprintf("M = %d",M));

            xlim([0 1]);

            all_y = [ ...
                r.cs_pred_median_m_s; ...
                c.cs_pred_q25_m_s; ...
                c.cs_pred_q75_m_s; ...
                cs];

            pad = max(0.03,0.08*(max(all_y)-min(all_y)));

            ylim([min(all_y)-pad,max(all_y)+pad]);

            grid on;
            box on;
            legend("Location","best");
        end

        title(tl,sprintf( ...
            "N = 20, N_{in-plane} = %d (%.0f%%), c_s = %.0f m/s", ...
            P,100*P/20,cs));

        file = fullfile( ...
            fig_root, ...
            sprintf("cs_vs_aperture_cs%d_P%02d.png",round(cs),P));

        exportgraphics(fig,file,"Resolution",250);
        close(fig);
    end
end

%% Console summary
fprintf("\nN=20 cs-vs-aperture analysis\n");
fprintf("============================\n");

for cs = cs_values.'

    fprintf("\nc_s = %.0f m/s\n",cs);

    for P = P_values.'

        fprintf("  P=%d (%g%%)\n",P,100*P/20);

        for M = M_values.'

            d = C( ...
                C.cs_true_m_s==cs & ...
                C.in_plane_count==P & ...
                C.M==M,:);

            fprintf( ...
                "    M=%d | mean MAPE=%.3f%% | full-sphere c_s=%.4f m/s\n", ...
                M, ...
                mean(d.mape_mean_percent,"omitnan"), ...
                d.cs_pred_median_m_s(end));
        end
    end
end

fprintf("\nFigures saved to:\n%s\n",fig_root);

result = struct();
result.run_summary = R;
result.condition_summary = C;
result.output_root = analysis_root;

end
