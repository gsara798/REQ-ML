function dataset = extract_examples_from_sample( ...
    data, feat_cfg, options)
%EXTRACT_EXAMPLES_FROM_SAMPLE Build traceable REQ examples from one sample.
%
% This is the first active dataset-layer API. It converts one loaded
% wavefield_sample into a feature/example table while reusing the existing
% REQ estimator implementation.

arguments
    data (1,1) struct
    feat_cfg (1,1) struct

    options.DatasetId (1,1) string = "dataset"
    options.SampleId (1,1) string = "sample"
    options.StepX (1,1) double = NaN
    options.StepZ (1,1) double = NaN
    options.StoreReqCurves (1,1) logical = false
    options.UseWindowParfor (1,1) logical = false
    options.Estimator (1,1) function_handle = ...
        @reqml.estimators.req_estimator_map
end

validate_loaded_sample(data);
validate_feature_config(feat_cfg);

cfg = build_physical_config(data);

estimator_args = {
    "QuantileMode", "local_req"
    "ReturnFeatures", false
    "ReturnFeatureTable", true
    "StoreReqCurves", options.StoreReqCurves
    "ReuseReqSpectrumForFeatures", true
    "UseWindowParfor", options.UseWindowParfor
    };

if isfinite(options.StepX)
    estimator_args(end + 1, :) = {"StepX", options.StepX};
end

if isfinite(options.StepZ)
    estimator_args(end + 1, :) = {"StepZ", options.StepZ};
end

