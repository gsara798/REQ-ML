function tests = test_wavefield_sample_legacy_equivalence
%TEST_WAVEFIELD_SAMPLE_LEGACY_EQUIVALENCE
% Confirm generic and legacy files yield identical estimator inputs.

tests = functiontests(localfunctions);

end

function setupOnce(~)

root = fileparts(fileparts(fileparts( ...
    mfilename("fullpath"))));

addpath(fullfile(root, "src"));

end

function testGenericAndLegacyInputsAreEquivalent(testCase)

[generic_file, legacy_file] = write_equivalent_samples();

cleanup = onCleanup(@() delete_files( ...
    generic_file, legacy_file));

generic = reqml.integration.load_wavefield_sample( ...
    generic_file);

legacy = reqml.integration.load_kwsim_validation_sample( ...
    legacy_file);

verifyEqual(testCase, generic.wavefield_zx, legacy.wavefield_zx);
verifyEqual(testCase, generic.axes.x_m, legacy.axes.x_m);
verifyEqual(testCase, generic.axes.z_m, legacy.axes.z_m);
verifyEqual(testCase, generic.dx_m, legacy.dx_m);
verifyEqual(testCase, generic.dz_m, legacy.dz_m);
verifyEqual(testCase, generic.frequency_hz, legacy.frequency_hz);
verifyEqual(testCase, ...
    generic.truth.cs_m_s_zx, ...
    legacy.truth.cs_m_s_zx);
verifyEqual(testCase, ...
    generic.truth.material_id_zx, ...
    legacy.truth.material_id_zx);
verifyEqual(testCase, generic.quantity, legacy.quantity);
verifyEqual(testCase, generic.units, legacy.units);
verifyEqual(testCase, ...
    generic.source_dimension, ...
    legacy.source_dimension);
verifyEqual(testCase, generic.extraction, legacy.extraction);

clear cleanup

end

function [generic_file, legacy_file] = write_equivalent_samples()

Nz = 3;
Nx = 4;
frequency_hz = 500;
dx_m = 0.5e-3;
dz_m = 0.5e-3;

x_m = (0:(Nx - 1)) * dx_m;
z_m = (0:(Nz - 1)) * dz_m;

wavefield_zx = complex( ...
    reshape(1:(Nz*Nx), Nz, Nx), ...
    0.25);

cs_map_zx = 2 * ones(Nz, Nx);
material_id_zx = ones(Nz, Nx, "uint16");

extraction = struct();
extraction.method = "central_xz_slice";
extraction.y_index = 4;
extraction.y_m = 0.5e-3;

wavefield_sample = struct();
wavefield_sample.schema_name = "wavefield_sample";
wavefield_sample.schema_version = "1.0";

wavefield_sample.generator = struct();
wavefield_sample.generator.name = "kwsim";
wavefield_sample.generator.backend = "full_wave_kwave";

wavefield_sample.coordinates = struct();
wavefield_sample.coordinates.x_m = x_m;
wavefield_sample.coordinates.z_m = z_m;
wavefield_sample.coordinates.dx_m = dx_m;
wavefield_sample.coordinates.dz_m = dz_m;
wavefield_sample.coordinates.array_order = "zx";

wavefield_sample.wavefield = struct();
wavefield_sample.wavefield.data_zx = wavefield_zx;
wavefield_sample.wavefield.frequency_hz = frequency_hz;
wavefield_sample.wavefield.component = "axial_total";
wavefield_sample.wavefield.quantity = "displacement";
wavefield_sample.wavefield.units = "m";

wavefield_sample.truth = struct();
wavefield_sample.truth.cs_map_zx = cs_map_zx;
wavefield_sample.truth.k_map_zx = ...
    2*pi*frequency_hz ./ cs_map_zx;
wavefield_sample.truth.material_id_zx = material_id_zx;
wavefield_sample.truth.valid_mask_zx = true(Nz, Nx);

wavefield_sample.validation = struct();
wavefield_sample.validation.valid = true;
wavefield_sample.validation.analysis_ready = true;

wavefield_sample.propagation = struct();
wavefield_sample.propagation.source_dimension = 3;

wavefield_sample.extraction = extraction;
wavefield_sample.provenance = struct();

req_validation_sample = struct();
req_validation_sample.sample_schema_version = "1.0";
req_validation_sample.source_dimension = 3;
req_validation_sample.wavefield_complex_zx = wavefield_zx;

req_validation_sample.axes = struct();
req_validation_sample.axes.x_m = x_m;
req_validation_sample.axes.z_m = z_m;

req_validation_sample.spacing = struct();
req_validation_sample.spacing.dx_m = dx_m;
req_validation_sample.spacing.dz_m = dz_m;

req_validation_sample.truth = struct();
req_validation_sample.truth.cs_m_s_zx = cs_map_zx;
req_validation_sample.truth.material_id_zx = material_id_zx;

req_validation_sample.frequency_hz = frequency_hz;
req_validation_sample.orientation = "[Nz,Nx]";
req_validation_sample.quantity = "displacement";
req_validation_sample.units = "m";
req_validation_sample.extraction = extraction;
req_validation_sample.simulation_valid = true;

generic_file = string(tempname) + ".mat";
legacy_file = string(tempname) + ".mat";

save(generic_file, "wavefield_sample", "-v7.3");
save(legacy_file, "req_validation_sample", "-v7.3");

end

function delete_files(varargin)

for index = 1:nargin
    if isfile(varargin{index})
        delete(varargin{index});
    end
end

end
