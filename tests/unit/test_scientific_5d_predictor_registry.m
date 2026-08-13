function tests = test_scientific_5d_predictor_registry
%TEST_SCIENTIFIC_5D_PREDICTOR_REGISTRY Test predictor safety contract.

tests = functiontests(localfunctions);

end

function setupOnce(~)

root = fileparts(fileparts(fileparts( ...
    mfilename("fullpath"))));

addpath(fullfile(root, "src"));

end

function testBasePredictorsAreValidForScientificDataset(testCase)

examples = load_scientific_examples();
registry = ...
    reqml.training.scientific_5d_predictor_registry();

purity_report = ...
    reqml.training.validate_predictor_contract( ...
        examples, ...
        registry.purity_predictors, ...
        registry);

q_report = ...
    reqml.training.validate_predictor_contract( ...
        examples, ...
        registry.q_spectrum_predictors, ...
        registry);

verifyTrue(testCase, ...
    purity_report.valid, ...
    purity_report.summary);

verifyTrue(testCase, ...
    q_report.valid, ...
    q_report.summary);

end

function testCompositionModelExtendsSpectrumModelExactly(testCase)

registry = ...
    reqml.training.scientific_5d_predictor_registry();

base_count = numel(registry.q_spectrum_predictors);

verifyEqual(testCase, ...
    registry.q_composition_predictors(1:base_count), ...
    registry.q_spectrum_predictors);

verifyEqual(testCase, ...
    registry.q_composition_predictors(base_count + 1:end), ...
    registry.composition_prediction_predictors);

end

function testRejectsTruthAndDiagnosticPredictors(testCase)

examples = load_scientific_examples();
registry = ...
    reqml.training.scientific_5d_predictor_registry();

unsafe = [
    registry.q_spectrum_predictors
    "truth_material_purity"
    "q_local_req"
    "achieved_purity"
    "campaign_direction_count"
    ];

report = reqml.training.validate_predictor_contract( ...
    examples, ...
    unsafe, ...
    registry);

verifyFalse(testCase, report.valid);

verifyEqual(testCase, ...
    sort(report.forbidden_names), ...
    sort([
        "truth_material_purity"
        "q_local_req"
        "achieved_purity"
        "campaign_direction_count"
    ]));

end

function testFutureCompositionColumnsMayBeValidatedBeforeAppending(testCase)

examples = load_scientific_examples();
registry = ...
    reqml.training.scientific_5d_predictor_registry();

report = reqml.training.validate_predictor_contract( ...
    examples, ...
    registry.q_composition_predictors, ...
    registry, ...
    RequireExisting=false);

verifyTrue(testCase, report.valid);
verifyEqual(testCase, ...
    report.missing_names, ...
    registry.composition_prediction_predictors);

end

function testPredictorOrderIsDeterministic(testCase)

a = reqml.training.scientific_5d_predictor_registry();
b = reqml.training.scientific_5d_predictor_registry();

verifyEqual(testCase, ...
    a.q_spectrum_predictors, ...
    b.q_spectrum_predictors);

verifyEqual(testCase, ...
    a.q_composition_predictors, ...
    b.q_composition_predictors);

end

function testGenericQ0RegistryIsExactlyLegacyCompatible(testCase)
generic=reqml.training.q0_predictor_registry();
legacy=reqml.training.scientific_5d_predictor_registry();
verifyEqual(testCase,generic.q_spectrum_predictors, ...
    legacy.q_spectrum_predictors);
verifyEqual(testCase,generic.operational_predictors, ...
    legacy.operational_predictors);
verifyEqual(testCase,generic.spectral_predictors,legacy.spectral_predictors);
verifyEqual(testCase,generic.forbidden_exact_names, ...
    legacy.forbidden_exact_names);
end

function examples = load_scientific_examples()

root = fileparts(fileparts(fileparts( ...
    mfilename("fullpath"))));

path = fullfile( ...
    root, ...
    "outputs", ...
    "adaptive_scientific_5d", ...
    "reqml_adaptive_scientific_5d_final", ...
    "reqml_adaptive_scientific_5d_final_iteration_050", ...
    "dataset", ...
    "examples.mat");

if ~isfile(path)
    error("reqml:Scientific5DTestDatasetMissing", ...
        "Required scientific test dataset is missing: %s", path);
end

loaded = load(path, "examples");
examples = loaded.examples;

end
