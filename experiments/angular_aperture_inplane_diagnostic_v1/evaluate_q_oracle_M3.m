function result = evaluate_q_oracle_M3()

repo_root = string(fileparts(fileparts(fileparts(mfilename("fullpath")))));

config_file = fullfile( ...
    repo_root,"configs","validation", ...
    "angular_aperture_inplane_diagnostic_v1.json");

cfg = jsondecode(fileread(config_file));

study_root = replace( ...
    string(cfg.paths.output_root), ...
    "${REPOSITORY_ROOT}",repo_root);

simulation_root = fullfile( ...
    study_root,"simulations", ...
    "angular_aperture_inplane_diagnostic_v1");

campaign_summary_file = fullfile( ...
    simulation_root,"campaign_summary.json");

assert(isfile(campaign_summary_file), ...
    "Missing campaign summary: %s",campaign_summary_file);

campaign = jsondecode(fileread(campaign_summary_file));

assert(campaign.completed_count==campaign.run_count);
assert(campaign.failed_count==0);

[~,planned,~] = materialize_design();

M = 3;
cs_guess = double(cfg.req.cs_guess_m_s);
step_pixels = double(cfg.req.step_pixels);

output_root = fullfile(study_root,"evaluation_M3");
runs_root = fullfile(output_root,"runs");

if ~isfolder(runs_root)
    mkdir(runs_root);
end

pool = gcp("nocreate");
if isempty(pool)
    pool = parpool("Processes");
end

fprintf("\nIn-plane q_oracle diagnostic\n");
fprintf("============================\n");
fprintf("Runs     : %d\n",campaign.run_count);
fprintf("M        : %g\n",M);
fprintf("cs_guess : %.3f m/s\n",cs_guess);
fprintf("Step     : %d pixels\n\n",step_pixels);

summary_rows = cell(campaign.run_count,1);

for irun = 1:campaign.run_count

    cr = campaign.runs(irun);

    design_id = string(cr.design_id);
    run_id = string(cr.run_id);

    match = planned.run_id==design_id;
    assert(nnz(match)==1, ...
        "Could not map %s to planned design.",design_id);

    p = planned(match,:);

    fprintf("[%02d/%02d] %s | cs=%.1f | P=%d | P/N=%.4f\n", ...
        irun,campaign.run_count,run_id, ...
        p.cs_true_m_s, ...
        p.in_plane_count, ...
        p.in_plane_fraction);

    sample_file = fullfile( ...
        string(cr.run_directory), ...
        "data","wavefield_sample.mat");

    assert(isfile(sample_file), ...
        "Missing sample: %s",sample_file);

    data = reqml.io.load_wavefield_sample(sample_file);

    feature_config = reqml.config.default_feature_config( ...
        "M",M, ...
        "cs_guess",cs_guess);

    dataset = reqml.datasets.extract_examples_from_sample( ...
        data, ...
        feature_config, ...
        DatasetId="angular_aperture_inplane_diagnostic_v1", ...
        SampleId=design_id, ...
        StepX=step_pixels, ...
        StepZ=step_pixels, ...
        StoreReqCurves=false, ...
        UseWindowParfor=true, ...
        RequireTruth=true);

    e = dataset.examples;

    valid = logical(e.target_valid) & ...
        isfinite(e.q_target_from_center_truth);

    q = double(e.q_target_from_center_truth(valid));

    assert(~isempty(q), ...
        "No valid q_oracle values for %s.",design_id);

    T = table( ...
        string(e.example_id(valid)), ...
        double(e.x_center_m(valid)), ...
        double(e.z_center_m(valid)), ...
        double(e.target_k_center_rad_m(valid)), ...
        q, ...
        VariableNames=[ ...
            "example_id", ...
            "x_center_m", ...
            "z_center_m", ...
            "k_true_rad_m", ...
            "q_oracle"]);

    run_out = fullfile(runs_root,run_id);
    if ~isfolder(run_out), mkdir(run_out); end

    save(fullfile(run_out,"q_oracle_metrics.mat"), ...
        "T","-v7.3");

    row = struct();

    row.run_id = run_id;
    row.design_id = design_id;

    row.cs_true_m_s = double(p.cs_true_m_s);
    row.frequency_hz = double(p.frequency_hz);

    row.direction_count = double(p.direction_count);
    row.in_plane_count = double(p.in_plane_count);
    row.in_plane_fraction = double(p.in_plane_fraction);

    row.solid_angle_fraction = double(p.solid_angle_fraction);
    row.solid_angle_sr = double(p.solid_angle_sr);

    row.patch_count = numel(q);

    row.q_oracle_mean = mean(q,"omitnan");
    row.q_oracle_median = median(q,"omitnan");
    row.q_oracle_q25 = prctile(q,25);
    row.q_oracle_q75 = prctile(q,75);
    row.q_oracle_min = min(q);
    row.q_oracle_max = max(q);

    summary_rows{irun} = row;

    fprintf("           patches=%d | median q=%.4f | IQR=[%.4f, %.4f]\n", ...
        row.patch_count, ...
        row.q_oracle_median, ...
        row.q_oracle_q25, ...
        row.q_oracle_q75);
