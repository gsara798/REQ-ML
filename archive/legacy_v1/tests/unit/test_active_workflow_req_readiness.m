function tests = test_active_workflow_req_readiness
%TEST_ACTIVE_WORKFLOW_REQ_READINESS Verify active workflows gate on readiness.

tests = functiontests(localfunctions);

end

function setupOnce(~)

root = fileparts(fileparts(fileparts( ...
    mfilename("fullpath"))));

addpath(fullfile(root, "src"));

end

function testSmokeRejectsSampleThatIsNotReqReady(testCase)

sample_file = write_wavefield_sample(20, 20);
cleanup = onCleanup(@() delete_if_present(sample_file));

verifyError(testCase, ...
    @() reqml.integration.evaluate_kwsim_req_smoke( ...
        sample_file, ...
        CsGuessMPerS=3.0, ...
        WindowWavelengths=2.0, ...
        MinimumPlacementsPerAxis=5), ...
    "reqml:WavefieldSampleNotReqReady");

clear cleanup

end

function testFrozenModelsRejectBeforeBundleLoad(testCase)

sample_file = write_wavefield_sample(20, 20);
cleanup = onCleanup(@() delete_if_present(sample_file));

missing_bundle = string(tempname) + ".mat";

verifyError(testCase, ...
    @() reqml.integration.evaluate_kwsim_frozen_models( ...
        sample_file, ...
        missing_bundle, ...
        CsGuessMPerS=3.0, ...
        WindowWavelengths=2.0, ...
        MinimumPlacementsPerAxis=5), ...
    "reqml:WavefieldSampleNotReqReady");

clear cleanup

end

function sample_file = write_wavefield_sample(Nz, Nx)

frequency_hz = 500;
dx_m = 0.5e-3;
dz_m = 0.5e-3;
cs_map_zx = 2 * ones(Nz, Nx);

wavefield_sample = struct();
wavefield_sample.schema_name = "wavefield_sample";
wavefield_sample.schema_version = "1.0";

wavefield_sample.generator = struct();
wavefield_sample.generator.name = "kwsim";
wavefield_sample.generator.backend = "full_wave_kwave";

wavefield_sample.coordinates = struct();
wavefield_sample.coordinates.x_m = (0:(Nx - 1)) * dx_m;
wavefield_sample.coordinates.z_m = (0:(Nz - 1)) * dz_m;
wavefield_sample.coordinates.dx_m = dx_m;
wavefield_sample.coordinates.dz_m = dz_m;
wavefield_sample.coordinates.array_order = "zx";

wavefield_sample.wavefield = struct();
wavefield_sample.wavefield.data_zx = complex(ones(Nz, Nx), 0.25);
wavefield_sample.wavefield.frequency_hz = frequency_hz;
wavefield_sample.wavefield.component = "axial_total";
wavefield_sample.wavefield.quantity = "displacement";
wavefield_sample.wavefield.units = "m";

wavefield_sample.truth = struct();
wavefield_sample.truth.cs_map_zx = cs_map_zx;
wavefield_sample.truth.k_map_zx = ...
    2*pi*frequency_hz ./ cs_map_zx;
wavefield_sample.truth.material_id_zx = ...
    ones(Nz, Nx, "uint16");
wavefield_sample.truth.valid_mask_zx = ...
    true(Nz, Nx);

wavefield_sample.validation = struct();
wavefield_sample.validation.valid = true;
wavefield_sample.validation.analysis_ready = true;

wavefield_sample.propagation = struct();
wavefield_sample.propagation.source_dimension = 3;

wavefield_sample.provenance = struct();

sample_file = string(tempname) + ".mat";

save(sample_file, ...
    "wavefield_sample", ...
    "-v7.3");

end

function delete_if_present(path_value)

if isfile(path_value)
    delete(path_value);
end

end
