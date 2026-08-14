function tests = test_experimental_bilayer_benchmark_config
tests = functiontests(localfunctions);
end

function testPrespecifiedBenchmarkContract(testCase)
root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
config_file = fullfile(root, 'configs', 'benchmarks', ...
    'experimental_bilayer_400hz.json');
config = jsondecode(fileread(config_file));

verifyEqual(testCase, string(config.benchmark_id), ...
    "experimental_bilayer_400hz_v1");
verifyEqual(testCase, string({config.conditions.id}), ...
    ["H_SOFT" "H_STIFF" "BILAYER"]);
verifyEqual(testCase, config.interface_z_m, 0.019, AbsTol=eps);
verifyEqual(testCase, config.req.M, 2);
verifyEqual(testCase, config.req.step_pixels, 1);
verifyEqual(testCase, string(config.req.preprocessing), "raw");
verifyEqual(testCase, string(config.theory_discrete.field_type), "Diffuse3D");
verifyEqual(testCase, string(config.theory_discrete.theory_mode), "S2D");
verifyEqual(testCase, config.aia.M, 2);
verifyEqual(testCase, config.aia.step_pixels, 2);
verifyEqual(testCase, config.aia.num_angles, 180);
verifyFalse(testCase, config.aia.auto_decimate);
end

function testExistingInputsResolveWithoutOutputReuse(testCase)
root = string(fileparts(fileparts(fileparts(mfilename('fullpath')))));
simulation_root = fullfile(fileparts(root), ...
    'shear-wave-simulation-framework');
config = jsondecode(fileread(fullfile(root, 'configs', 'benchmarks', ...
    'experimental_bilayer_400hz.json')));
variables = struct('SWSIM_ROOT', simulation_root);

model_file = reqml.config.resolveWorkspacePath(config.model_file, ...
    RepositoryRoot=root, Variables=variables);
verifyTrue(testCase, isfile(model_file));
for index = 1:numel(config.conditions)
    sample_file = reqml.config.resolveWorkspacePath( ...
        config.conditions(index).sample_file, RepositoryRoot=root, ...
        Variables=variables);
    verifyTrue(testCase, isfile(sample_file), ...
        sprintf('Missing completed sample: %s', sample_file));
end
output_root = reqml.config.resolveWorkspacePath(config.output_root, ...
    RepositoryRoot=root, Variables=variables);
sample_roots = string({config.conditions.sample_file});
verifyFalse(testCase, any(contains(sample_roots, string(config.output_root))));
verifyTrue(testCase, contains(output_root, string(config.benchmark_id)));
end
