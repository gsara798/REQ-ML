function result = analyze_results()

repo_root = string(fileparts(fileparts(fileparts(mfilename("fullpath")))));

eval_root = fullfile( ...
    repo_root,"outputs","validation", ...
    "angular_aperture_validation_v1","evaluation");

run_file = fullfile(eval_root,"run_summary.csv");
assert(isfile(run_file),"Missing %s",run_file);

R = readtable(run_file);

assert(height(R)==190, ...
    "Expected 190 evaluated runs, found %d.",height(R));

%% Aggregate at the physical-condition level.
% Statistical unit = realization.
% Each realization contributes one patchwise summary value.

cs_values = unique(R.cs_true_m_s);
alpha_values = unique(R.solid_angle_fraction);

rows = cell(numel(cs_values)*numel(alpha_values),1);
k = 0;

for ci = 1:numel(cs_values)

    cs = cs_values(ci);

    for ai = 1:numel(alpha_values)

        alpha = alpha_values(ai);

        d = R( ...
            abs(R.cs_true_m_s-cs)<1e-12 & ...
            abs(R.solid_angle_fraction-alpha)<1e-12,:);

        assert(height(d)==5, ...
            "Expected 5 realizations for cs=%g alpha=%g; found %d.", ...
            cs,alpha,height(d));

        k = k+1;

        row = struct();

        row.cs_true_m_s = cs;
        row.frequency_hz = unique(d.frequency_hz);
        row.solid_angle_fraction = alpha;
        row.solid_angle_sr = unique(d.solid_angle_sr);
        row.realization_count = height(d);

        % q oracle: one patchwise median per realization
        row.q_oracle_median = ...
            median(d.q_oracle_median,"omitnan");
        row.q_oracle_q25 = ...
            prctile(d.q_oracle_median,25);
        row.q_oracle_q75 = ...
            prctile(d.q_oracle_median,75);

        % q predicted
        row.q_pred_median = ...
            median(d.q_pred_median,"omitnan");
        row.q_pred_q25 = ...
            prctile(d.q_pred_median,25);
        row.q_pred_q75 = ...
            prctile(d.q_pred_median,75);

        % q error
        row.q_error_median = ...
            median(d.q_error_median,"omitnan");
        row.q_error_q25 = ...
            prctile(d.q_error_median,25);
        row.q_error_q75 = ...
            prctile(d.q_error_median,75);

        row.q_abs_error_mean_across_runs = ...
            mean(d.q_abs_error_mean,"omitnan");

        % SWS prediction
        row.cs_pred_median_m_s = ...
            median(d.cs_pred_median_m_s,"omitnan");
        row.cs_pred_q25_m_s = ...
            prctile(d.cs_pred_median_m_s,25);
        row.cs_pred_q75_m_s = ...
            prctile(d.cs_pred_median_m_s,75);

        % SWS error
        row.mape_median_percent = ...
            median(d.mape_percent,"omitnan");
        row.mape_q25_percent = ...
            prctile(d.mape_percent,25);
        row.mape_q75_percent = ...
            prctile(d.mape_percent,75);
        row.mape_mean_percent = ...
            mean(d.mape_percent,"omitnan");

        row.bias_median_percent = ...
            median(d.bias_percent,"omitnan");

        rows{k}=row;
    end
end

C = struct2table(vertcat(rows{:}));
C = sortrows(C,["cs_true_m_s","solid_angle_fraction"]);

%% Output

analysis_root = fullfile(eval_root,"angular_analysis");
fig_root = fullfile(analysis_root,"figures");

if ~isfolder(fig_root)
    mkdir(fig_root);
end

writetable(C,fullfile(analysis_root,"condition_summary.csv"));

xlsx = fullfile(analysis_root,"angular_aperture_metrics.xlsx");
if isfile(xlsx), delete(xlsx); end

writetable(C,xlsx,"Sheet","ConditionSummary");
writetable(R,xlsx,"Sheet","RunSummary");

for cs = cs_values.'
    writetable( ...
        C(C.cs_true_m_s==cs,:), ...
        xlsx, ...
        "Sheet","cs_"+string(round(cs)));
end

%% Figures

