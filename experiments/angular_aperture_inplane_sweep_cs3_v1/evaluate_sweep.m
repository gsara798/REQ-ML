function result = evaluate_sweep()

repo_root = string(fileparts(fileparts(fileparts(mfilename("fullpath")))));

%% Config
config_file = fullfile( ...
    repo_root,"configs","validation", ...
    "angular_aperture_inplane_sweep_cs3_v1.json");

fprintf("\n[setup] Loading config...\n");
cfg = jsondecode(fileread(config_file));

study_root = replace( ...
    string(cfg.paths.output_root), ...
    "${REPOSITORY_ROOT}",repo_root);

simulation_root = fullfile( ...
    study_root,"simulations","angular_aperture_inplane_sweep_cs3_v1");

campaign_summary_file = fullfile( ...
    simulation_root,"campaign_summary.json");

assert(isfile(campaign_summary_file), ...
    "Missing campaign summary: %s",campaign_summary_file);

campaign = jsondecode(fileread(campaign_summary_file));

assert(campaign.failed_count==0, ...
    "Campaign still contains failed runs.");
assert(campaign.completed_count + campaign.skipped_count == campaign.run_count, ...
    "Campaign is incomplete.");

fprintf("[setup] Simulations available: %d\n",campaign.run_count);

%% Planned design
planned_file = fullfile( ...
    study_root,"campaign","planned_runs.csv");

assert(isfile(planned_file), ...
    "Missing planned design: %s",planned_file);

planned = readtable(planned_file);

%% Frozen Q0
model_file = fullfile( ...
    repo_root,"outputs","homogeneous_cartesian_q0_v2", ...
    "training","final_frozen_q0_v2","model_bundle.mat");

assert(isfile(model_file), ...
    "Frozen Q0 not found: %s",model_file);

fprintf("[setup] Loading frozen Q0...\n");
tmodel = tic;

B = load(model_file,"model","model_metadata","predictor_names");

bundle = struct();
bundle.model = B.model;
bundle.predictor_names = string(B.predictor_names(:));

if isfield(B,"model_metadata")
    bundle.model_metadata = B.model_metadata;
end

fprintf("[setup] Model loaded in %.2f s\n",toc(tmodel));
fprintf("[setup] Predictors: %d\n",numel(bundle.predictor_names));

%% Analysis settings
M_values = double(cfg.req.M_values(:)).';
cs_guess = double(cfg.req.cs_guess_m_s);
step_pixels = double(cfg.req.step_pixels);

fprintf("[setup] M values: %s\n",char(strjoin(string(M_values),", ")));
fprintf("[setup] cs_guess: %.1f m/s\n",cs_guess);
fprintf("[setup] StepPixels: %d\n",step_pixels);

%% Output
output_root = fullfile(study_root,"evaluation");
runs_root = fullfile(output_root,"runs");

if ~isfolder(runs_root)
    mkdir(runs_root);
end

%% Parallel pool
pool = gcp("nocreate");

if isempty(pool)
    fprintf("[setup] Starting Processes pool...\n");
    pool = parpool("Processes");
else
    fprintf("[setup] Reusing pool with %d workers.\n",pool.NumWorkers);
end

%% Evaluate
run_count = numel(campaign.runs);
total_jobs = run_count*numel(M_values);

summary_rows = cell(total_jobs,1);
job_index = 0;
overall_timer = tic;

fprintf("\nEvaluation starting\n");
fprintf("===================\n");
fprintf("Wavefields : %d\n",run_count);
fprintf("M values   : %d\n",numel(M_values));
fprintf("REQ jobs   : %d\n\n",total_jobs);

