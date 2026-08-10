function tests=test_homogeneous_patch_quota
tests=functiontests(localfunctions);
end
function setupOnce(~)
root=fileparts(fileparts(fileparts(mfilename("fullpath"))));
addpath(fullfile(root,"src"));
end
function testSelectsExactQuotaDeterministically(testCase)
candidates=fixture_candidates(150);
[a,da]=reqml.homogeneous.selectPatchQuota(candidates,100,991);
[b,db]=reqml.homogeneous.selectPatchQuota(candidates,100,991);
verifyEqual(testCase,a,b);
verifyEqual(testCase,da,db);
verifyEqual(testCase,height(a),100);
verifyEqual(testCase,numel(unique(a.example_id)),100);
verifyEqual(testCase,sort(a.quota_selection_rank),(1:100)');
end
function testDifferentSeedChangesSubset(testCase)
candidates=fixture_candidates(150);
a=reqml.homogeneous.selectPatchQuota(candidates,100,991);
b=reqml.homogeneous.selectPatchQuota(candidates,100,992);
verifyNotEqual(testCase,sort(a.example_id),sort(b.example_id));
end
function testRetainsAllAndReportsDeficit(testCase)
candidates=fixture_candidates(73);
[selected,d]=reqml.homogeneous.selectPatchQuota(candidates,100,991);
verifyEqual(testCase,height(selected),73);
verifyEqual(testCase,d.deficit_patch_count,27);
verifyFalse(testCase,d.complete);
verifyEqual(testCase,selected.example_id,candidates.example_id);
end
function testRejectsDuplicateCandidateIds(testCase)
candidates=fixture_candidates(5); candidates.example_id(5)=candidates.example_id(1);
verifyError(testCase,@() reqml.homogeneous.selectPatchQuota( ...
    candidates,3,10),"reqml:DuplicatePatchQuotaCandidate");
end
function candidates=fixture_candidates(n)
candidates=table(compose("example_%04d",(1:n)'),(1:n)', ...
    VariableNames=["example_id","value"]);
end
