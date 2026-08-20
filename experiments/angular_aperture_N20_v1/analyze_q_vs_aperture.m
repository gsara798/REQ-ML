function result = analyze_q_vs_aperture()

repo_root = string(fileparts(fileparts(fileparts(mfilename("fullpath")))));

study_root = fullfile( ...
    repo_root,"outputs","validation","angular_aperture_N20_v1");

eval_root = fullfile(study_root,"evaluation");

R = readtable(fullfile(eval_root,"run_summary.csv"));

cs_values = unique(R.cs_true_m_s);
P_values = unique(R.in_plane_count);
M_values = unique(R.M);

analysis_root = fullfile(eval_root,"q_vs_aperture");
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

                assert(height(d)==3);

                row = struct();

                row.cs_true_m_s = cs;
                row.in_plane_count = P;
                row.in_plane_fraction = unique(d.in_plane_fraction);
                row.M = M;
                row.solid_angle_fraction = alpha;
                row.solid_angle_sr = unique(d.solid_angle_sr);

                row.q_oracle_median = median(d.q_oracle_median,"omitnan");
                row.q_oracle_q25 = prctile(d.q_oracle_median,25);
                row.q_oracle_q75 = prctile(d.q_oracle_median,75);

                row.q_pred_median = median(d.q_pred_median,"omitnan");
                row.q_pred_q25 = prctile(d.q_pred_median,25);
                row.q_pred_q75 = prctile(d.q_pred_median,75);

                row.q_abs_error_mean = mean(d.q_abs_error_mean,"omitnan");

                rows{end+1,1} = row; %#ok<AGROW>
            end
        end
    end
end

C = struct2table(vertcat(rows{:}));

C = sortrows(C, ...
    ["cs_true_m_s","in_plane_count","M","solid_angle_fraction"]);

writetable(C,fullfile(analysis_root,"condition_summary.csv"));

xlsx = fullfile(analysis_root,"q_vs_aperture_summary.xlsx");
if isfile(xlsx), delete(xlsx); end
writetable(C,xlsx,"Sheet","All");

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

            scatter( ...
                r.solid_angle_fraction, ...
                r.q_oracle_median, ...
                14, ...
                "Marker","o", ...
                "MarkerEdgeAlpha",0.18, ...
                "HandleVisibility","off");

            scatter( ...
                r.solid_angle_fraction, ...
                r.q_pred_median, ...
                14, ...
                "Marker","x", ...
                "MarkerEdgeAlpha",0.18, ...
                "HandleVisibility","off");

            y = c.q_oracle_median;
            lo = y-c.q_oracle_q25;
            hi = c.q_oracle_q75-y;

            errorbar( ...
                c.solid_angle_fraction,y,lo,hi, ...
                "-o", ...
                "LineWidth",1.8, ...
                "MarkerSize",5, ...
                "DisplayName","q oracle");

            y = c.q_pred_median;
            lo = y-c.q_pred_q25;
            hi = c.q_pred_q75-y;

            errorbar( ...
                c.solid_angle_fraction,y,lo,hi, ...
                "-s", ...
                "LineWidth",1.8, ...
                "MarkerSize",5, ...
                "DisplayName","Q0 prediction");

            xlabel("\Omega / 4\pi");
            ylabel("REQ quantile q");
            title(sprintf("M = %d",M));

            xlim([0 1]);
            ylim([0 1]);

            grid on;
            box on;
            legend("Location","best");
        end

        title(tl,sprintf( ...
            "N = 20, N_{in-plane} = %d (%.0f%%), c_s = %.0f m/s", ...
            P,100*P/20,cs));

        file = fullfile( ...
            fig_root, ...
            sprintf("q_vs_aperture_cs%d_P%02d.png",round(cs),P));

        exportgraphics(fig,file,"Resolution",250);
        close(fig);
    end
end

fprintf("\nSaved q-vs-aperture figures to:\n%s\n",fig_root);

result = struct();
result.run_summary = R;
result.condition_summary = C;
result.output_root = analysis_root;

end
