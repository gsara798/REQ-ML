function tests = test_compute_nominal_angular_coverage
%TEST_COMPUTE_NOMINAL_ANGULAR_COVERAGE Test Dnom computation.

tests = functiontests(localfunctions);

end


function setupOnce(~)

root = fileparts(fileparts(fileparts( ...
    mfilename("fullpath"))));

addpath(fullfile(root, "src"));

end


function testComputesExpectedValues(testCase)

direction_count = [1; 16; 32; 64; 128];
solid_angle_sr = [0.01; pi; 4*pi; 4*pi; 4*pi];

actual = reqml.coverage.computeNominalAngularCoverage( ...
    direction_count, ...
    solid_angle_sr, ...
    MaximumDirectionCount=128);

expected = [
    (1/128) * (0.01/(4*pi))
    (16/128) * (pi/(4*pi))
    32/128
    64/128
    1
    ];

verifyEqual(testCase, actual, expected, AbsTol=1e-12);

end


function testInvertsMaterializedField(testCase)

stream = RandStream("Threefry", Seed=9101);

field = reqml.campaigns.materializeNominalAngularField( ...
    stream, ...
    [0.35 0.55], ...
    MaximumDirectionCount=128);

actual = reqml.coverage.computeNominalAngularCoverage( ...
    field.direction_count, ...
    field.solid_angle_sr, ...
    MaximumDirectionCount=128);

verifyEqual(testCase, ...
    actual, ...
    field.nominal_angular_coverage, ...
    AbsTol=1e-12);

end


function testMarksInvalidRowsAsNaN(testCase)

actual = reqml.coverage.computeNominalAngularCoverage( ...
    [0; 129; 16; NaN], ...
    [1; 1; 5*pi; 1]);

verifyTrue(testCase, all(isnan(actual)));

end


function testToleratesRoundoffAtFullSphere(testCase)

slightly_above_full_sphere = ...
    4*pi + 10*eps(4*pi);

actual = reqml.coverage.computeNominalAngularCoverage( ...
    32, ...
    slightly_above_full_sphere, ...
    MaximumDirectionCount=128);

verifyEqual(testCase, actual, 0.25, AbsTol=1e-12);

end


function testRejectsUnequalSizes(testCase)

verifyError(testCase, ...
    @() reqml.coverage.computeNominalAngularCoverage( ...
        [1; 2], ...
        0.5), ...
    "reqml:NominalAngularCoverageSizeMismatch");

end