make_q_tracking_figure(C,R,fig_root);
make_q_error_figure(C,R,fig_root);
make_cs_figure(C,R,fig_root);
make_mape_figure(C,R,fig_root);

%% Numerical diagnostics

fprintf("\nAngular aperture analysis\n");
fprintf("=========================\n");

for cs = cs_values.'

    d = C(C.cs_true_m_s==cs,:);

    fprintf("\nc_s = %.1f m/s\n",cs);
    fprintf("----------------\n");

    fprintf("Median condition q |error| : %.4f\n", ...
        median(d.q_abs_error_mean_across_runs,"omitnan"));

    fprintf("Mean condition MAPE        : %.3f %%\n", ...
        mean(d.mape_mean_percent,"omitnan"));

    [worst_mape,idx] = max(d.mape_mean_percent);

    fprintf("Worst aperture MAPE        : %.3f %%\n",worst_mape);
    fprintf("  alpha = %.6f\n",d.solid_angle_fraction(idx));
    fprintf("  Omega = %.4f sr\n",d.solid_angle_sr(idx));

    [worst_q,idxq] = max(d.q_abs_error_mean_across_runs);

    fprintf("Worst q absolute error     : %.4f\n",worst_q);
    fprintf("  alpha = %.6f\n",d.solid_angle_fraction(idxq));
    fprintf("  Omega = %.4f sr\n",d.solid_angle_sr(idxq));
end

%% Overall q tracking correlation at run-summary level

valid = ...
    isfinite(R.q_oracle_median) & ...
    isfinite(R.q_pred_median);

rho = corr( ...
    R.q_oracle_median(valid), ...
    R.q_pred_median(valid), ...
    "Type","Pearson");

fprintf("\nRun-level q tracking correlation: %.4f\n",rho);

fprintf("\nSaved analysis:\n%s\n",analysis_root);

result = struct();
result.run_summary = R;
result.condition_summary = C;
result.q_tracking_correlation = rho;
result.output_root = analysis_root;

end


function make_q_tracking_figure(C,R,fig_root)

cs_values = unique(C.cs_true_m_s);

fig = figure( ...
    "Visible","off", ...
    "Color","w", ...
    "Position",[100 100 1200 480]);

tl = tiledlayout(1,numel(cs_values), ...
    "TileSpacing","compact", ...
    "Padding","compact");

for i = 1:numel(cs_values)

    cs = cs_values(i);

    c = C(C.cs_true_m_s==cs,:);
    r = R(R.cs_true_m_s==cs,:);

    ax = nexttile;
    hold(ax,"on");

    % Individual realization medians
    scatter( ...
        r.solid_angle_fraction, ...
        r.q_oracle_median, ...
        16, ...
        "Marker","o", ...
        "MarkerEdgeAlpha",0.20, ...
        "HandleVisibility","off");

    scatter( ...
        r.solid_angle_fraction, ...
        r.q_pred_median, ...
        16, ...
        "Marker","x", ...
        "MarkerEdgeAlpha",0.20, ...
        "HandleVisibility","off");

    % Oracle condition summary
    y = c.q_oracle_median;
    lo = y-c.q_oracle_q25;
    hi = c.q_oracle_q75-y;

    errorbar( ...
        c.solid_angle_fraction,y,lo,hi, ...
        "-o", ...
        "LineWidth",1.8, ...
        "MarkerSize",5, ...
        "DisplayName","q oracle");

    % Q0 condition summary
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
    title(sprintf("c_s = %.0f m/s",cs));

    xlim([0 1]);
    ylim([0 1]);

    grid on;
    box on;
    legend("Location","best");

end

title(tl, ...
    "Continuous angular-aperture quantile tracking");

exportgraphics( ...
    fig, ...
    fullfile(fig_root,"q_pred_vs_q_oracle.png"), ...
    "Resolution",250);

close(fig);

end


function make_q_error_figure(C,R,fig_root)

cs_values = unique(C.cs_true_m_s);

fig = figure( ...
    "Visible","off", ...
    "Color","w", ...
    "Position",[100 100 1200 480]);

tl = tiledlayout(1,numel(cs_values), ...
    "TileSpacing","compact", ...
    "Padding","compact");

