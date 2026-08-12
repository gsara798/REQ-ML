function result = predictSWS(sample_file, options)
%PREDICTSWS Estimate a shear-wave-speed map with the current REQ Q0 model.
%
% result = reqml.predictSWS(sample_file, "M", 2)
% result = reqml.predictSWS(sample_file, "Model", model_file, "M", 3)

arguments
    sample_file {mustBeTextScalar}
    options.Model {mustBeTextScalar} = ""
    options.M (1,1) double {mustBeMember(options.M, [2 3])} = 2
    options.StepPixels (1,1) double {mustBeInteger,mustBeNonnegative} = 0
    options.UseParallel (1,1) logical = false
end

cs_guess_m_s = 3;
[model_file, model_resolution] = ...
    reqml.models.resolveCurrentQ0Model(Model=options.Model);
bundle = load(model_file, "model", "model_metadata", "predictor_names");
required = ["model", "model_metadata", "predictor_names"];
missing = required(~isfield(bundle, cellstr(required)));
if ~isempty(missing)
    error("reqml:InvalidQ0ModelBundle", ...
        "Q0 model bundle is missing: %s", strjoin(missing, ", "));
end

data = reqml.io.load_wavefield_sample(sample_file);
geometry = reqml.homogeneous.computePatchGeometry( ...
    data.frequency_hz, data.dx_m, data.dz_m, M=options.M, ...
    CsGuessMPerS=cs_guess_m_s);
step = options.StepPixels;
if step == 0
    step = max(geometry.stride_x_px, geometry.stride_z_px);
end

feature_config = reqml.config.default_feature_config( ...
    "M", options.M, "cs_guess", cs_guess_m_s);
dataset = reqml.datasets.extract_examples_from_sample( ...
    data, feature_config, DatasetId="reqml_public_prediction", ...
    SampleId="prediction", StepX=step, StepZ=step, ...
    StoreReqCurves=false, UseWindowParfor=options.UseParallel);
examples = dataset.examples;
examples.campaign_frequency_hz = ...
    repmat(double(data.frequency_hz), height(examples), 1);
prediction = reqml.deployment.predictQ0Examples( ...
    examples, bundle.model, string(bundle.predictor_names(:)));

[cs_map, q_map, valid_mask, x_mm, z_mm] = ...
    assemble_maps(examples, prediction);
metadata = struct();
metadata.model_identifier = resolve_model_identifier(bundle.model_metadata);
metadata.model_file = model_file;
metadata.model_resolution = model_resolution.source;
metadata.M = options.M;
metadata.cs_guess_m_s = cs_guess_m_s;
metadata.frequency_hz = double(data.frequency_hz);
metadata.step_pixels = step;
metadata.patch_width_pixels = geometry.patch_width_px;
metadata.sample_file = string(sample_file);
metadata.sample_schema_version = data.sample_schema_version;
metadata.sample_provenance = data.provenance;
metadata.valid_patch_count = nnz(valid_mask);
metadata.patch_count = numel(valid_mask);

result = struct("cs_map", cs_map, "q_map", q_map, ...
    "valid_mask", valid_mask, "x_mm", x_mm, "z_mm", z_mm, ...
    "metadata", metadata, "patch_predictions", prediction.sws, ...
    "patch_examples", examples);
end

function [cs_map, q_map, valid_mask, x_mm, z_mm] = assemble_maps(e, p)
nz = max(double(e.map_iz)); nx = max(double(e.map_ix));
linear = sub2ind([nz nx], double(e.map_iz), double(e.map_ix));
cs_map = nan(nz, nx); q_map = nan(nz, nx); valid_mask = false(nz, nx);
cs_map(linear) = p.sws.cs_pred_m_s;
q_map(linear) = p.q_pred;
valid_mask(linear) = p.sws.sws_valid;
x_mm = accumarray(double(e.map_ix), 1e3*double(e.x_center_m), ...
    [nx 1], @mean, NaN).';
z_mm = accumarray(double(e.map_iz), 1e3*double(e.z_center_m), ...
    [nz 1], @mean, NaN);
end

function identifier = resolve_model_identifier(metadata)
identifier = "current_q0_model";
if isstruct(metadata) && isfield(metadata, "model_id")
    identifier = string(metadata.model_id);
end
end
