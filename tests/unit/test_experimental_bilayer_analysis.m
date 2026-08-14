function tests=test_experimental_bilayer_analysis
tests=functiontests(localfunctions);
end
function setupOnce(~)
root=fileparts(fileparts(fileparts(mfilename('fullpath')))); addpath(fullfile(root,'src'));
end
function testExactPurityAndDistance(testCase)
data=fixture(); cs=2*ones(3,2);
t=reqml.benchmarks.experimentalBilayer.buildPatchTable( ...
    "bilayer","REQ",cs,[3 5],[3;4;5],3,data,InterfaceZM=.003);
verifyEqual(testCase,t.distance_to_interface_mm,[-1;0;1;-1;0;1]);
verifyEqual(testCase,t.window_purity,[2/3;2/3;1;2/3;2/3;1],AbsTol=1e-12);
verifyEqual(testCase,t.center_material_id,uint16([1;2;2;1;2;2]));
end
function testCommonSupportAndSummary(testCase)
data=fixture(); a=reqml.benchmarks.experimentalBilayer.buildPatchTable( ...
    "h","A",2*ones(2),[3 5],[3;5],3,data);
b=a; b.estimator(:)="B"; b=b(1:3,:); rows=[a;b];
rows=reqml.benchmarks.experimentalBilayer.markCommonSupport(rows);
verifyEqual(testCase,nnz(rows.common_support),6);
s=reqml.benchmarks.experimentalBilayer.summarizePatches(rows, ...
    ["condition","estimator","center_material_id"]);
verifyEqual(testCase,sum(s.N),6);
verifyEqual(testCase,sort(s.MAPE_percent),[0;0;100/3;100/3],AbsTol=1e-12);
end
function testCommonSupportRequiresValidEstimateFromEveryEstimator(testCase)
data=fixture(); a=reqml.benchmarks.experimentalBilayer.buildPatchTable( ...
    "h","A",2*ones(2),[3 5],[3;5],3,data);
b=a; b.estimator(:)="B"; b.valid(1)=false;
rows=reqml.benchmarks.experimentalBilayer.markCommonSupport([a;b]);
verifyFalse(testCase,any(rows.common_support(rows.cx==3&rows.cz==3)));
verifyEqual(testCase,nnz(rows.common_support),6);
end
function data=fixture()
data=struct(); data.has_truth=true; data.axes=struct('x_m',(0:6)'*.001,'z_m',(0:6)'*.001);
material=ones(7,7,'uint16'); material(4:end,:)=2;
cs=2*ones(7); cs(material==2)=3;
data.truth=struct('material_id_zx',material,'cs_m_s_zx',cs);
end
