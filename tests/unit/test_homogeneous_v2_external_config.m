function tests=test_homogeneous_v2_external_config
tests=functiontests(localfunctions);
end

function setupOnce(testCase)
testCase.TestData.repo=string(fileparts(fileparts(fileparts(mfilename("fullpath")))));
testCase.TestData.path=fullfile(testCase.TestData.repo,"configs","homogeneous", ...
    "homogeneous_q0_external_transfer_v2.json");
testCase.TestData.config=jsondecode(fileread(testCase.TestData.path));
end

function testUsesCleanV2Identities(testCase)
raw=fileread(testCase.TestData.path);
verifyFalse(testCase,contains(raw,"_v1"));
verifyFalse(testCase,contains(raw,"/Users/"));
verifyTrue(testCase,all(contains(string({testCase.TestData.config.campaigns.campaign_name}),"v2")));
verifyEqual(testCase,sum(double([testCase.TestData.config.campaigns.expected_runs])),24);
end

function testMatchedAngularAnchors(testCase)
a=testCase.TestData.config.angular_anchors;
verifyEqual(testCase,double([a.angular_level]),[1 5 7]);
verifyEqual(testCase,double([a.direction_count]),[1 16 32]);
verifyEqual(testCase,double([a.in_plane_count]),[1 4 8]);
verifyEqual(testCase,double([a.angular_support_fraction]),[.01/(4*pi) .25 1],AbsTol=1e-14);
end

function testDualMAndPureCoreContract(testCase)
c=testCase.TestData.config;
verifyEqual(testCase,double(c.feature_config.M_values(:)),[2;3]);
verifyEqual(testCase,double(c.feature_config.cs_guess_m_s),3);
verifyEqual(testCase,double(c.roi_requirements.minimum_preferred_pure_core_patches_per_M),25);
verifyEqual(testCase,double(c.roi_requirements.inclusion_radius_m),.052);
end
