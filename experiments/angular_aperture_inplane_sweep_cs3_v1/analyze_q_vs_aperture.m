function result = analyze_q_vs_aperture()

repo_root = string(fileparts(fileparts(fileparts(mfilename("fullpath")))));

study_root = fullfile( ...
    repo_root,"outputs","validation", ...
    "angular_aperture_inplane_sweep_cs3_v1");

eval_root = fullfile(study_root,"evaluation");

R = readtable(fullfile(eval_root,"run_summary.csv"));

assert(height(R)==684, ...
    "Expected 684 run-level evaluations, found %d.",height(R));

P_values = unique(R.in_plane_count);
M_values = unique(R.M);

analysis_root = fullfile(eval_root,"q_vs_aperture");
fig_root = fullfile(analysis_root,"figures");

if ~isfolder(fig_root), mkdir(fig_root); end

%% Aggregate across the 3 realizations
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

            assert(height(d)==3, ...
                "Expected 3 realizations for P=%d M=%d alpha=%g.", ...
                P,M,alpha);

            row = struct();

            row.in_plane_count = P;
            row.in_plane_fraction = unique(d.in_plane_fraction);
            row.M = M;
            row.solid_angle_fraction = alpha;
            row.solid_angle_sr = unique(d.solid_angle_sr);
            row.realization_count = height(d);

            % Each realization contributes one patchwise median.
            row.q_oracle_median = ...
                median(d.q_oracle_median,"omitnan");
            row.q_oracle_q25 = ...
                prctile(d.q_oracle_median,25);
            row.q_oracle_q75 = ...
                prctile(d.q_oracle_median,75);

            row.q_pred_median = ...
                median(d.q_pred_median,"omitnan");
            row.q_pred_q25 = ...
                prctile(d.q_pred_median,25);
            row.q_pred_q75 = ...
                prctile(d.q_pred_median,75);

            row.q_error_median = ...
                median(d.q_error_median,"omitnan");

            row.q_abs_error_mean = ...
                mean(d.q_abs_error_mean,"omitnan");

            rows{end+1,1} = row; %#ok<AGROW>
        end
    end
end

C = struct2table(vertcat(rows{:}));

C = sortrows(C, ...
    ["in_plane_count","M","solid_angle_fraction"]);

writetable(C,fullfile(analysis_root,"condition_summary.csv"));

xlsx = fullfile(analysis_root,"q_vs_aperture_summary.xlsx");
if isfile(xlsx), delete(xlsx); end

writetable(C,xlsx,"Sheet","All");

for P = P_values.'
    writetable( ...
        C(C.in_plane_count==P,:), ...
        xlsx, ...
        "Sheet","P"+string(P));
end

%% One figure per in-plane count
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

        % Individual realization medians
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

        % Oracle
        y = c.q_oracle_median;
        lo = y-c.q_oracle_q25;
        hi = c.q_oracle_q75-y;

        errorbar( ...
            c.solid_angle_fraction, ...
            y,lo,hi, ...
            "-o", ...
            "LineWidth",1.8, ...
            "MarkerSize",5, ...
            "DisplayName","q oracle");

        % Prediction
        y = c.q_pred_median;
        lo = y-c.q_pred_q25;
        hi = c.q_pred_q75-y;

        errorbar( ...
            c.solid_angle_fraction, ...
            y,lo,hi, ...
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
        "N = 2000, N_{in-plane} = %d (%.1f%%), c_s = 3 m/s", ...
        P,100*P/2000));

    file = fullfile( ...
        fig_root, ...
        sprintf("q_vs_aperture_P%04d.png",P));

    exportgraphics(fig,file,"Resolution",250);
    close(fig);
end

%% Compact numerical summary
fprintf("\nq vs aperture analysis\n");
fprintf("======================\n");

for P = P_values.'

    fprintf("\nP = %d (%.1f%% in-plane)\n",P,100*P/2000);

    for M = M_values.'

        d = C(C.in_plane_count==P & C.M==M,:);

        fprintf("  M=%d | mean q MAE = %.4f | ", ...
            M,mean(d.q_abs_error_mean,"omitnan"));

        fprintf("q_oracle(full sphere) = %.4f | ", ...
            d.q_oracle_median(end));

        fprintf("q_pred(full sphere) = %.4f\n", ...
            d.q_pred_median(end));
    end
end

fprintf("\nFigures saved to:\n%s\n",fig_root);

result = struct();
result.run_summary = R;
result.condition_summary = C;
result.output_root = analysis_root;

end
