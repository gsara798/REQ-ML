function result = evaluate_campaign()

repo_root = string(fileparts(fileparts(fileparts(mfilename("fullpath")))));

config_file = fullfile( ...
    repo_root,"configs","validation", ...
    "angular_aperture_validation_v1.json");

fprintf("\n[setup] Loading config...\n");
cfg = jsondecode(fileread(config_file));
fprintf("[setup] Config loaded: %s\n",cfg.study_id);

study_root = replace( ...
    string(cfg.paths.output_root), ...
    "${REPOSITORY_ROOT}",repo_root);

simulation_root = fullfile( ...
    study_root,"simulations","angular_aperture_validation_v1");

campaign_summary_file = fullfile( ...
    simulation_root,"campaign_summary.json");

assert(isfile(campaign_summary_file), ...
    "Missing campaign summary: %s",campaign_summary_file);

campaign = jsondecode(fileread(campaign_summary_file));

assert(campaign.completed_count==campaign.run_count);
assert(campaign.failed_count==0);

%% Planned design lookup

planned = readtable(fullfile( ...
    study_root,"design","planned_runs.csv"));

%% Frozen Q0

model_file = fullfile( ...
    repo_root,"outputs","homogeneous_cartesian_q0_v2", ...
    "training","final_frozen_q0_v2","model_bundle.mat");

assert(isfile(model_file), ...
    "Frozen model not found: %s",model_file);

fprintf("[setup] Loading frozen Q0 model...\n");
model_timer = tic;

B = load(model_file,"model","model_metadata","predictor_names");

assert(isfield(B,"model"), ...
    "Model file is missing variable 'model'.");
assert(isfield(B,"predictor_names"), ...
    "Model file is missing variable 'predictor_names'.");

bundle = struct();
bundle.model = B.model;
bundle.predictor_names = string(B.predictor_names(:));

if isfield(B,"model_metadata")
    bundle.model_metadata = B.model_metadata;
end

fprintf("[setup] Model loaded in %.2f s\n",toc(model_timer));
fprintf("[setup] Predictors: %d\n",numel(bundle.predictor_names));

if isfield(bundle,"model_metadata")
    md = bundle.model_metadata;

    if isfield(md,"model_id")
        fprintf("[setup] Model ID: %s\n",string(md.model_id));
    elseif isfield(md,"training_id")
        fprintf("[setup] Training ID: %s\n",string(md.training_id));
    end
end

M = double(cfg.req.M);
cs_guess = double(cfg.req.cs_guess_m_s);
step_pixels = double(cfg.req.step_pixels);

%% Output

output_root = fullfile(study_root,"evaluation");
runs_output_root = fullfile(output_root,"runs");

if ~isfolder(runs_output_root)
    mkdir(runs_output_root);
end

run_count = numel(campaign.runs);
summary_rows = cell(run_count,1);

%% One parallel pool reused by all runs

fprintf("[setup] Checking parallel pool...\n");

pool = gcp("nocreate");

if isempty(pool)
    pool_timer = tic;
    pool = parpool("Processes");
    fprintf("[setup] Parallel pool started in %.2f s with %d workers\n", ...
        toc(pool_timer),pool.NumWorkers);
else
    fprintf("[setup] Reusing parallel pool with %d workers\n", ...
        pool.NumWorkers);
end

fprintf("\nAngular aperture Q0 evaluation\n");
fprintf("==============================\n");
fprintf("Runs      : %d\n",run_count);
fprintf("M         : %g\n",M);
fprintf("cs_guess  : %.3f m/s\n",cs_guess);
fprintf("Step      : %d pixels\n\n",step_pixels);

evaluation_timer = tic;

