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
    purity_bin = double(deficits.purity_bin(index));
    diffusivity_bin = ...
        double(deficits.diffusivity_bin(index));

    purity_range = bin_range( ...
        purity_edges, purity_bin);

    diffusivity_range = bin_range( ...
        diffusivity_edges, diffusivity_bin);

    geometry_family = choose_geometry_family( ...
        purity_range, index, options.PlannerSeed);

    field_regime = choose_field_regime( ...
        diffusivity_range);

    target_sws_bin = choose_missing_diversity_bin( ...
        deficits.sws_bin_deficit(index), ...
        sws_edges, ...
        index, ...
        options.PlannerSeed);

    target_frequency_bin = choose_missing_diversity_bin( ...
        deficits.frequency_bin_deficit(index), ...
        frequency_edges, ...
        index + 1000, ...
        options.PlannerSeed);

    requests(index).condition_id = sprintf( ...
        "adaptive_p%02d_d%02d_%03d", ...
        purity_bin, ...
        diffusivity_bin, ...
        index);

    requests(index).priority_rank = index;
    requests(index).deficit_score = ...
        double(deficits.deficit_score(index));

    requests(index).purity_bin = purity_bin;
    requests(index).purity_range = purity_range;

    requests(index).diffusivity_bin = ...
        diffusivity_bin;
    requests(index).diffusivity_range = ...
        diffusivity_range;

    requests(index).geometry_family = ...
        geometry_family;

    requests(index).field_regime = ...
        field_regime;

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


function regime = choose_field_regime(diffusivity_range)

midpoint = mean(diffusivity_range);

if midpoint < 0.33
    regime = "directional";
elseif midpoint < 0.67
    regime = "intermediate";
else
    regime = "broad";
end

end


function selected_range = choose_missing_diversity_bin( ...
        deficit, edges, index, planner_seed)

bin_count = numel(edges) - 1;

if deficit <= 0
    selected_range = [NaN, NaN];
    return
end

selection = deterministic_index( ...
    bin_count, ...
    index, ...
    planner_seed);

selected_range = bin_range(edges, selection);

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
    "purity_bin", 0, ...
    "purity_range", [NaN, NaN], ...
    "diffusivity_bin", 0, ...
    "diffusivity_range", [NaN, NaN], ...
    "geometry_family", "", ...
    "field_regime", "", ...
    "target_sws_range_m_s", [NaN, NaN], ...
    "target_frequency_range_hz", [NaN, NaN], ...
    "realization_count", 0, ...
    "planner_seed", 0, ...
    "source_example_deficit", 0, ...
    "source_run_deficit", 0, ...
    "source_condition_deficit", 0);

end


function requests = empty_requests()

requests = repmat(empty_request(), 0, 1);

end