for irun = 1:run_count

    cr = campaign.runs(irun);

    design_id = string(cr.design_id);
    run_id = string(cr.run_id);

    match = string(planned.run_id)==design_id;

    assert(nnz(match)==1, ...
        "Could not map campaign design_id %s.",design_id);

    p = planned(match,:);

    sample_file = fullfile( ...
        string(cr.run_directory), ...
        "data","wavefield_sample.mat");

    assert(isfile(sample_file), ...
        "Missing sample: %s",sample_file);

    fprintf("\n[%03d/%03d] %s | P=%d | alpha=%.6f | r=%d\n", ...
        irun,run_count,run_id, ...
        p.in_plane_count, ...
        p.solid_angle_fraction, ...
        p.realization);

    tload = tic;
    data = reqml.io.load_wavefield_sample(sample_file);
    fprintf("          sample loaded in %.2f s\n",toc(tload));

    for M = M_values

        job_index = job_index+1;

        run_M_root = fullfile( ...
            runs_root,run_id,"M"+string(M));

        metrics_file = fullfile(run_M_root,"patch_metrics.mat");
        summary_file = fullfile(run_M_root,"run_summary.mat");

        if isfile(metrics_file) && isfile(summary_file)

            tmp = load(summary_file,"row");
            summary_rows{job_index} = tmp.row;

            fprintf("          M=%d | resumed\n",M);
            continue
        end

        if ~isfolder(run_M_root)
            mkdir(run_M_root);
        end

        fprintf("          M=%d | extracting + predicting... ",M);
        tjob = tic;

        [T,metadata] = evaluate_sample( ...
            data,bundle,M,cs_guess,step_pixels);

        row = summarize_run(T,p,M);

        save(metrics_file,"T","metadata","-v7.3");
        save(summary_file,"row");

        summary_rows{job_index} = row;

        dt = toc(tjob);
        elapsed = toc(overall_timer);

        jobs_left = total_jobs-job_index;

        if job_index>0
            eta = elapsed/job_index*jobs_left;
        else
            eta = NaN;
        end

        fprintf("patches=%d | qMAE=%.4f | SWS MAPE=%.2f%% | %.2f s | ETA %.1f min\n", ...
            row.patch_count, ...
            row.q_abs_error_mean, ...
            row.mape_percent, ...
            dt,eta/60);
    end
end

%% Combine summary
summary = struct2table(vertcat(summary_rows{:}));

summary = sortrows(summary, ...
    ["M","in_plane_count","solid_angle_fraction","realization"]);

summary_csv = fullfile(output_root,"run_summary.csv");
writetable(summary,summary_csv);

xlsx_file = fullfile(output_root,"angular_aperture_inplane_sweep_metrics.xlsx");

if isfile(xlsx_file)
    delete(xlsx_file);
end

writetable(summary,xlsx_file,"Sheet","RunSummary");

for M = M_values
    writetable( ...
        summary(summary.M==M,:), ...
        xlsx_file, ...
        "Sheet","M"+string(M));
end

%% Manifest
manifest = struct();
manifest.study_id = string(cfg.study_id);
manifest.model_file = model_file;
manifest.M_values = M_values;
manifest.cs_guess_m_s = cs_guess;
manifest.step_pixels = step_pixels;
manifest.run_count = run_count;
manifest.evaluation_count = height(summary);
manifest.q_oracle_definition = ...
    "q_target_from_center_truth = Ecum(k_true)";
manifest.q_theory_used = false;
manifest.statistical_unit = "simulation realization";
manifest.created_utc = string(datetime("now","TimeZone","UTC"));

write_json(fullfile(output_root,"manifest.json"),manifest);

fprintf("\nEvaluation complete.\n");
fprintf("====================\n");
fprintf("Wavefields evaluated : %d\n",run_count);
fprintf("REQ evaluations      : %d\n",height(summary));

for M = M_values

    d = summary(summary.M==M,:);

    fprintf("\nM=%d\n",M);
    fprintf("  mean q absolute error : %.5f\n", ...
        mean(d.q_abs_error_mean,"omitnan"));
    fprintf("  mean SWS MAPE         : %.3f %%\n", ...
        mean(d.mape_percent,"omitnan"));
end

result = struct();
result.summary = summary;
result.output_root = output_root;

end


function [T,metadata] = evaluate_sample( ...
    data,bundle,M,cs_guess,step_pixels)

geometry = reqml.homogeneous.computePatchGeometry( ...
    data.frequency_hz, ...
    data.dx_m, ...
    data.dz_m, ...
    M=M, ...
    CsGuessMPerS=cs_guess);

feature_config = reqml.config.default_feature_config( ...
    "M",M, ...
    "cs_guess",cs_guess);

dataset = reqml.datasets.extract_examples_from_sample( ...
    data, ...
    feature_config, ...
    DatasetId="angular_aperture_inplane_sweep_cs3_v1", ...
    SampleId="angular_aperture_inplane_sweep", ...
    StepX=step_pixels, ...
    StepZ=step_pixels, ...
    StoreReqCurves=false, ...
    UseWindowParfor=true, ...
    RequireTruth=true);

e = dataset.examples;

