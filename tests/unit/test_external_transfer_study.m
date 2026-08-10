function tests=test_external_transfer_study
tests=functiontests(localfunctions);
end

function testDenseAndStrideAggregation(testCase)
p=synthetic_predictions();
s=reqml.homogeneous.summarizeExternalPredictions(p, ...
    ["backend","geometry","sampling_mode"]);
verifyEqual(testCase,height(s),2);
verifyEqual(testCase,sort(s.patch_count),[2;4]);
verifyEqual(testCase,s.sws_mape(s.sampling_mode=="dense_map"),2.5,AbsTol=1e-12);
verifyEqual(testCase,s.sws_bias_percent(s.sampling_mode=="dense_map"),-.5,AbsTol=1e-12);
end

function testRoiUsesFullPatchPurity(testCase)
geometry=repmat("inclusion",4,1); material=[1;2;1;2];
purity=[1;1;.99;.8];
roi=reqml.homogeneous.classifyExternalRoi(geometry,material,purity, ...
    (1:4)',(1:4)',.0005,.0005);
verifyEqual(testCase,roi,["background_far";"inclusion_core"; ...
    "interface_band";"interface_band"]);
end

function testBilayerRoiNames(testCase)
roi=reqml.homogeneous.classifyExternalRoi(repmat("bilayer",3,1), ...
    [1;2;2],[1;1;.95],[1;2;3]',[1;2;3]',.001,.001);
verifyEqual(testCase,roi,["layer_1_core";"layer_2_core";"interface_band"]);
end

function testPortableExternalTransferConfig(testCase)
path=fullfile(testCase.TestData.repo,"configs","homogeneous", ...
    "homogeneous_q0_external_transfer_v1.json");
raw=fileread(path); config=jsondecode(raw);
verifyFalse(testCase,contains(raw,"/Users/sara"));
verifyTrue(testCase,contains(string(config.model_bundle),"${REPOSITORY_ROOT}"));
verifyTrue(testCase,all(contains(string({config.cases.sample_file}),"${SWSIM_ROOT}")));
verifyEqual(testCase,numel(config.cases),17);
end

function setupOnce(testCase)
testCase.TestData.repo=string(fileparts(fileparts(fileparts(mfilename("fullpath")))));
end

function p=synthetic_predictions
backend=repmat("eikonal",6,1); geometry=repmat("homogeneous",6,1);
sampling_mode=[repmat("dense_map",4,1);repmat("stride_matched",2,1)];
q_error=[.01;-.01;.02;-.02;.01;-.01]; cs_error_m_s=[.02;-.02;.04;-.04;.02;-.02];
cs_error_percent=[1;-2;3;-4;1;-2]; cs_absolute_error_percent=abs(cs_error_percent);
sws_valid=true(6,1);
p=table(backend,geometry,sampling_mode,q_error,cs_error_m_s, ...
    cs_error_percent,cs_absolute_error_percent,sws_valid);
end
