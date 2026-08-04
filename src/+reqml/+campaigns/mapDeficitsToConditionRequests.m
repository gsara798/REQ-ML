function requests = mapDeficitsToConditionRequests( ...
    coverage_report, options)
%MAPDEFICITSTOCONDITIONREQUESTS Translate coverage deficits into physical requests.
%
% This function does not write simulator-specific overrides. It produces an
% auditable intermediate representation describing what the next batch
% should attempt to generate.

arguments
    coverage_report (1,1) struct

    options.MaximumConditions (1,1) double = 20
    options.RealizationsPerCondition (1,1) double = 2
    options.PlannerSeed (1,1) double = 1
    options.ConditionIdPrefix (1,1) string = "adaptive"
    options.SchedulingMode (1,1) string = "legacy"
    options.MaximumExamplesPerRun (1,1) double = 2
end

validate_report(coverage_report);
validate_positive_integer( ...
    options.MaximumConditions, ...
    "MaximumConditions");
validate_positive_integer( ...
    options.RealizationsPerCondition, ...
    "RealizationsPerCondition");
validate_nonnegative_integer( ...
    options.PlannerSeed, ...
    "PlannerSeed");
validate_positive_integer( ...
    options.MaximumExamplesPerRun, ...
    "MaximumExamplesPerRun");
if ~ismember(options.SchedulingMode,["legacy","residual_deficit_aware"])
    error("reqml:InvalidAdaptivePlannerOption", ...
        "SchedulingMode must be legacy or residual_deficit_aware.");
end

condition_id_prefix = validate_condition_id_prefix( ...
    options.ConditionIdPrefix);

deficits = coverage_report.deficits;

if isempty(deficits)
    requests = empty_requests();
    return
end

request_count = min( ...
    height(deficits), ...
    options.MaximumConditions);

deficits = deficits(1:request_count, :);

purity_edges = double( ...
    coverage_report.config.purity_edges);

diffusivity_edges = double( ...
    coverage_report.config.diffusivity_edges);

sws_edges = double( ...
    coverage_report.config.sws_edges);

frequency_edges = double( ...
    coverage_report.config.frequency_edges);

template = empty_request();
requests = repmat(template, request_count, 1);

for index = 1:request_count
    sws_bin = double(deficits.sws_bin(index));
    frequency_bin = ...
        double(deficits.frequency_bin(index));

    purity_bin = double(deficits.purity_bin(index));
    diffusivity_bin = ...
        double(deficits.diffusivity_bin(index));

    target_sws_bin = bin_range( ...
        sws_edges, sws_bin);

    target_frequency_bin = bin_range( ...
        frequency_edges, frequency_bin);

    purity_range = bin_range( ...
        purity_edges, purity_bin);

    diffusivity_range = bin_range( ...
        diffusivity_edges, diffusivity_bin);

    geometry_family = choose_geometry_family( ...
        purity_range, index, options.PlannerSeed);

    nominal_angular_coverage_range = ...
        diffusivity_range;

    requests(index).condition_id = sprintf( ...
        "%s_s%02d_f%02d_p%02d_d%02d_%03d", ...
        condition_id_prefix, ...
        sws_bin, ...
        frequency_bin, ...
        purity_bin, ...
        diffusivity_bin, ...
        index);

    requests(index).priority_rank = index;
    requests(index).deficit_score = ...
        double(deficits.deficit_score(index));


    requests(index).sws_bin = sws_bin;

    requests(index).frequency_bin = ...
        frequency_bin;

    requests(index).purity_bin = purity_bin;
    requests(index).purity_range = purity_range;

    requests(index).diffusivity_bin = ...
        diffusivity_bin;
    requests(index).diffusivity_range = ...
        diffusivity_range;

    requests(index).nominal_angular_coverage_range = ...
        nominal_angular_coverage_range;

    requests(index).geometry_family = ...
        geometry_family;

    % Legacy metadata retained while old campaign plans remain readable.
    requests(index).field_regime = ...
        "continuous_dnom";

    requests(index).target_sws_range_m_s = ...
        target_sws_bin;

    requests(index).target_frequency_range_hz = ...
        target_frequency_bin;

    requests(index).realization_count = ...
        options.RealizationsPerCondition;

    requests(index).planner_seed = ...
        options.PlannerSeed;

    requests(index).source_example_deficit = ...
        double(deficits.example_deficit(index));

    requests(index).source_run_deficit = ...
        double(deficits.independent_run_deficit(index));

    requests(index).source_condition_deficit = ...
        double( ...
            deficits.independent_condition_deficit(index));

    requests(index).requested_cell_key = compose( ...
        "s%02d_f%02d_p%02d_d%02d",sws_bin,frequency_bin, ...
        purity_bin,diffusivity_bin);
    requests(index).residual_example_deficit = ...
        requests(index).source_example_deficit;
    requests(index).residual_independent_run_deficit = ...
        requests(index).source_run_deficit;
    requests(index).residual_independent_condition_deficit = ...
        requests(index).source_condition_deficit;

    if options.SchedulingMode=="residual_deficit_aware"
        requests(index) = plan_residual_action( ...
            requests(index),coverage_report.assigned_examples, ...
            options.RealizationsPerCondition,options.MaximumExamplesPerRun);
    end
