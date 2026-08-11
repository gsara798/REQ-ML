function tests=test_authorize_v2_final_freeze
tests=functiontests(localfunctions);
end

function testAcceptsPassingGatesWithoutWaiver(testCase)
gates=make_gates([2.9;3.8],[3;4]);
decision=reqml.homogeneous.authorizeV2FinalFreeze(gates);
verifyTrue(testCase,decision.freeze_authorized);
verifyTrue(testCase,decision.all_gates_passed);
verifyFalse(testCase,decision.waiver_used);
end

function testRejectsFailedGateByDefault(testCase)
gates=make_gates([3.044;2.8],[3;4]);
verifyError(testCase,@() reqml.homogeneous.authorizeV2FinalFreeze(gates), ...
    "reqml:V2DevelopmentGateFailed");
end

function testRecordsSpecificMarginalWaiver(testCase)
gates=make_gates([3.044;2.8],[3;4]);
reason="Overall SWS MAPE exceeds the approximate target by only 0.044 points with low bias.";
decision=reqml.homogeneous.authorizeV2FinalFreeze(gates, ...
    AllowMarginalGateWaiver=true,ScientificWaiverReason=reason);
verifyTrue(testCase,decision.freeze_authorized);
verifyTrue(testCase,decision.waiver_used);
verifyEqual(testCase,decision.waived_gate_names,"alternating_sws");
verifyEqual(testCase,decision.maximum_observed_mape_excess,0.044,AbsTol=1e-12);
verifyEqual(testCase,decision.scientific_waiver_reason,reason);
end

function testRejectsUndocumentedWaiver(testCase)
gates=make_gates([3.044;2.8],[3;4]);
verifyError(testCase,@() reqml.homogeneous.authorizeV2FinalFreeze(gates, ...
    AllowMarginalGateWaiver=true,ScientificWaiverReason="marginal"), ...
    "reqml:MissingV2ScientificWaiverReason");
end

function testRejectsNonMarginalFailure(testCase)
gates=make_gates([3.2;2.8],[3;4]);
verifyError(testCase,@() reqml.homogeneous.authorizeV2FinalFreeze(gates, ...
    AllowMarginalGateWaiver=true, ...
    ScientificWaiverReason="The observed result has been reviewed scientifically."), ...
    "reqml:V2DevelopmentGateNotMarginal");
end

function gates=make_gates(observed,threshold)
gate=["alternating_sws";"alternating_angular"];
observed_mape=observed; threshold_mape=threshold;
pass=observed_mape<=threshold_mape;
observed_bias_percent=zeros(2,1);
gates=table(gate,threshold_mape,observed_mape,observed_bias_percent,pass);
end
