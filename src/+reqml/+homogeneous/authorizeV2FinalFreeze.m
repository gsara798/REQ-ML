function decision=authorizeV2FinalFreeze(gates,options)
%AUTHORIZEV2FINALFREEZE Apply the explicit v2 development-gate policy.
arguments
    gates table
    options.RequireDevelopmentGates (1,1) logical = true
    options.AllowMarginalGateWaiver (1,1) logical = false
    options.ScientificWaiverReason {mustBeTextScalar} = ""
    options.MaximumWaivedMapeExcess (1,1) double {mustBeFinite,mustBeNonnegative} = 0.1
end

required=["gate","threshold_mape","observed_mape","pass"];
if ~all(ismember(required,string(gates.Properties.VariableNames)))
    error("reqml:InvalidV2DevelopmentGates", ...
        "Development gates must contain: %s.",strjoin(required,", "));
end

failed=gates(~logical(gates.pass),:);
decision=struct("development_gates_required",options.RequireDevelopmentGates, ...
    "all_gates_passed",isempty(failed),"freeze_authorized",true, ...
    "waiver_used",false,"waived_gate_names",strings(0,1), ...
    "maximum_allowed_mape_excess",options.MaximumWaivedMapeExcess, ...
    "maximum_observed_mape_excess",0,"scientific_waiver_reason","");
if isempty(failed) || ~options.RequireDevelopmentGates
    return
end

if ~options.AllowMarginalGateWaiver
    error("reqml:V2DevelopmentGateFailed", ...
        "Cannot freeze final Q0 while required development gates fail.");
end
reason=strtrim(string(options.ScientificWaiverReason));
if strlength(reason)<20
    error("reqml:MissingV2ScientificWaiverReason", ...
        "A specific scientific waiver reason of at least 20 characters is required.");
end
excess=double(failed.observed_mape)-double(failed.threshold_mape);
maximum_excess=max(excess);
if any(~isfinite(excess)) || any(excess<0) || maximum_excess>options.MaximumWaivedMapeExcess
    error("reqml:V2DevelopmentGateNotMarginal", ...
        "Failed gate excess %.6g percentage points is not within the allowed marginal excess %.6g.", ...
        maximum_excess,options.MaximumWaivedMapeExcess);
end

decision.waiver_used=true;
decision.waived_gate_names=string(failed.gate);
decision.maximum_observed_mape_excess=maximum_excess;
decision.scientific_waiver_reason=reason;
end