end

end


function family = choose_geometry_family( ...
        purity_range, index, planner_seed)

purity_midpoint = mean(purity_range);

if purity_midpoint >= 0.98
    candidates = [
        "homogeneous"
        "circular_inclusion"
        ];

elseif purity_midpoint >= 0.90
    candidates = [
        "circular_inclusion"
        "bilayer"
        ];

else
    candidates = [
        "bilayer"
        "circular_inclusion"
        ];
end

selection = deterministic_index( ...
    numel(candidates), ...
    index, ...
    planner_seed);

family = candidates(selection);

end


function index = deterministic_index( ...
        count, ordinal, planner_seed)

index = mod( ...
    double(ordinal) + double(planner_seed) - 2, ...
    count) + 1;

end


function range = bin_range(edges, bin_index)

if bin_index < 1 || ...
        bin_index >= numel(edges)

    error("reqml:InvalidCoverageBinIndex", ...
        "Coverage bin index is outside the configured edges.");
end

range = [
    edges(bin_index)
    edges(bin_index + 1)
    ]';

end


function validate_report(report)

required = [
    "deficits"
    "config"
    ];

for name = required.'
    if ~isfield(report, name)
        error("reqml:InvalidCoverageReport", ...
            "Coverage report is missing field '%s'.", ...
            name);
    end
end

if ~istable(report.deficits)
    error("reqml:InvalidCoverageReport", ...
        "Coverage report deficits must be a table.");
end

required_config = [
    "purity_edges"
    "diffusivity_edges"
    "sws_edges"
    "frequency_edges"
    ];

for name = required_config.'
    if ~isfield(report.config, name)
        error("reqml:InvalidCoverageReport", ...
            "Coverage report config is missing field '%s'.", ...
            name);
    end
end

end


function prefix = validate_condition_id_prefix(value)

prefix = string(value);

if ~isscalar(prefix) || ...
        strlength(prefix) == 0 || ...
        isempty(regexp( ...
            char(prefix), ...
            '^[A-Za-z0-9_-]+$', ...
            'once'))

    error("reqml:InvalidAdaptiveConditionIdPrefix", ...
        ["ConditionIdPrefix must contain only letters, numbers, " ...
         "underscores, and hyphens."]);
end

end


function validate_positive_integer(value, name)

if ~isfinite(value) || ...
        value < 1 || ...
        value ~= fix(value)

    error("reqml:InvalidAdaptivePlannerOption", ...
        "%s must be a positive integer.", ...
        name);