% Q0 predictor contract
e.campaign_frequency_hz = ...
    repmat(double(data.frequency_hz),height(e),1);

prediction = reqml.deployment.predictQ0Examples( ...
    e, ...
    bundle.model, ...
    string(bundle.predictor_names(:)));

q_pred = double(prediction.q_pred);
q_oracle = double(e.q_target_from_center_truth);

q_error = q_pred-q_oracle;
q_absolute_error = abs(q_error);

cs_pred = double(prediction.sws.cs_pred_m_s);
truth_cs = double(e.truth_cs_center_m_s);

sws_valid = ...
    logical(prediction.sws.sws_valid) & ...
    logical(e.target_valid) & ...
    isfinite(q_pred) & ...
    isfinite(q_oracle) & ...
    isfinite(cs_pred);

signed_error_percent = ...
    100*(cs_pred-truth_cs)./truth_cs;

absolute_error_percent = ...
    abs(signed_error_percent);

T = table( ...
    string(e.example_id), ...
    double(e.x_center_m), ...
    double(e.z_center_m), ...
    truth_cs, ...
    double(e.target_k_center_rad_m), ...
    q_oracle, ...
    q_pred, ...
    q_error, ...
    q_absolute_error, ...
    cs_pred, ...
    signed_error_percent, ...
    absolute_error_percent, ...
    sws_valid, ...
    VariableNames=[ ...
        "example_id", ...
        "x_center_m","z_center_m", ...
        "cs_true_m_s", ...
        "k_true_rad_m", ...
        "q_oracle", ...
        "q_pred", ...
        "q_error", ...
        "q_absolute_error", ...
        "cs_pred_m_s", ...
        "cs_error_percent", ...
        "cs_absolute_error_percent", ...
        "valid"]);

metadata = struct();
metadata.M = M;
metadata.cs_guess_m_s = cs_guess;
metadata.step_pixels = step_pixels;
metadata.patch_geometry = geometry;
metadata.patch_count = height(T);

end


function row = summarize_run(T,p,M)

valid = logical(T.valid);

assert(any(valid),"No valid patches.");

qoracle = T.q_oracle(valid);
qpred = T.q_pred(valid);
qerr = T.q_error(valid);
qabserr = T.q_absolute_error(valid);

cspred = T.cs_pred_m_s(valid);
ape = T.cs_absolute_error_percent(valid);
bias = T.cs_error_percent(valid);

row = struct();

row.M = M;

row.run_id = string(p.run_id);
row.condition_id = string(p.condition_id);

row.cs_true_m_s = double(p.cs_true_m_s);
row.frequency_hz = double(p.frequency_hz);

row.direction_count = double(p.direction_count);
row.in_plane_count = double(p.in_plane_count);
row.in_plane_fraction = double(p.in_plane_fraction);

row.aperture_index = double(p.aperture_index);
row.solid_angle_fraction = double(p.solid_angle_fraction);
row.solid_angle_sr = double(p.solid_angle_sr);

row.realization = double(p.realization);
row.seed = double(p.seed);

row.patch_count = nnz(valid);

row.q_oracle_mean = mean(qoracle,"omitnan");
row.q_oracle_median = median(qoracle,"omitnan");
row.q_oracle_q25 = prctile(qoracle,25);
row.q_oracle_q75 = prctile(qoracle,75);

row.q_pred_mean = mean(qpred,"omitnan");
row.q_pred_median = median(qpred,"omitnan");
row.q_pred_q25 = prctile(qpred,25);
row.q_pred_q75 = prctile(qpred,75);

row.q_error_mean = mean(qerr,"omitnan");
row.q_error_median = median(qerr,"omitnan");

row.q_abs_error_mean = mean(qabserr,"omitnan");
row.q_abs_error_median = median(qabserr,"omitnan");

row.cs_pred_mean_m_s = mean(cspred,"omitnan");
row.cs_pred_median_m_s = median(cspred,"omitnan");
row.cs_pred_q25_m_s = prctile(cspred,25);
row.cs_pred_q75_m_s = prctile(cspred,75);

row.mape_percent = mean(ape,"omitnan");
row.median_ape_percent = median(ape,"omitnan");
row.bias_percent = mean(bias,"omitnan");

end


function write_json(path,value)

fid = fopen(path,"w");
assert(fid>=0,"Cannot write %s",path);

cleanup = onCleanup(@() fclose(fid));
fprintf(fid,"%s\n",jsonencode(value,PrettyPrint=true));

end
