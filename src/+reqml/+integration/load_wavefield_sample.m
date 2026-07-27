function data = load_wavefield_sample(sample_file)
%LOAD_WAVEFIELD_SAMPLE Load and validate wavefield_sample v1.

arguments
    sample_file {mustBeTextScalar}
end

sample_file = string(sample_file);

if ~isfile(sample_file)
    error("reqml:WavefieldSampleNotFound", ...
        "Wavefield sample was not found: %s", sample_file);
end

loaded = load(sample_file, "wavefield_sample");

if ~isfield(loaded, "wavefield_sample")
    error("reqml:InvalidWavefieldSample", ...
        "The MAT file must contain 'wavefield_sample'.");
end

sample = loaded.wavefield_sample;

required_top = ["schema_name","schema_version","generator", ...
    "coordinates","wavefield","truth","validation","provenance"];

for name = required_top
    require_field(sample, name, "sample", ...
        "reqml:InvalidWavefieldSample");
end

if string(sample.schema_name) ~= "wavefield_sample"
    error("reqml:InvalidWavefieldSample", ...
        "Expected schema_name wavefield_sample.");
end

if string(sample.schema_version) ~= "1.0"
    error("reqml:UnsupportedWavefieldSampleSchema", ...
        "Unsupported wavefield_sample schema: %s.", ...
        string(sample.schema_version));
end

required_coordinates = ["x_m","z_m","dx_m","dz_m","array_order"];
for name = required_coordinates
    require_field(sample.coordinates, name, ...
        "sample.coordinates", ...
        "reqml:InvalidWavefieldCoordinates");
end

if string(sample.coordinates.array_order) ~= "zx"
    error("reqml:InvalidWavefieldOrientation", ...
        "Expected coordinates.array_order zx.");
end

required_wavefield = ["data_zx","frequency_hz", ...
    "component","quantity","units"];
for name = required_wavefield
    require_field(sample.wavefield, name, ...
        "sample.wavefield", ...
        "reqml:InvalidWavefieldData");
end

wavefield_zx = sample.wavefield.data_zx;

if ~isnumeric(wavefield_zx) || ~ismatrix(wavefield_zx) || isempty(wavefield_zx)
    error("reqml:InvalidWavefieldData", ...
        "wavefield.data_zx must be a nonempty numeric matrix.");
end

if ~all(isfinite(wavefield_zx), "all")
    error("reqml:InvalidWavefieldData", ...
        "wavefield.data_zx contains non-finite values.");
end

x_m = double(sample.coordinates.x_m(:));
z_m = double(sample.coordinates.z_m(:));
expected_size = [numel(z_m), numel(x_m)];

if ~isequal(size(wavefield_zx), expected_size)
    error("reqml:InvalidWavefieldSize", ...
        "Wavefield size is inconsistent with x/z axes.");
end

dx_m = validate_spacing(sample.coordinates.dx_m, x_m, "x");
dz_m = validate_spacing(sample.coordinates.dz_m, z_m, "z");

frequency_hz = double(sample.wavefield.frequency_hz);
if ~isscalar(frequency_hz) || ~isfinite(frequency_hz) || frequency_hz <= 0
    error("reqml:InvalidWavefieldFrequency", ...
        "wavefield.frequency_hz must be positive.");
end

required_truth = ["cs_map_zx","k_map_zx", ...
    "material_id_zx","valid_mask_zx"];
for name = required_truth
    require_field(sample.truth, name, ...
        "sample.truth", ...
        "reqml:InvalidWavefieldTruth");
end

cs_truth_zx = double(sample.truth.cs_map_zx);
k_truth_zx = double(sample.truth.k_map_zx);
material_id_zx = sample.truth.material_id_zx;
valid_mask_zx = logical(sample.truth.valid_mask_zx);

truth_values = {cs_truth_zx, k_truth_zx, material_id_zx, valid_mask_zx};
truth_names = ["cs_map_zx","k_map_zx","material_id_zx","valid_mask_zx"];

for index = 1:numel(truth_values)
    if ~isequal(size(truth_values{index}), expected_size)
        error("reqml:InvalidWavefieldTruth", ...
            "truth.%s has an inconsistent size.", truth_names(index));
    end
end

if any(~isfinite(cs_truth_zx), "all") || any(cs_truth_zx <= 0, "all")
    error("reqml:InvalidWavefieldTruth", ...
        "truth.cs_map_zx must be finite and positive.");
end

expected_k_zx = 2*pi*frequency_hz ./ cs_truth_zx;
relative_k_error = max(abs(k_truth_zx(:)-expected_k_zx(:)) ./ ...
    max(abs(expected_k_zx(:)), eps));

if relative_k_error > 1e-5
    error("reqml:InconsistentWavefieldTruth", ...
        "truth.k_map_zx is inconsistent with frequency and cs.");
end

data = struct();
data.sample_file = sample_file;
data.sample_schema_name = string(sample.schema_name);
data.sample_schema_version = string(sample.schema_version);
data.generator = sample.generator;
data.wavefield_zx = wavefield_zx;
data.axes = struct("x_m", x_m, "z_m", z_m);
data.dx_m = dx_m;
data.dz_m = dz_m;
data.frequency_hz = frequency_hz;
data.quantity = string(sample.wavefield.quantity);
data.component = string(sample.wavefield.component);
data.units = string(sample.wavefield.units);
data.truth = struct();
data.truth.cs_m_s_zx = cs_truth_zx;
data.truth.k_rad_m_zx = k_truth_zx;
data.truth.material_id_zx = material_id_zx;
data.truth.valid_mask_zx = valid_mask_zx;
data.validation = sample.validation;
data.analysis_ready = resolve_analysis_ready(sample.validation);
data.provenance = sample.provenance;
data.raw_sample = sample;

end

function require_field(value, field_name, path_name, error_id)
if ~isstruct(value) || ~isfield(value, field_name)
    error(error_id, "%s is missing field '%s'.", path_name, field_name);
end
end

function spacing_m = validate_spacing(value, axis_m, axis_name)
spacing_m = double(value);
if ~isscalar(spacing_m) || ~isfinite(spacing_m) || spacing_m <= 0
    error("reqml:InvalidWavefieldCoordinates", ...
        "Declared spacing along %s must be positive.", axis_name);
end
if numel(axis_m) < 2
    error("reqml:InvalidWavefieldCoordinates", ...
        "At least two samples are required along %s.", axis_name);
end
increments = diff(axis_m);
tolerance = max(1e-12, 1e-6*abs(spacing_m));
if any(increments <= 0) || max(abs(increments-spacing_m)) > tolerance
    error("reqml:NonuniformWavefieldCoordinates", ...
        "Axis %s is not uniformly sampled.", axis_name);
end
end

function ready = resolve_analysis_ready(validation)
ready = true;
if isfield(validation, "analysis_ready")
    ready = logical(validation.analysis_ready);
end
if ~isscalar(ready)
    error("reqml:InvalidWavefieldValidation", ...
        "validation.analysis_ready must be scalar.");
end
end