for irun = 1:run_count

    run_timer = tic;

    cr = campaign.runs(irun);

    design_id = string(cr.design_id);
    run_id = string(cr.run_id);

    match = planned.run_id == design_id;
    assert(nnz(match)==1, ...
        "Could not uniquely map design_id %s.",design_id);

    p = planned(match,:);

    run_out = fullfile(runs_output_root,run_id);

    if ~isfolder(run_out)
        mkdir(run_out);
    end

    patch_file = fullfile(run_out,"patch_metrics.mat");

    fprintf("[%03d/%03d] %s | cs=%.1f | alpha=%.6f | r=%d\n", ...
        irun,run_count,run_id, ...
        p.cs_true_m_s, ...
        p.solid_angle_fraction, ...
        p.realization);

    if isfile(patch_file)

        S = load(patch_file,"T","metadata");
        T = S.T;
        metadata = S.metadata;

        fprintf("           resumed (%d patches)\n",height(T));

    else

        fprintf("           loading sample...\n");

        sample_file = fullfile( ...
            string(cr.run_directory), ...
            "data","wavefield_sample.mat");

        assert(isfile(sample_file), ...
            "Missing sample: %s",sample_file);

        sample_timer = tic;
        data = reqml.io.load_wavefield_sample(sample_file);
        fprintf("           sample loaded in %.2f s\n",toc(sample_timer));

        fprintf("           extracting patches + Q0 prediction...\n");
        inference_timer = tic;

        [T,metadata] = evaluate_sample( ...
            data,sample_file,bundle,M,cs_guess,step_pixels);

        fprintf("           evaluated %d patches in %.2f s\n", ...
            height(T),toc(inference_timer));

        save(patch_file,"T","metadata","-v7.3");
        fprintf("           patch metrics saved\n");
    end

    summary_rows{irun} = summarize_run( ...
        T,p,run_id,design_id);

    partial = struct2table(vertcat(summary_rows{1:irun}));
    writetable(partial,fullfile(output_root,"run_summary.csv"));

    elapsed_run = toc(run_timer);
    elapsed_total = toc(evaluation_timer);
    mean_per_run = elapsed_total / irun;
    eta = mean_per_run * (run_count-irun);

    fprintf("           done in %.2f s | elapsed %.1f min | ETA %.1f min\n\n", ...
        elapsed_run,elapsed_total/60,eta/60);

end

summary = struct2table(vertcat(summary_rows{:}));

%% Manifest

manifest = struct();
manifest.schema_name = ...
    "reqml_angular_aperture_validation_evaluation";
manifest.schema_version = "1.0";

manifest.source_config = config_file;
manifest.model_file = model_file;

manifest.req_M = M;
manifest.req_cs_guess_m_s = cs_guess;
manifest.step_pixels = step_pixels;

manifest.q_oracle_definition = ...
    "examples.q_target_from_center_truth";
manifest.q_theory_used = false;

manifest.run_count = height(summary);
manifest.created_utc = ...
    string(datetime("now","TimeZone","UTC"));

write_json(fullfile(output_root,"manifest.json"),manifest);

fprintf("\nEvaluation complete.\n");
fprintf("Runs: %d\n",height(summary));

fprintf("Mean run-level q absolute error: %.5f\n", ...
    mean(summary.q_abs_error_mean,"omitnan"));

fprintf("Mean run-level SWS MAPE: %.3f %%\n", ...
    mean(summary.mape_percent,"omitnan"));

result = struct();
result.summary = summary;
result.output_root = output_root;

end


function [T,metadata] = evaluate_sample( ...
    data,sample_file,bundle,M,cs_guess,step_pixels)

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
    DatasetId="angular_aperture_validation_v1", ...
    SampleId="angular_aperture", ...
    StepX=step_pixels, ...
    StepZ=step_pixels, ...
    StoreReqCurves=false, ...
    UseWindowParfor=true, ...
    RequireTruth=true);

e = dataset.examples;

e.campaign_frequency_hz = ...
    repmat(double(data.frequency_hz),height(e),1);

prediction = reqml.deployment.predictQ0Examples( ...
    e, ...
    bundle.model, ...
    string(bundle.predictor_names(:)));

