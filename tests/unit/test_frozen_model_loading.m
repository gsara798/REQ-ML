function tests = test_frozen_model_loading
%TEST_FROZEN_MODEL_LOADING Tests for persisted model selection.

tests = functiontests(localfunctions);

end

function testLoadsNamedModel(testCase)

temporaryFile = string(tempname) + ".mat";
cleanupObject = onCleanup(@() deleteIfPresent(temporaryFile)); %#ok<NASGU>

model_metadata = {
    struct( ...
        "model_id", "ridge_full", ...
        "model_type", "ridge", ...
        "value", 1)
    struct( ...
        "model_id", "bagged_full", ...
        "model_type", "bagged_trees", ...
        "value", 2)
    };

save(char(temporaryFile), "model_metadata");

model = reqml.training.load_frozen_model( ...
    temporaryFile, ...
    "bagged_full");

verifyEqual(testCase, model.model_id, "bagged_full");
verifyEqual(testCase, model.model_type, "bagged_trees");
verifyEqual(testCase, model.value, 2);

end

function testRejectsMissingModel(testCase)

temporaryFile = string(tempname) + ".mat";
cleanupObject = onCleanup(@() deleteIfPresent(temporaryFile)); %#ok<NASGU>

model_metadata = {
    struct( ...
        "model_id", "ridge_full", ...
        "model_type", "ridge")
    };

save(char(temporaryFile), "model_metadata");

verifyError( ...
    testCase, ...
    @() reqml.training.load_frozen_model( ...
        temporaryFile, ...
        "bagged_full"), ...
    "reqml:FrozenModelNotFound");

end

function testRejectsMissingFile(testCase)

missingFile = string(tempname) + ".mat";

verifyError( ...
    testCase, ...
    @() reqml.training.load_frozen_model( ...
        missingFile, ...
        "bagged_full"), ...
    "reqml:MissingFrozenModelFile");

end

function deleteIfPresent(path)

if isfile(path)
    delete(path);
end

end
