function result = evaluate_campaign()

repo_root = string(fileparts(fileparts(fileparts(mfilename("fullpath")))));

config_file = fullfile( ...
    repo_root, ...
    "configs","validation","eikonal_validation_v1.json");

cfg = jsondecode(fileread(config_file));

model_file = fullfile( ...
    repo_root, ...
    "outputs","homogeneous_cartesian_q0_v2", ...
    "training","final_frozen_q0_v2","model_bundle.mat");

assert(isfile(model_file), "Model bundle not found: %s", model_file);

output_root = fullfile( ...
    repo_root, ...
    "outputs","validation","eikonal_validation_v1","evaluation");

runs_output = fullfile(output_root,"runs");

if ~isfolder(runs_output)
    mkdir(runs_output);
end

fprintf("[%s] Loading frozen Q0 model...\n", string(datetime("now")));
t_model = tic;

bundle = load(model_file, ...
    "model","model_metadata","predictor_names");

fprintf("[%s] Model loaded in %.1f s\n", ...
    string(datetime("now")), toc(t_model));

p = gcp("nocreate");
if isempty(p)
    fprintf("[%s] Starting parallel pool...\n", string(datetime("now")));
    p = parpool("Processes");
end
fprintf("[%s] Parallel pool ready: %d workers\n", ...
    string(datetime("now")), p.NumWorkers);

campaign_root = fullfile( ...
    repo_root, ...
    "outputs","validation","eikonal_validation_v1","simulations");

campaigns = [
    struct("geometry","homogeneous", ...
           "directory","eikonal_validation_v1_homogeneous")
    struct("geometry","bilayer", ...
           "directory","eikonal_validation_v1_bilayer")
    struct("geometry","circular_inclusion", ...
           "directory","eikonal_validation_v1_circular_inclusion")
];

sample_files = strings(0,1);
geometry_labels = strings(0,1);

for ic = 1:numel(campaigns)

    base = fullfile( ...
        campaign_root, ...
        campaigns(ic).geometry, ...
        campaigns(ic).directory);

    files = dir(fullfile(base,"run_*","data","wavefield_sample.mat"));

    for j = 1:numel(files)
        sample_files(end+1,1) = string(fullfile(files(j).folder,files(j).name));
        geometry_labels(end+1,1) = string(campaigns(ic).geometry);
    end
end

assert(numel(sample_files)==84, ...
    "Expected 84 final samples, found %d.", numel(sample_files));

summary_rows = cell(numel(sample_files),1);

fprintf("\nEvaluating %d runs with StepPixels=2\n\n", numel(sample_files));

for irun = 1:numel(sample_files)

    sample_file = sample_files(irun);
    geometry = geometry_labels(irun);

    t_run = tic;

    data = reqml.io.load_wavefield_sample(sample_file);

    design_id = resolve_design_id(data, sample_file);

    run_output = fullfile(runs_output, design_id);
    if ~isfolder(run_output)
        mkdir(run_output);
    end

    metrics_file = fullfile(run_output,"patch_metrics.mat");
    figure_file = fullfile(run_output,"maps.png");

    % Resume-safe: use existing patch metrics when present.
    if isfile(metrics_file)
        saved = load(metrics_file,"T","metadata");
        T = saved.T;
        metadata = saved.metadata;
        status = "resumed";
    else
        [T, metadata] = evaluate_sample( ...
            data, sample_file, bundle, cfg.req.M, cfg.req.cs_guess_m_s);

        save(metrics_file,"T","metadata","-v7.3");
        status = "computed";
    end

    if ~isfile(figure_file)
        plot_run_maps( ...
            data, T, figure_file, ...
            sprintf("%s | %s", design_id, geometry));
    end

    valid = T.sws_valid;

    mape = mean( ...
        T.cs_absolute_error_percent(valid), ...
        "omitnan");

    bias = mean( ...
        T.cs_error_percent(valid), ...
        "omitnan");

    invalid_fraction = 1 - mean(valid);

    summary_rows{irun} = struct( ...
        "design_id",design_id, ...
        "geometry",geometry, ...
        "frequency_hz",double(data.frequency_hz), ...
        "patch_count",height(T), ...
        "valid_patch_count",nnz(valid), ...
        "invalid_fraction",invalid_fraction, ...
        "mape_percent",mape, ...
        "bias_percent",bias, ...
        "runtime_s",toc(t_run), ...
        "status",status, ...
        "sample_file",sample_file);

    fprintf( ...
        "[%02d/%02d] %-55s | %6.1f s | MAPE %6.3f %% | bias %+6.3f %% | %s\n", ...
        irun,numel(sample_files),design_id,toc(t_run),mape,bias,status);

    % Persist summary after every run, so interruption loses almost nothing.
    partial = struct2table(vertcat(summary_rows{1:irun}));
    writetable(partial,fullfile(output_root,"run_summary.csv"));