q_pred = double(prediction.q_pred);
q_oracle = double(e.q_target_from_center_truth);

q_error = q_pred - q_oracle;
q_absolute_error = abs(q_error);

cs_pred = double(prediction.sws.cs_pred_m_s);

sws_valid = ...
    logical(prediction.sws.sws_valid) & ...
    logical(e.target_valid) & ...
    isfinite(q_pred) & ...
    isfinite(q_oracle);

truth_cs = double(e.truth_cs_center_m_s);

signed_error_percent = ...
    100*(cs_pred-truth_cs)./truth_cs;

absolute_error_percent = ...
    abs(signed_error_percent);

T = table( ...
    string(e.example_id), ...
    double(e.map_iz), ...
    double(e.map_ix), ...
    double(e.cx), ...
    double(e.cz), ...
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
        "map_iz","map_ix","cx","cz", ...
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
metadata.sample_file = string(sample_file);
metadata.frequency_hz = double(data.frequency_hz);

metadata.M = M;
metadata.cs_guess_m_s = cs_guess;
metadata.step_pixels = step_pixels;

metadata.patch_width_pixels = geometry.patch_width_px;
metadata.patch_height_pixels = geometry.patch_height_px;

metadata.q_oracle_definition = ...
    "q_target_from_center_truth";

end


function row = summarize_run(T,p,run_id,design_id)

valid = logical(T.valid);

Tv = T(valid,:);

assert(~isempty(Tv),"No valid patches in %s.",run_id);

q_oracle = double(Tv.q_oracle);
q_pred = double(Tv.q_pred);
q_error = double(Tv.q_error);
q_abs_error = double(Tv.q_absolute_error);

cs_pred = double(Tv.cs_pred_m_s);
cs_err = double(Tv.cs_error_percent);
cs_abs_err = double(Tv.cs_absolute_error_percent);

row = struct();

row.run_id = string(run_id);
row.design_id = string(design_id);
row.condition_id = string(p.condition_id);

row.cs_true_m_s = double(p.cs_true_m_s);
row.frequency_hz = double(p.frequency_hz);

row.solid_angle_fraction = ...
    double(p.solid_angle_fraction);
row.solid_angle_sr = ...
    double(p.solid_angle_sr);

row.direction_count = ...
    double(p.direction_count);
row.in_plane_count = ...
    double(p.in_plane_count);

row.realization = double(p.realization);
row.seed = double(p.seed);

row.patch_count = height(Tv);

row.q_oracle_mean = mean(q_oracle,"omitnan");
row.q_oracle_median = median(q_oracle,"omitnan");
row.q_oracle_q25 = prctile(q_oracle,25);
row.q_oracle_q75 = prctile(q_oracle,75);

row.q_pred_mean = mean(q_pred,"omitnan");
row.q_pred_median = median(q_pred,"omitnan");
row.q_pred_q25 = prctile(q_pred,25);
row.q_pred_q75 = prctile(q_pred,75);

row.q_error_mean = mean(q_error,"omitnan");
row.q_error_median = median(q_error,"omitnan");
row.q_abs_error_mean = mean(q_abs_error,"omitnan");
row.q_abs_error_median = median(q_abs_error,"omitnan");

row.cs_pred_mean_m_s = mean(cs_pred,"omitnan");
row.cs_pred_median_m_s = median(cs_pred,"omitnan");
row.cs_pred_q25_m_s = prctile(cs_pred,25);
row.cs_pred_q75_m_s = prctile(cs_pred,75);

row.mape_percent = mean(cs_abs_err,"omitnan");
row.median_ape_percent = median(cs_abs_err,"omitnan");
row.bias_percent = mean(cs_err,"omitnan");

end


function write_json(path,value)

fid = fopen(path,"w");
assert(fid>=0,"Cannot write %s",path);

cleanup = onCleanup(@() fclose(fid));
fprintf(fid,"%s\n",jsonencode(value,PrettyPrint=true));

end
