function tests=test_select_hotspot_control_patches
tests=functiontests(localfunctions);
end

function testSelectsTopOnePercentAndMatchedControls(testCase)
n=200; example_id="e"+compose("%03d",(1:n)'); cx=(1:n)'; cz=mod((1:n)',17)+1;
cs_absolute_error_percent=(1:n)'; sws_valid=true(n,1);
p=table(example_id,cx,cz,cs_absolute_error_percent,sws_valid);
a=reqml.homogeneous.selectHotspotControlPatches(p);
b=reqml.homogeneous.selectHotspotControlPatches(p);
verifyEqual(testCase,height(a),4); verifyEqual(testCase,a,b);
verifyEqual(testCase,sort(a.cs_absolute_error_percent(a.selection_group=="hotspot")),[199;200]);
verifyTrue(testCase,all(a.cs_absolute_error_percent(a.selection_group=="control")<median(cs_absolute_error_percent)));
verifyEqual(testCase,nnz(a.selection_group=="hotspot"),nnz(a.selection_group=="control"));
end

function testRejectsMissingColumns(testCase)
verifyError(testCase,@() reqml.homogeneous.selectHotspotControlPatches(table()), ...
    "reqml:MissingHotspotPredictionVariable");
end
