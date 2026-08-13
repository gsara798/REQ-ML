function tests=test_homogeneous_v2_external_roi_feasibility
tests=functiontests(localfunctions);
end

function testLargeInclusionHasPureCoreForBothM(testCase)
r=reqml.homogeneous.assessExternalRoiFeasibility("inclusion", ...
    DomainSizeM=.15,GridSpacingM=.0005,InclusionRadiusM=.052);
verifyGreaterThanOrEqual(testCase,r.inclusion_core_count,25*ones(2,1));
verifyGreaterThanOrEqual(testCase,r.background_far_count,25*ones(2,1));
verifyGreaterThan(testCase,r.interface_band_count,zeros(2,1));
end

function testObliqueBilayerHasBothCores(testCase)
r=reqml.homogeneous.assessExternalRoiFeasibility("bilayer", ...
    DomainSizeM=.15,GridSpacingM=.0005,InterfaceAngleRad=pi/6);
verifyGreaterThanOrEqual(testCase,r.layer1_core_count,25*ones(2,1));
verifyGreaterThanOrEqual(testCase,r.layer2_core_count,25*ones(2,1));
verifyGreaterThan(testCase,r.interface_band_count,zeros(2,1));
end

function testSmallV1LikeInclusionFailsCoreQuota(testCase)
r=reqml.homogeneous.assessExternalRoiFeasibility("inclusion", ...
    DomainSizeM=.05,GridSpacingM=.0005,InclusionRadiusM=.008);
verifyLessThan(testCase,r.inclusion_core_count,25*ones(2,1));
end