estimator_args = reshape(estimator_args.', 1, []);

estimator_out = options.Estimator( ...
    data.wavefield_zx, ...
    cfg, ...
    feat_cfg, ...
    estimator_args{:});

if ~isfield(estimator_out, "feature_table") || ...
        ~istable(estimator_out.feature_table)
    error("reqml:MissingEstimatorFeatureTable", ...
        "Estimator output must contain feature_table.");
end

examples = estimator_out.feature_table;

required_columns = ["cx", "cz", "q_local_req"];

for name = required_columns.'
    if ~ismember(name, string(examples.Properties.VariableNames))
        error("reqml:InvalidEstimatorFeatureTable", ...
            "Estimator feature_table is missing '%s'.", name);
    end
end

examples = attach_identifiers( ...
    examples, ...
    options.DatasetId, ...
    options.SampleId);

examples = attach_truth( ...
    examples, ...
    data, ...
    estimator_out);

examples = attach_center_truth_target( ...
    examples, ...
    data);

examples = movevars( ...
    examples, ...
    ["dataset_id", "sample_id", "example_id"], ...
    "Before", 1);

dataset = struct();
dataset.schema_name = "reqml_dataset_examples";
dataset.schema_version = "1.0";
dataset.dataset_id = options.DatasetId;
dataset.sample_id = options.SampleId;
dataset.examples = examples;
dataset.estimator = estimator_out;
dataset.sample_summary = make_summary( ...
    examples, ...
    data, ...
    options.DatasetId, ...
    options.SampleId);

end

function validate_loaded_sample(data)

required = [
    "wavefield_zx"
    "dx_m"
    "dz_m"
    "frequency_hz"
    "truth"
    ];

for name = required.'
    if ~isfield(data, name)
        error("reqml:InvalidDatasetSample", ...
            "Loaded sample is missing '%s'.", name);
    end
end

truth_required = [
    "cs_m_s_zx"
    "material_id_zx"
    "valid_mask_zx"
    ];

for name = truth_required.'
    if ~isfield(data.truth, name)
        error("reqml:InvalidDatasetTruth", ...
            "Loaded sample truth is missing '%s'.", name);
    end
end

expected_size = size(data.wavefield_zx);

for name = truth_required.'
    if ~isequal(size(data.truth.(name)), expected_size)
        error("reqml:InvalidDatasetTruth", ...
            "Truth map '%s' has an inconsistent size.", name);
    end
end

end

function validate_feature_config(feat_cfg)

required = ["win_size", "M"];

for name = required.'
    if ~isfield(feat_cfg, name)
        error("reqml:InvalidDatasetFeatureConfig", ...
            "Feature configuration is missing '%s'.", name);
    end
end

end

function cfg = build_physical_config(data)

cfg = struct();
cfg.dx = double(data.dx_m);
cfg.dz = double(data.dz_m);
cfg.f0 = double(data.frequency_hz);

valid_truth = double(data.truth.cs_m_s_zx( ...
    logical(data.truth.valid_mask_zx)));

if isempty(valid_truth)
    error("reqml:EmptyDatasetTruth", ...
        "No valid truth pixels are available.");
end

cfg.cs_bg = median(valid_truth, "omitnan");
cfg.WaveModel = resolve_wave_model(data);

end

function wave_model = resolve_wave_model(data)

wave_model = "wavefield_sample";

if isfield(data, "generator") && ...
        isstruct(data.generator) && ...
        isfield(data.generator, "backend")
    wave_model = string(data.generator.backend);
end

end

function examples = attach_identifiers( ...
    examples, dataset_id, sample_id)

n = height(examples);

examples.dataset_id = repmat(dataset_id, n, 1);
examples.sample_id = repmat(sample_id, n, 1);

example_id = strings(n, 1);

for index = 1:n
    example_id(index) = sprintf( ...
        "%s__z%05d_x%05d", ...
        sample_id, ...
        round(examples.cz(index)), ...
        round(examples.cx(index)));
end

if numel(unique(example_id)) ~= n
    error("reqml:DuplicateDatasetExampleId", ...
        "Example identifiers are not unique.");
end

examples.example_id = example_id;

end

function examples = attach_truth( ...
    examples, data, estimator_out)

cs_map = double(data.truth.cs_m_s_zx);
material_map = data.truth.material_id_zx;
valid_map = logical(data.truth.valid_mask_zx);

half_win = resolve_half_window(estimator_out);

n = height(examples);

truth_cs_center_m_s = nan(n, 1);
truth_cs_mean_m_s = nan(n, 1);
truth_cs_median_m_s = nan(n, 1);
truth_cs_std_m_s = nan(n, 1);
truth_cs_min_m_s = nan(n, 1);
truth_cs_max_m_s = nan(n, 1);
truth_material_id_center = nan(n, 1);
truth_material_id_dominant = nan(n, 1);
truth_material_purity = nan(n, 1);
truth_valid_fraction = nan(n, 1);

for index = 1:n
    cx = round(examples.cx(index));
    cz = round(examples.cz(index));

    x_idx = (cx - half_win):(cx + half_win);
    z_idx = (cz - half_win):(cz + half_win);

    if min(x_idx) < 1 || ...
            max(x_idx) > size(cs_map, 2) || ...
            min(z_idx) < 1 || ...
            max(z_idx) > size(cs_map, 1)
        error("reqml:DatasetWindowOutOfBounds", ...
            "Example '%d' exceeds truth-map bounds.", index);
    end

    cs_patch = cs_map(z_idx, x_idx);
    material_patch = material_map(z_idx, x_idx);
    valid_patch = valid_map(z_idx, x_idx);

    valid_values = cs_patch(valid_patch);

    truth_cs_center_m_s(index) = cs_map(cz, cx);
    truth_material_id_center(index) = double(material_map(cz, cx));
    truth_valid_fraction(index) = mean(valid_patch, "all");

    if ~isempty(valid_values)
        truth_cs_mean_m_s(index) = mean(valid_values, "omitnan");
        truth_cs_median_m_s(index) = median(valid_values, "omitnan");
        truth_cs_std_m_s(index) = std(valid_values, 0, "omitnan");
        truth_cs_min_m_s(index) = min(valid_values);
        truth_cs_max_m_s(index) = max(valid_values);
    end

    valid_materials = double(material_patch(valid_patch));

    if ~isempty(valid_materials)
        dominant_id = mode(valid_materials);
        truth_material_id_dominant(index) = dominant_id;
        truth_material_purity(index) = mean(valid_materials == dominant_id);
    end
end

examples.truth_cs_center_m_s = truth_cs_center_m_s;
examples.truth_cs_mean_m_s = truth_cs_mean_m_s;
examples.truth_cs_median_m_s = truth_cs_median_m_s;
examples.truth_cs_std_m_s = truth_cs_std_m_s;
examples.truth_cs_min_m_s = truth_cs_min_m_s;
examples.truth_cs_max_m_s = truth_cs_max_m_s;
examples.truth_material_id_center = truth_material_id_center;
examples.truth_material_id_dominant = truth_material_id_dominant;
examples.truth_material_purity = truth_material_purity;
examples.truth_valid_fraction = truth_valid_fraction;

end

function examples = attach_center_truth_target( ...
    examples, data)

required_columns = [
    "truth_cs_center_m_s"
    "req_mapping"
    ];

for name = required_columns.'
    if ~ismember( ...
            name, ...
            string(examples.Properties.VariableNames))
        error("reqml:MissingCenterTruthTargetInput", ...
            "Example table is missing '%s'.", ...
            name);
    end
end

n = height(examples);

target_cs_center_m_s = ...
    double(examples.truth_cs_center_m_s);

target_k_center_rad_m = nan(n, 1);
q_target_from_center_truth = nan(n, 1);
target_valid = false(n, 1);

for index = 1:n
    cs_target = target_cs_center_m_s(index);

    if ~isfinite(cs_target) || cs_target <= 0
        continue
    end

    k_target = ...
        2*pi*double(data.frequency_hz) / cs_target;

    mapping = examples.req_mapping{index};

    q_target = ...
        reqml.quantile. ...
        evaluate_quantile_at_wavenumber( ...
            mapping, ...
            k_target);

    target_k_center_rad_m(index) = k_target;
    q_target_from_center_truth(index) = q_target;

    target_valid(index) = ...
        isfinite(k_target) && ...
        isfinite(q_target);
end

examples.target_cs_center_m_s = ...
    target_cs_center_m_s;

examples.target_k_center_rad_m = ...
    target_k_center_rad_m;

examples.q_target_from_center_truth = ...
    q_target_from_center_truth;

examples.target_valid = target_valid;

examples.target_definition = ...
    repmat("center_pixel_truth", n, 1);

end


function half_win = resolve_half_window(estimator_out)

if isfield(estimator_out, "half_win")
    half_win = double(estimator_out.half_win);
elseif isfield(estimator_out, "win_size")
    half_win = floor(double(estimator_out.win_size) / 2);
else
    error("reqml:MissingEstimatorWindowMetadata", ...
        "Estimator output must contain half_win or win_size.");
end

if ~isscalar(half_win) || ...
        ~isfinite(half_win) || ...
        half_win < 0 || ...
        half_win ~= fix(half_win)
    error("reqml:InvalidEstimatorWindowMetadata", ...
        "Estimator half-window must be a nonnegative integer.");
end

end

function summary = make_summary( ...
    examples, data, dataset_id, sample_id)

summary = struct();
summary.dataset_id = dataset_id;
summary.sample_id = sample_id;
summary.example_count = height(examples);
summary.valid_example_count = ...
    sum(examples.target_valid);
summary.frequency_hz = double(data.frequency_hz);
summary.dx_m = double(data.dx_m);
summary.dz_m = double(data.dz_m);
summary.wavefield_size_zx = size(data.wavefield_zx);
summary.minimum_material_purity = min( ...
    examples.truth_material_purity, [], "omitnan");
summary.median_material_purity = median( ...
    examples.truth_material_purity, "omitnan");

end
