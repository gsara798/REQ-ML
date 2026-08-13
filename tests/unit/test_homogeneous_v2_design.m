function tests=test_homogeneous_v2_design
tests=functiontests(localfunctions);
end

function setupOnce(testCase)
root=string(fileparts(fileparts(fileparts(mfilename("fullpath")))));
testCase.TestData.previous=getenv("SWSIM_ROOT");
setenv("SWSIM_ROOT",fullfile(fileparts(root),"shear-wave-simulation-framework"));
end
function teardownOnce(testCase), setenv("SWSIM_ROOT",testCase.TestData.previous); end

function testResolvedCartesianCounts(testCase)
d=reqml.homogeneous.materializeCartesianDesign(load_config());
verifyEqual(testCase,d.condition_count,910); verifyEqual(testCase,d.run_count,2730);
verifyEqual(testCase,d.req_M_values,[2;3]);
verifyEqual(testCase,unique(d.conditions.cs_m_s),(1:.25:4)');
verifyEqual(testCase,unique(d.conditions.dx_m),[.00025;.0005]);
verifyEqual(testCase,unique(d.conditions.angular_level),(1:7)');
verifyEqual(testCase,groupcounts(d.runs.condition_id),3*ones(910,1));
end

function testDomainUsesM3AndSupportsBothQuotas(testCase)
d=reqml.homogeneous.materializeCartesianDesign(load_config());
verifyEqual(testCase,unique(d.conditions.domain_basis_M),3);
verifyGreaterThanOrEqual(testCase,d.conditions.m2_available_patch_count,100*ones(910,1));
verifyGreaterThanOrEqual(testCase,d.conditions.m3_available_patch_count,100*ones(910,1));
verifyGreaterThan(testCase,d.conditions.m3_patch_width_px,d.conditions.m2_patch_width_px);
end

function testDeterministicAndNoMDuplicatedRuns(testCase)
c=load_config(); a=reqml.homogeneous.materializeCartesianDesign(c);
b=reqml.homogeneous.materializeCartesianDesign(c);
verifyEqual(testCase,a.conditions,b.conditions); verifyEqual(testCase,a.runs,b.runs);
verifyEqual(testCase,height(a.runs),2730);
verifyFalse(testCase,ismember("REQ_M",string(a.runs.Properties.VariableNames)));
end

function testCampaignManifestDeclaresSharedMValues(testCase)
folder=string(testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture).Folder);
r=reqml.homogeneous.writeCartesianCampaign(config_path(),OutputDirectory=folder);
m=jsondecode(fileread(r.paths.manifest_json));
verifyEqual(testCase,double(m.req_M_values(:)),[2;3]);
verifyEqual(testCase,double(m.run_count),2730);
verifyEqual(testCase,numel(r.campaign.runs),2730);
end

function testInvalidCsGuessMessageDescribesDualMContract(testCase)
c=load_config(); c.req.cs_guess_m_s=2.5;
try
    reqml.homogeneous.materializeCartesianDesign(c);
    verifyFail(testCase,"Expected invalid REQ contract error.");
catch exception
    verifyEqual(testCase,exception.identifier,'reqml:InvalidHomogeneousQ0ReqContract');
    verifySubstring(testCase,exception.message,"supports M=2 and M=3");
end
end

function c=load_config, c=jsondecode(fileread(config_path())); end
function path=config_path
root=string(fileparts(fileparts(fileparts(mfilename("fullpath")))));
path=fullfile(root,"configs","homogeneous","homogeneous_cartesian_q0_v2.json");
end
