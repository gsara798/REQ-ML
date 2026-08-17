function tests = test_analytic_point_force_design
%TEST_ANALYTIC_POINT_FORCE_DESIGN Validate the fixed eight-case design.
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
root = fileparts(fileparts(fileparts(mfilename("fullpath"))));
addpath(fullfile(root,"src"));
file = fullfile(root,"configs","validation", ...
    "reqml_analytic_point_force_q0_v1.json");
testCase.TestData.config = jsondecode(fileread(file));
end

function testExactlyEightUniqueCases(testCase)
[campaign,design] = buildDesign(testCase);
verifyEqual(testCase,height(design),8);
verifyEqual(testCase,numel(campaign.runs),8);
verifyEqual(testCase,numel(unique(design.design_id)),8);
verifyEqual(testCase,unique(design.cs_true_m_s),[2;3]);
verifyEqual(testCase,unique(design.geometric_decay_exponent),[0;1]);
end

function testForcesAndFixedContract(testCase)
[~,design] = buildDesign(testCase);
sourceX = design.force_label=="sourcex";
sourceZ = design.force_label=="sourcez";
verifyEqual(testCase,[design.force_x(sourceX),design.force_y(sourceX), ...
    design.force_z(sourceX)],repmat([1 0 0],4,1));
verifyEqual(testCase,[design.force_x(sourceZ),design.force_y(sourceZ), ...
    design.force_z(sourceZ)],repmat([0 0 1],4,1));
verifyEqual(testCase,design.source_radius_m,0.05*ones(8,1));
verifyEqual(testCase,design.frequency_hz,400*ones(8,1));
verifyEqual(testCase,unique(design.radiation_model), ...
    "point_force_shear_far_field");
verifyEqual(testCase,testCase.TestData.config.M,2);
verifyEqual(testCase,testCase.TestData.config.step_pixels,1);
verifyNotEmpty(testCase, ...
    testCase.TestData.config.required_simulation_framework_commit);
end

function testMatchedCasesDifferOnlyAsDesigned(testCase)
[campaign,design] = buildDesign(testCase);
for cs = [2 3]
    for decay = [0 1]
        zIndex = find(design.cs_true_m_s==cs & ...
            design.geometric_decay_exponent==decay & ...
            design.force_label=="sourcez");
        xIndex = find(design.cs_true_m_s==cs & ...
            design.geometric_decay_exponent==decay & ...
            design.force_label=="sourcex");
        verifyEqual(testCase,design.seed(zIndex),design.seed(xIndex));
        verifyEqual(testCase,design{zIndex,["expected_source_x_m", ...
            "expected_source_y_m","expected_source_z_m"]}, ...
            design{xIndex,["expected_source_x_m","expected_source_y_m", ...
            "expected_source_z_m"]});
        verifyOverridesDifferOnly(testCase,campaign.runs(zIndex).overrides, ...
            campaign.runs(xIndex).overrides, ...
            ["scenario","sources.radiation.force_direction_xyz"]);
    end
end

for cs = [2 3]
    for force = ["sourcex","sourcez"]
        noSpread = find(design.cs_true_m_s==cs & ...
            design.force_label==force & design.geometric_decay_exponent==0);
        spread = find(design.cs_true_m_s==cs & ...
            design.force_label==force & design.geometric_decay_exponent==1);
        verifyOverridesDifferOnly(testCase, ...
            campaign.runs(noSpread).overrides,campaign.runs(spread).overrides, ...
            ["scenario","amplitude.geometric_decay_exponent"]);
    end
end
end

function testCampaignContainsRadiationOverrides(testCase)
[campaign,~] = buildDesign(testCase);
for index = 1:numel(campaign.runs)
    overrides = campaign.runs(index).overrides;
    paths = string({overrides.path});
    verifyTrue(testCase,ismember("sources.radiation.model",paths));
    verifyTrue(testCase,ismember( ...
        "sources.radiation.force_direction_xyz",paths));
    verifyTrue(testCase,ismember( ...
        "amplitude.geometric_decay_exponent",paths));
end
end

function testFrameworkShaGuard(testCase)
required = string( ...
    testCase.TestData.config.required_simulation_framework_commit);
actual = reqml.analysis.verifyRequiredGitCommit("unused",required, ...
    ActualCommit=required);
verifyEqual(testCase,actual,lower(required));
verifyError(testCase,@() reqml.analysis.verifyRequiredGitCommit( ...
    "unused",required,ActualCommit=repmat('0',1,40)), ...
    "reqml:SimulationFrameworkCommitMismatch");
end

function testNoTrainingTest53OrHeterogeneousDependency(testCase)
files = [string(which("reqml.analysis.buildAnalyticPointForceCampaign")); ...
    string(which("reqml.analysis.verifyRequiredGitCommit"))];
content = lower(join(arrayfun(@fileread,files,UniformOutput=false),"\n"));
verifyFalse(testCase,contains(content,"test53"));
verifyFalse(testCase,contains(content,"train"));
verifyFalse(testCase,contains(content,"medium.objects"));
end

function verifyOverridesDifferOnly(testCase,a,b,allowedPaths)
verifyEqual(testCase,string({a.path}),string({b.path}));
for index = 1:numel(a)
    if ismember(string(a(index).path),allowedPaths)
        verifyNotEqual(testCase,a(index).value,b(index).value);
    else
        verifyEqual(testCase,a(index).value,b(index).value);
    end
end
end

function [campaign,design] = buildDesign(testCase)
[campaign,design] = reqml.analysis.buildAnalyticPointForceCampaign( ...
    testCase.TestData.config,string(tempname));
end
