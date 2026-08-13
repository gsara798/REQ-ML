function tests=test_homogeneous_external_q0_config
tests=functiontests(localfunctions);
end
function setupOnce(testCase)
root=fileparts(fileparts(fileparts(mfilename("fullpath"))));
addpath(fullfile(root,"src"));
testCase.TestData.root=root;
end
function testControlledCasesAreIsolatedAndMatched(testCase)
path=fullfile(testCase.TestData.root,"archive","legacy_v1", ...
    "configs","homogeneous", ...
    "homogeneous_q0_external_controls_v1.json");
config=jsondecode(fileread(path));
verifyEqual(testCase,string(config.evaluation_id), ...
    "homogeneous_q0_external_controls_v1");
verifyEqual(testCase,numel(config.cases),4);
verifyEqual(testCase,sort(string({config.cases.backend})), ...
    sort(["projected3d_eikonal","projected3d_eikonal","kwave_3d","kwave_3d"]));
verifyEqual(testCase,double(config.feature_config.M),2);
verifyEqual(testCase,double(config.feature_config.cs_guess_m_s),3);
verifyFalse(testCase,contains(string(config.output_root), ...
    "scientific_5d_training"));
raw_paths=string({config.cases.sample_file});
verifyTrue(testCase,all(startsWith(raw_paths,"${SWSIM_ROOT}/")));
verifyFalse(testCase,any(contains(raw_paths,"/Users/")));
variables=struct("SWSIM_ROOT",fullfile(fileparts(testCase.TestData.root), ...
    "shear-wave-simulation-framework"));
resolved=arrayfun(@(p) reqml.config.resolveWorkspacePath(p, ...
    RepositoryRoot=testCase.TestData.root,Variables=variables),raw_paths);
verifyTrue(testCase,all(isfile(resolved)));
end