for i = 1:numel(cs_values)

    cs = cs_values(i);

    c = C(C.cs_true_m_s==cs,:);
    r = R(R.cs_true_m_s==cs,:);

    ax = nexttile;
    hold(ax,"on");

    yline(0,"--","LineWidth",1.1);

    scatter( ...
        r.solid_angle_fraction, ...
        r.q_error_median, ...
        16, ...
        "MarkerEdgeAlpha",0.25, ...
        "HandleVisibility","off");

    y = c.q_error_median;
    lo = y-c.q_error_q25;
    hi = c.q_error_q75-y;

    errorbar( ...
        c.solid_angle_fraction,y,lo,hi, ...
        "-o", ...
        "LineWidth",1.8, ...
        "MarkerSize",5);

    xlabel("\Omega / 4\pi");
    ylabel("q_{pred} - q_{oracle}");
    title(sprintf("c_s = %.0f m/s",cs));

    xlim([0 1]);
    grid on;
    box on;

end

title(tl,"Q0 quantile error across angular aperture");

exportgraphics( ...
    fig, ...
    fullfile(fig_root,"q_error_vs_aperture.png"), ...
    "Resolution",250);

close(fig);

end


function make_cs_figure(C,R,fig_root)

cs_values = unique(C.cs_true_m_s);

fig = figure( ...
    "Visible","off", ...
    "Color","w", ...
    "Position",[100 100 1200 480]);

tl = tiledlayout(1,numel(cs_values), ...
    "TileSpacing","compact", ...
    "Padding","compact");

for i = 1:numel(cs_values)

    cs = cs_values(i);

    c = C(C.cs_true_m_s==cs,:);
    r = R(R.cs_true_m_s==cs,:);

    ax = nexttile;
    hold(ax,"on");

    yline(cs,"--","LineWidth",1.2, ...
        "DisplayName","truth");

    scatter( ...
        r.solid_angle_fraction, ...
        r.cs_pred_median_m_s, ...
        16, ...
        "MarkerEdgeAlpha",0.25, ...
        "HandleVisibility","off");

    y = c.cs_pred_median_m_s;
    lo = y-c.cs_pred_q25_m_s;
    hi = c.cs_pred_q75_m_s-y;

    errorbar( ...
        c.solid_angle_fraction,y,lo,hi, ...
        "-o", ...
        "LineWidth",1.8, ...
        "MarkerSize",5, ...
        "DisplayName","Q0 median");

    xlabel("\Omega / 4\pi");
    ylabel("Predicted c_s (m/s)");
    title(sprintf("c_s = %.0f m/s",cs));

    xlim([0 1]);
    grid on;
    box on;
    legend("Location","best");

end

title(tl,"SWS estimation across angular aperture");

exportgraphics( ...
    fig, ...
    fullfile(fig_root,"cs_pred_vs_aperture.png"), ...
    "Resolution",250);

close(fig);

end


function make_mape_figure(C,R,fig_root)

cs_values = unique(C.cs_true_m_s);

fig = figure( ...
    "Visible","off", ...
    "Color","w", ...
    "Position",[100 100 1200 480]);

tl = tiledlayout(1,numel(cs_values), ...
    "TileSpacing","compact", ...
    "Padding","compact");

for i = 1:numel(cs_values)

    cs = cs_values(i);

    c = C(C.cs_true_m_s==cs,:);
    r = R(R.cs_true_m_s==cs,:);

    ax = nexttile;
    hold(ax,"on");

    scatter( ...
        r.solid_angle_fraction, ...
        r.mape_percent, ...
        16, ...
        "MarkerEdgeAlpha",0.25, ...
        "HandleVisibility","off");

    y = c.mape_median_percent;
    lo = y-c.mape_q25_percent;
    hi = c.mape_q75_percent-y;

    errorbar( ...
        c.solid_angle_fraction,y,lo,hi, ...
        "-o", ...
        "LineWidth",1.8, ...
        "MarkerSize",5);

    xlabel("\Omega / 4\pi");
    ylabel("MAPE (%)");
    title(sprintf("c_s = %.0f m/s",cs));

    xlim([0 1]);
    grid on;
    box on;

end

title(tl,"SWS error across angular aperture");

exportgraphics( ...
    fig, ...
    fullfile(fig_root,"mape_vs_aperture.png"), ...
    "Resolution",250);

close(fig);

end