end

summary = struct2table(vertcat(summary_rows{:}));

manifest = struct();
manifest.schema_name = "reqml_eikonal_validation_evaluation";
manifest.schema_version = "1.0";
manifest.source_config = config_file;
manifest.model_file = model_file;
manifest.req_M = cfg.req.M;
manifest.req_cs_guess_m_s = cfg.req.cs_guess_m_s;
manifest.step_pixels = 2;
manifest.run_count = height(summary);
manifest.created_utc = string(datetime("now","TimeZone","UTC"));

write_json(fullfile(output_root,"manifest.json"),manifest);

fprintf("\nEvaluation complete.\n");
fprintf("Runs: %d\n",height(summary));
fprintf("Overall run-level mean MAPE: %.3f %%\n", ...
    mean(summary.mape_percent,"omitnan"));

result = struct( ...
    "summary",summary, ...
    "output_root",output_root);

end


function [T, metadata] = evaluate_sample( ...
    data, sample_file, bundle, M, cs_guess)

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
    DatasetId="eikonal_validation_v1", ...
    SampleId="validation", ...
    StepX=2, ...
    StepZ=2, ...
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

cs_pred = double(prediction.sws.cs_pred_m_s);
valid = logical(prediction.sws.sws_valid);

truth_cs = double(e.truth_cs_center_m_s);

signed_error_percent = ...
    100*(cs_pred-truth_cs)./truth_cs;

absolute_error_percent = ...
    abs(signed_error_percent);

purity = double(e.truth_material_purity);

purity_bin = strings(height(e),1);
purity_bin(:) = "<0.5";
purity_bin(purity>=0.5) = "0.5-0.7";
purity_bin(purity>=0.7) = "0.7-0.9";
purity_bin(purity>=0.9) = "0.9-0.98";
purity_bin(purity>=0.98) = "0.98-1";
purity_bin(abs(purity-1)<=1e-12) = "1";

T = table( ...
    string(e.example_id), ...
    double(e.map_iz), ...
    double(e.map_ix), ...
    double(e.cx), ...
    double(e.cz), ...
    double(e.x_center_m), ...
    double(e.z_center_m), ...
    truth_cs, ...
    cs_pred, ...
    signed_error_percent, ...
    absolute_error_percent, ...
    double(e.truth_material_id_center), ...
    purity, ...
    purity_bin, ...
    valid, ...
    VariableNames=[ ...
        "example_id","map_iz","map_ix","cx","cz", ...
        "x_center_m","z_center_m", ...
        "cs_true_m_s","cs_pred_m_s", ...
        "cs_error_percent","cs_absolute_error_percent", ...
        "material_id_center","truth_material_purity", ...
        "purity_bin","sws_valid"]);

metadata = struct();
metadata.sample_file = string(sample_file);
metadata.frequency_hz = double(data.frequency_hz);
metadata.M = M;
metadata.cs_guess_m_s = cs_guess;
metadata.step_pixels = 2;
metadata.patch_width_pixels = geometry.patch_width_px;

end


function design_id = resolve_design_id(data, sample_file)

design_id = "";

if isstruct(data.provenance) && ...
        isfield(data.provenance,"design_id")
    design_id = string(data.provenance.design_id);
end

if strlength(design_id)==0
    run_dir = fileparts(fileparts(sample_file));
    [~,run_name] = fileparts(run_dir);
    design_id = string(run_name);
end

end


function write_json(path,value)

fid = fopen(path,"w");
assert(fid>=0,"Cannot write %s",path);

cleanup = onCleanup(@() fclose(fid));
fprintf(fid,"%s\n",jsonencode(value,PrettyPrint=true));

end
