function tests=test_homogeneous_cartesian_design
tests=functiontests(localfunctions);
end
function setupOnce(testCase)
root=fileparts(fileparts(fileparts(mfilename("fullpath"))));
addpath(fullfile(root,"src"));
testCase.TestData.previous_swsim_root=getenv("SWSIM_ROOT");
setenv("SWSIM_ROOT",fullfile(fileparts(root), ...
    "shear-wave-simulation-framework"));
end
function teardownOnce(testCase)
setenv("SWSIM_ROOT",testCase.TestData.previous_swsim_root);
end
function testFullCartesianCountsAndValues(testCase)
cfg=load_config(); d=reqml.homogeneous.materializeCartesianDesign(cfg);
verifyEqual(testCase,d.condition_count,240);
verifyEqual(testCase,d.run_count,720);
verifyEqual(testCase,unique(d.conditions.cs_m_s),[1;2;3;4]);
verifyEqual(testCase,unique(d.conditions.frequency_hz),[200;300;400;500;600]);
verifyEqual(testCase,unique(d.conditions.dx_m),[.00025;.0003;.0005]);
verifyEqual(testCase,sort(unique(d.conditions.field_regime)), ...
    sort(["single";"directional";"intermediate";"diffuse"]));
verifyEqual(testCase,groupcounts(d.runs.condition_id),3*ones(240,1));
end
function testFieldRegimeContract(testCase)
d=reqml.homogeneous.materializeCartesianDesign(load_config());
[~,i]=unique(d.conditions.field_regime); f=sortrows( ...
    d.conditions(i,["field_regime","direction_count", ...
    "in_plane_count","solid_angle_sr"]),"direction_count");
verifyEqual(testCase,f.direction_count,[1;4;16;32]);
verifyEqual(testCase,f.in_plane_count,[1;2;4;8]);
verifyEqual(testCase,f.solid_angle_sr,[.01;.5;pi;4*pi],AbsTol=1e-14);
end
function testSeedsAndAxesAreDeterministic(testCase)
cfg=load_config(); a=reqml.homogeneous.materializeCartesianDesign(cfg);
b=reqml.homogeneous.materializeCartesianDesign(cfg);
verifyEqual(testCase,a.runs,b.runs);
verifyEqual(testCase,numel(unique(a.runs.seed)),720);
verifyEqual(testCase,a.runs.axis_y,zeros(720,1));
verifyEqual(testCase,hypot(a.runs.axis_x,a.runs.axis_z),ones(720,1), ...
    AbsTol=1e-14);
end
function testPatchGeometryProvidesOneHundredCandidates(testCase)
for f=[200 600]
    for dx=[.00025 .0003 .0005]
        g=reqml.homogeneous.computePatchGeometry(f,dx,dx);
        verifyEqual(testCase,g.available_patch_count,100);
        verifyEqual(testCase,mod(g.patch_width_px,2),1);
        verifyGreaterThanOrEqual(testCase,g.stride_x_px,4);
        verifyLessThanOrEqual(testCase,g.linear_overlap_fraction,.5);
        count=floor((g.domain_points_x-g.patch_width_px)/g.stride_x_px)+1;
        verifyEqual(testCase,count,10);
    end
end
end
function testWritesExplicitCampaign(testCase)
folder=string(testCase.applyFixture( ...
    matlab.unittest.fixtures.TemporaryFolderFixture).Folder);
path=config_path(); r=reqml.homogeneous.writeCartesianCampaign(path, ...
    OutputDirectory=folder);
verifyTrue(testCase,isfile(r.paths.campaign_json));
j=jsondecode(fileread(r.paths.campaign_json));
verifyEqual(testCase,string(j.schema_version),"1.2");
verifyEqual(testCase,numel(j.runs),720);
verifyEqual(testCase,string(j.runs(1).condition_id), ...
    r.design.runs.condition_id(1));
verifyEqual(testCase,double(j.runs(1).realization_id),1);
end
function cfg=load_config(), cfg=jsondecode(fileread(config_path())); end
function path=config_path()
root=fileparts(fileparts(fileparts(mfilename("fullpath"))));
path=fullfile(root,"configs","homogeneous", ...
    "homogeneous_cartesian_q0_v1.json");
end
