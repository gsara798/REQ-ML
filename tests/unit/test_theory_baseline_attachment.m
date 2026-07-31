function tests = test_theory_baseline_attachment
%TEST_THEORY_BASELINE_ATTACHMENT Test run-level theory diagnostics.

tests = functiontests(localfunctions);

end

function setupOnce(~)

root = fileparts(fileparts(fileparts( ...
    mfilename("fullpath"))));

addpath(fullfile(root, "src"));

end

function testResolvesConfiguredClasses(testCase)

mapping = make_mapping();

verifyEqual(testCase, ...
    reqml.theory.resolve_field_class(1, mapping), ...
    "SingleWave");

verifyEqual(testCase, ...
    reqml.theory.resolve_field_class(8, mapping), ...
    "PartialDiffuse3D");

verifyEqual(testCase, ...
    reqml.theory.resolve_field_class(128, mapping), ...
    "Diffuse3D");

end

function testAttachesPartialDiffuseTheory(testCase)

examples = make_examples();
run = make_run(8);
mapping = make_mapping();

feat_cfg = struct();
feat_cfg.gamma_win = 1;
feat_cfg.pad_factor = 1;
feat_cfg.smooth_sigma_2d = 1;

out = reqml.datasets.attach_theory_baseline( ...
    examples, ...
    run, ...
    feat_cfg, ...
    mapping);

expected = 0.5 * ( ...
    out.q_theory_single_wave_discrete(1) + ...
    out.q_theory_diffuse3d_discrete(1));

verifyEqual(testCase, ...
    unique(out.theory_field_class), ...
    "PartialDiffuse3D");

verifyEqual(testCase, ...
    out.q_theory_discrete, ...
    repmat(expected, height(out), 1), ...
    AbsTol=1e-12);

verifyTrue(testCase, all(out.q_theory_valid));

end

function testRegistryExcludesTheoryFromTraining(testCase)

examples = reqml.datasets.attach_theory_baseline( ...
    make_examples(), ...
    make_run(32), ...
    make_feature_config(), ...
    make_mapping());

registry = ...
    reqml.schema.dataset_variable_registry(examples);

names = [
    "theory_field_class"
    "q_theory_single_wave_discrete"
    "q_theory_diffuse3d_discrete"
    "q_theory_discrete"
    "q_theory_valid"
    ];

for name = names.'
    row = registry(registry.variable_name == name, :);

    verifyEqual(testCase, height(row), 1);
    verifyFalse(testCase, row.trainable);
    verifyEqual(testCase, row.group, "theory_baseline");
end

end

function examples = make_examples()

examples = table();
examples.GRID_dx_m = repmat(0.5e-3, 2, 1);
examples.GRID_dz_m = repmat(0.5e-3, 2, 1);
examples.REQ_cs_guess_m_s = repmat(3.0, 2, 1);
examples.REQ_M = repmat(2, 2, 1);
examples.REQ_Nbins_effective = repmat(41, 2, 1);
examples.mock_feature = [1; 2];

end

function run = make_run(direction_count)

run = table();
run.direction_count = direction_count;
run.frequency_hz = 500;

end

function mapping = make_mapping()

mapping = struct( ...
    "direction_count", ...
    {1; 4; 8; 32; 128}, ...
    "field_class", ...
    {"SingleWave"; ...
     "PartialDiffuse3D"; ...
     "PartialDiffuse3D"; ...
     "Diffuse3D"; ...
     "Diffuse3D"});

end

function config = make_feature_config()

config = struct();
config.gamma_win = 1;
config.pad_factor = 1;
config.smooth_sigma_2d = 1;

end
