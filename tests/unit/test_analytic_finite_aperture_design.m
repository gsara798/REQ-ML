function tests = test_analytic_finite_aperture_design
%TEST_ANALYTIC_FINITE_APERTURE_DESIGN Validate the fixed 12-case design.
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
root = fileparts(fileparts(fileparts(mfilename("fullpath"))));
addpath(fullfile(root,"src"));
file = fullfile(root,"configs","validation", ...
    "reqml_analytic_finite_aperture_q0_v1.json");
testCase.TestData.config = jsondecode(fileread(file));
end

function testExactlyTwelveUniqueCases(testCase)
[campaign,design] = buildDesign(testCase);
verifyEqual(testCase,height(design),12);
verifyEqual(testCase,numel(campaign.runs),12);
verifyEqual(testCase,numel(unique(design.design_id)),12);
verifyEqual(testCase,unique(design.cs_true_m_s),[2;3]);
verifyEqual(testCase,sort(unique(design.aperture_span_m)),[0;.004;.008]);
end

function testForcesAperturesAndFixedContract(testCase)
[~,design] = buildDesign(testCase);
sourceX = design.force_label=="sourcex";
sourceZ = design.force_label=="sourcez";
verifyEqual(testCase,[design.force_x(sourceX),design.force_y(sourceX), ...
    design.force_z(sourceX)],repmat([1 0 0],6,1));
verifyEqual(testCase,[design.force_x(sourceZ),design.force_y(sourceZ), ...
    design.force_z(sourceZ)],repmat([0 0 1],6,1));
verifyEqual(testCase,sort(unique(design.aperture_node_count)),[1;9;17]);
verifyEqual(testCase,unique(design.geometric_decay_exponent),0);
verifyEqual(testCase,unique(design.aperture_node_spacing_m),0.0005);
verifyEqual(testCase,testCase.TestData.config.M,2);
verifyEqual(testCase,testCase.TestData.config.step_pixels,1);
verifyEqual(testCase,string( ...
    testCase.TestData.config.required_simulation_framework_commit), ...
    "6ba498c0690f96c112516632d34c336b7a67d6b3");
end

function testMatchedAperturesDifferOnlyByAperture(testCase)
[campaign,design] = buildDesign(testCase);
for cs = [2 3]
    for force = ["sourcex","sourcez"]
        indices = find(design.cs_true_m_s==cs & design.force_label==force);
        point = indices(design.aperture_span_m(indices)==0);
        for candidate = indices(design.aperture_span_m(indices)>0)'
            verifyOverridesDifferOnly(testCase, ...
                campaign.runs(point).overrides, ...
                campaign.runs(candidate).overrides, ...
                ["scenario","sources.aperture.model", ...
                 "sources.aperture.span_m"]);
        end
    end
end
end

function testMatchedForcesDifferOnlyByForce(testCase)
[campaign,design] = buildDesign(testCase);
for cs = [2 3]
    for span = [0 .004 .008]
        zIndex = find(design.cs_true_m_s==cs & ...
            design.aperture_span_m==span & design.force_label=="sourcez");
        xIndex = find(design.cs_true_m_s==cs & ...
            design.aperture_span_m==span & design.force_label=="sourcex");
        verifyOverridesDifferOnly(testCase,campaign.runs(zIndex).overrides, ...
            campaign.runs(xIndex).overrides, ...
            ["scenario","sources.radiation.force_direction_xyz"]);
    end
end
end

function testCampaignContainsApertureOverrides(testCase)
[campaign,design] = buildDesign(testCase);
for index = 1:numel(campaign.runs)
    paths = string({campaign.runs(index).overrides.path});
    verifyTrue(testCase,ismember("sources.aperture.model",paths));
    verifyTrue(testCase,ismember("sources.aperture.span_m",paths));
    verifyTrue(testCase,ismember("sources.aperture.axis_xyz",paths));
    verifyTrue(testCase,ismember("sources.aperture.node_spacing_m",paths));
    verifyEqual(testCase,design.seed(index), ...
        double(testCase.TestData.config.base_seed)+ ...
        double(design.cs_true_m_s(index)==3));
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

function testNoTrainingOrTest53Dependency(testCase)
file = string(which( ...
    "reqml.analysis.buildAnalyticFiniteApertureCampaign"));
content = lower(fileread(file));
verifyFalse(testCase,contains(content,"test53"));
verifyFalse(testCase,contains(content,"train"));
verifyFalse(testCase,contains(content,"medium.objects"));

root = fileparts(fileparts(fileparts(mfilename("fullpath"))));
runner = lower(fileread(fullfile(root,"scripts","diagnostics", ...
    "run_analytic_finite_aperture_q0_v1.m")));
verifyFalse(testCase,contains(runner,"test53"));
verifyFalse(testCase,contains(runner,"reqml.training"));
verifyFalse(testCase,contains(runner,"build_dataset"));
verifyFalse(testCase,contains(runner,"fitrensemble"));
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
[campaign,design] = reqml.analysis.buildAnalyticFiniteApertureCampaign( ...
    testCase.TestData.config,string(tempname));
end