end

S = struct2table(vertcat(summary_rows{:}));
S = sortrows(S,["cs_true_m_s","in_plane_fraction"]);

writetable(S,fullfile(output_root,"q_oracle_summary.csv"));

xlsx = fullfile(output_root,"q_oracle_inplane_diagnostic.xlsx");
if isfile(xlsx), delete(xlsx); end

writetable(S,xlsx,"Sheet","Summary");

for cs = unique(S.cs_true_m_s).'
    writetable( ...
        S(S.cs_true_m_s==cs,:), ...
        xlsx, ...
        "Sheet","cs_"+string(round(cs)));
end

make_figure(S,output_root);

fprintf("\nDiagnostic complete.\n");
disp(S(:,[ ...
    "cs_true_m_s", ...
    "in_plane_count", ...
    "in_plane_fraction", ...
    "q_oracle_median", ...
    "q_oracle_q25", ...
    "q_oracle_q75"]));

result = struct();
result.summary = S;
result.output_root = output_root;

end


function make_figure(S,output_root)

cs_values = unique(S.cs_true_m_s);

fig = figure( ...
    "Visible","off", ...
    "Color","w", ...
    "Position",[100 100 1100 430]);

tl = tiledlayout(1,numel(cs_values), ...
    "TileSpacing","compact", ...
    "Padding","compact");

for i = 1:numel(cs_values)

    cs = cs_values(i);
    d = S(S.cs_true_m_s==cs,:);
    d = sortrows(d,"in_plane_fraction");

    ax = nexttile;
    hold(ax,"on");

    y = d.q_oracle_median;
    lo = y-d.q_oracle_q25;
    hi = d.q_oracle_q75-y;

    errorbar( ...
        100*d.in_plane_fraction, ...
        y, ...
        lo, ...
        hi, ...
        "-o", ...
        "LineWidth",1.8, ...
        "MarkerSize",6);

    yline(0.94,"--", ...
        "DisplayName","paper reference ~0.94");

    xlabel("Exactly in-plane components (%)");
    ylabel("q_{oracle}");

    title(sprintf("c_s = %.0f m/s",cs));

    ylim([0 1]);
    grid on;
    box on;
    legend("Location","best");

end

title(tl, ...
    "Full-sphere q_{oracle} versus exactly in-plane fraction");

fig_dir = fullfile(output_root,"figures");
if ~isfolder(fig_dir), mkdir(fig_dir); end

exportgraphics( ...
    fig, ...
    fullfile(fig_dir,"q_oracle_vs_inplane_fraction.png"), ...
    "Resolution",250);

close(fig);

end
