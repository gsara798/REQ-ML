function tests=test_workspace_path_resolution
tests=functiontests(localfunctions);
end
function setupOnce(~)
root=fileparts(fileparts(fileparts(mfilename("fullpath"))));
addpath(fullfile(root,"src"));
end
function testResolvesRepositoryAndExplicitWorkspaceRoot(testCase)
variables=struct("SWSIM_ROOT","/portable/simulation-root");
actual=reqml.config.resolveWorkspacePath( ...
    "${SWSIM_ROOT}/outputs/campaigns", ...
    RepositoryRoot="/portable/reqml",Variables=variables);
verifyEqual(testCase,actual,"/portable/simulation-root/outputs/campaigns");
repository=reqml.config.resolveWorkspacePath( ...
    "${REPOSITORY_ROOT}/outputs/test", ...
    RepositoryRoot="/portable/reqml",Variables=variables);
verifyEqual(testCase,repository,"/portable/reqml/outputs/test");
end
function testMissingWorkspaceRootFailsClearly(testCase)
previous=getenv("REQML_TEST_MISSING_ROOT");
cleanup=onCleanup(@() setenv("REQML_TEST_MISSING_ROOT",previous));
setenv("REQML_TEST_MISSING_ROOT","");
verifyError(testCase,@() reqml.config.resolveWorkspacePath( ...
    "${REQML_TEST_MISSING_ROOT}/sample.mat"), ...
    "reqml:MissingWorkspaceRoot");
end
