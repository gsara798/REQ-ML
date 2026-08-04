function tests = test_compute_bilayer_interface_placement
%TEST_COMPUTE_BILAYER_INTERFACE_PLACEMENT Test discrete purity control.

tests = functiontests(localfunctions);

end


function setupOnce(~)

root = fileparts(fileparts(fileparts( ...
    mfilename("fullpath"))));
addpath(fullfile(root, "src"));

end


function testRequestedPurityBins(testCase)

ranges = [ ...
    0.50 0.70
    0.70 0.90
    0.90 0.98
    0.98 1.00
    ];

for index = 1:size(ranges, 1)
    placement = make_placement(ranges(index, :), 61, "negative");

    verifyGreaterThanOrEqual(testCase, ...
        placement.achieved_discrete_purity, ranges(index, 1));
    verifyLessThan(testCase, ...
        placement.achieved_discrete_purity, ranges(index, 2));
end

end


function testLargeLowFrequencyWindow(testCase)

% M=3, cs_guess=3 m/s, f=200 Hz, dx=0.5 mm resolves to 91 pixels.
win_size = round(3 * 3 / 200 / 0.0005);
if mod(win_size, 2) == 0
    win_size = win_size + 1;
end

verifyEqual(testCase, win_size, 91);

placement = make_placement([0.9 0.98], win_size, "negative");

verifyGreaterThanOrEqual(testCase, ...
    placement.predicted_discrete_purity, 0.9);
verifyLessThan(testCase, ...
    placement.predicted_discrete_purity, 0.98);
verifyEqual(testCase, ...
    placement.patch_size_pixels, [91 91]);

end


function testExactPurityOnePlacesInterfaceOutsidePatch(testCase)

placement = make_placement([1 1], 91, "negative");

verifyEqual(testCase, placement.achieved_discrete_purity, 1);
verifyTrue(testCase, ...
    placement.diagnostics.interface_is_outside_patch_support);

evaluated = reqml.campaigns.evaluateBilayerPatchPurity( ...
    placement.patch_size_pixels, ...
    placement.selected_patch_center_indices_xz, ...
    placement.grid_spacing_m, ...
    placement.interface_position_m, ...
    InterfaceOrientation=placement.interface_orientation, ...
    DominantMaterialSide=placement.dominant_material_side);

verifyEqual(testCase, unique(evaluated.material_patch), uint16(0));

end


function testBothDominantMaterialSides(testCase)

negative = make_placement([0.9 0.98], 61, "negative");
positive = make_placement([0.9 0.98], 61, "positive");

verifyGreaterThan(testCase, negative.interface_offset_pixels, 0);
verifyLessThan(testCase, positive.interface_offset_pixels, 0);
verifyEqual(testCase, ...
    negative.achieved_discrete_purity, ...
    positive.achieved_discrete_purity);

end


function testZOrientedInterface(testCase)

placement = reqml.campaigns.computeBilayerInterfacePlacement( ...
    [0.7 0.9], [61 61], [0.0005 0.0005], [51 51], [0.05 0.05], ...
    InterfaceOrientation="z", ...
    DominantMaterialSide="positive");

verifyEqual(testCase, placement.interface_orientation, "z");
verifyEqual(testCase, placement.normal_angle_rad, pi/2, AbsTol=eps);
verifyGreaterThanOrEqual(testCase, ...
    placement.achieved_discrete_purity, 0.7);
verifyLessThan(testCase, placement.achieved_discrete_purity, 0.9);

end


function testPlacementIsReproducible(testCase)

a = make_placement([0.9 0.98], 91, "negative");
b = make_placement([0.9 0.98], 91, "negative");

verifyEqual(testCase, a, b);

end


function testInsufficientDomainMarginForPurePatch(testCase)

verifyError(testCase, @() ...
    reqml.campaigns.computeBilayerInterfacePlacement( ...
        [1 1], [101 101], [0.0005 0.0005], [51 51], [0.05 0.05]), ...
    "reqml:AnalyticBilayerInsufficientDomainMargin");

end


function testNoDiscreteOffsetInNarrowBin(testCase)

verifyError(testCase, @() ...
    reqml.campaigns.computeBilayerInterfacePlacement( ...
        [0.7 0.9], [3 3], [0.0005 0.0005], [5 5], [0.004 0.004]), ...
    "reqml:AnalyticBilayerNoDiscreteOffset");

end


function testEvenWindowReportsUnsupportedConvention(testCase)

verifyError(testCase, @() ...
    reqml.campaigns.computeBilayerInterfacePlacement( ...
        [0.5 0.7], [20 20], [0.0005 0.0005], [51 51], [0.05 0.05]), ...
    "reqml:UnsupportedEvenPatchSupport");

end


function testPredictedPurityMatchesDiscreteTruthMask(testCase)

placement = make_placement([0.9 0.98], 91, "positive");

half_win = floor(placement.patch_size_pixels / 2);
x_indices = (51-half_win(1)):(51+half_win(1));
z_indices = (51-half_win(2)):(51+half_win(2));
[X, ~] = meshgrid( ...
    (x_indices - 1) * placement.grid_spacing_m(1), ...
    (z_indices - 1) * placement.grid_spacing_m(2));

truth_material_patch = uint16( ...
    X - placement.interface_position_m > 0);
truth_purity = reqml.datasets.computeMaterialPatchPurity( ...
    truth_material_patch, true(size(truth_material_patch)));

verifyEqual(testCase, ...
    placement.predicted_discrete_purity, truth_purity);

end


function placement = make_placement(range, win_size, side)

placement = reqml.campaigns.computeBilayerInterfacePlacement( ...
    range, [win_size win_size], [0.0005 0.0005], [51 51], [0.05 0.05], ...
    InterfaceOrientation="x", ...
    DominantMaterialSide=side);

end
