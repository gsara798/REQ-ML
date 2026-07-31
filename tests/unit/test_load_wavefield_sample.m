function tests = test_load_wavefield_sample
tests = functiontests(localfunctions);
end

function setupOnce(~)
root = fileparts(fileparts(fileparts(mfilename("fullpath"))));
addpath(fullfile(root, "src"));
end

function testLoadsValidSample(testCase)
sample_file = write_sample(valid_sample());
cleanup = onCleanup(@() delete_if_present(sample_file));

data = reqml.io.load_wavefield_sample(sample_file);

verifyEqual(testCase, data.sample_schema_name, "wavefield_sample");
verifyEqual(testCase, data.sample_schema_version, "1.0");
verifyEqual(testCase, data.generator.name, "kwsim");
verifyEqual(testCase, data.wavefield_zx, valid_sample().wavefield.data_zx);
verifyEqual(testCase, data.dx_m, 0.5e-3);
verifyEqual(testCase, data.dz_m, 0.5e-3);
verifyEqual(testCase, data.frequency_hz, 500);
verifyEqual(testCase, data.quantity, "displacement");
verifyEqual(testCase, data.component, "axial_total");
verifyEqual(testCase, data.truth.cs_m_s_zx, 2*ones(3,4));
verifyTrue(testCase, data.analysis_ready);

clear cleanup
end

function testRejectsWrongVariableName(testCase)
wrong_name = valid_sample(); %#ok<NASGU>
sample_file = string(tempname) + ".mat";
save(sample_file, "wrong_name");
cleanup = onCleanup(@() delete_if_present(sample_file));

verifyError(testCase, ...
    @() reqml.io.load_wavefield_sample(sample_file), ...
    "reqml:InvalidWavefieldSample");

clear cleanup
end

function testRejectsWrongOrientation(testCase)
sample = valid_sample();
sample.coordinates.array_order = "xz";
sample_file = write_sample(sample);
cleanup = onCleanup(@() delete_if_present(sample_file));

verifyError(testCase, ...
    @() reqml.io.load_wavefield_sample(sample_file), ...
    "reqml:InvalidWavefieldOrientation");

clear cleanup
end

function testRejectsInconsistentTruthWavenumber(testCase)
sample = valid_sample();
sample.truth.k_map_zx = 2*sample.truth.k_map_zx;
sample_file = write_sample(sample);
cleanup = onCleanup(@() delete_if_present(sample_file));

verifyError(testCase, ...
    @() reqml.io.load_wavefield_sample(sample_file), ...
    "reqml:InconsistentWavefieldTruth");

clear cleanup
end

function testRejectsWavefieldAxisSizeMismatch(testCase)
sample = valid_sample();
sample.coordinates.x_m = sample.coordinates.x_m(1:3);
sample_file = write_sample(sample);
cleanup = onCleanup(@() delete_if_present(sample_file));

verifyError(testCase, ...
    @() reqml.io.load_wavefield_sample(sample_file), ...
    "reqml:InvalidWavefieldSize");

clear cleanup
end

function sample = valid_sample()
Nz = 3; Nx = 4; frequency_hz = 500;
cs_map_zx = 2*ones(Nz,Nx);

sample = struct();
sample.schema_name = "wavefield_sample";
sample.schema_version = "1.0";
sample.generator = struct("name","kwsim","backend","full_wave_kwave");
sample.coordinates = struct();
sample.coordinates.x_m = (0:Nx-1)*0.5e-3;
sample.coordinates.z_m = (0:Nz-1)*0.5e-3;
sample.coordinates.dx_m = 0.5e-3;
sample.coordinates.dz_m = 0.5e-3;
sample.coordinates.array_order = "zx";

sample.wavefield = struct();
sample.wavefield.data_zx = complex(reshape(1:Nz*Nx,Nz,Nx),0.25);
sample.wavefield.component = "axial_total";
sample.wavefield.quantity = "displacement";
sample.wavefield.frequency_hz = frequency_hz;
sample.wavefield.units = "m";

sample.truth = struct();
sample.truth.cs_map_zx = cs_map_zx;
sample.truth.k_map_zx = 2*pi*frequency_hz ./ cs_map_zx;
sample.truth.material_id_zx = ones(Nz,Nx,"uint16");
sample.truth.valid_mask_zx = true(Nz,Nx);

sample.validation = struct("valid",true,"analysis_ready",true);
sample.provenance = struct("run_id","unit_test");
end

function sample_file = write_sample(sample)
sample_file = string(tempname) + ".mat";
wavefield_sample = sample; %#ok<NASGU>
save(sample_file, "wavefield_sample", "-v7.3");
end

function delete_if_present(path_value)
if isfile(path_value)
    delete(path_value);
end
end