end

end


function validate_nonnegative_integer(value, name)

if ~isfinite(value) || ...
        value < 0 || ...
        value ~= fix(value)

    error("reqml:InvalidAdaptivePlannerOption", ...
        "%s must be a nonnegative integer.", ...
        name);
end

end


function request = empty_request()

request = struct( ...
    "condition_id", "", ...
    "priority_rank", 0, ...
    "deficit_score", NaN, ...
    "sws_bin", 0, ...
    "frequency_bin", 0, ...
    "purity_bin", 0, ...
    "purity_range", [NaN, NaN], ...
    "diffusivity_bin", 0, ...
    "diffusivity_range", [NaN, NaN], ...
    "nominal_angular_coverage_range", [NaN, NaN], ...
    "geometry_family", "", ...
    "field_regime", "", ...
    "target_sws_range_m_s", [NaN, NaN], ...
    "target_frequency_range_hz", [NaN, NaN], ...
    "realization_count", 0, ...
    "planner_seed", 0, ...
    "source_example_deficit", 0, ...
    "source_run_deficit", 0, ...
    "source_condition_deficit", 0);

request.requested_cell_key = "";
request.residual_example_deficit = 0;
request.residual_independent_run_deficit = 0;
request.residual_independent_condition_deficit = 0;
request.planned_action = "new_condition";
request.planned_realization_count = 0;
request.planned_new_condition_count = 0;
request.reason_for_repeat = "";
request.expected_example_contribution = 0;
request.expected_independent_run_contribution = 0;
request.expected_independent_condition_contribution = 0;
request.realization_start_index = 1;

end


function request = plan_residual_action(request,assigned,base_realizations, ...
        examples_per_run)

existing_condition="";
next_realization=1;
names=string(assigned.Properties.VariableNames);
if all(ismember(["requested_condition_cell_key","campaign_condition_id", ...
        "campaign_realization_id"],names))
    mask=string(assigned.requested_condition_cell_key)==request.requested_cell_key;
    if ismember("center_selection_role",names)
        mask=mask & string(assigned.center_selection_role)=="analytic_target";
    end
    condition_ids=sort(unique(string(assigned.campaign_condition_id(mask))));
    if ~isempty(condition_ids)
        existing_condition=condition_ids(1);
        same=mask & string(assigned.campaign_condition_id)==existing_condition;
        next_realization=max(double(assigned.campaign_realization_id(same)))+1;
    end
end

e=request.residual_example_deficit;
r=request.residual_independent_run_deficit;
c=request.residual_independent_condition_deficit;
needs_new=c>0 || strlength(existing_condition)==0;
if needs_new
    request.planned_action="new_condition";
    if e>0 || r>0, request.planned_action="combined"; end
    request.planned_new_condition_count=1;
    request.realization_count=max(base_realizations,max(1,r));
    request.realization_start_index=1;
    request.reason_for_repeat="new physical condition required by condition deficit";
    expected_conditions=1;
else
    request.condition_id=existing_condition;
    request.planned_new_condition_count=0;
    request.realization_start_index=next_realization;
    expected_conditions=0;
    if r>0
        request.planned_action="additional_realization";
        if e>0, request.planned_action="combined"; end
        request.realization_count=max(r,ceil(e/examples_per_run));
        request.reason_for_repeat="independent-run deficit requires new realization";
    else
        request.planned_action="opportunistic_examples";
        request.realization_count=max(1,ceil(e/examples_per_run));
        request.reason_for_repeat="example-only deficit remained after prior packing";
    end
end
request.planned_realization_count=request.realization_count;
request.expected_example_contribution=min(e, ...
    request.realization_count*examples_per_run);
request.expected_independent_run_contribution=min(r,request.realization_count);
request.expected_independent_condition_contribution=min(c,expected_conditions);

end


function requests = empty_requests()

requests = repmat(empty_request(), 0, 1);

end
