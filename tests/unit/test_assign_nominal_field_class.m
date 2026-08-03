function tests = test_assign_nominal_field_class
%TEST_ASSIGN_NOMINAL_FIELD_CLASS Test prescribed field classification.

tests = functiontests(localfunctions);

end


function setupOnce(~)

root = fileparts(fileparts(fileparts( ...
    mfilename("fullpath"))));

addpath(fullfile(root, "src"));

end


function testClassifiesControlledFieldRegimes(testCase)

examples = table();

examples.campaign_direction_count = [1; 16; 32];
examples.campaign_solid_angle_sr = [0.01; pi; 4*pi];

actual = reqml.coverage.assignNominalFieldClass(examples);

verifyEqual(testCase, actual, [1; 2; 3]);

end


function testRejectsMissingControlledVariable(testCase)

examples = table();
examples.campaign_direction_count = 1;

verifyError(testCase, ...
    @() reqml.coverage.assignNominalFieldClass(examples), ...
    "reqml:MissingNominalFieldVariable");

end
