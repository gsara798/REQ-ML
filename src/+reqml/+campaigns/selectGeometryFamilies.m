function selected = selectGeometryFamilies( ...
    requests, assigned_examples, options)
%SELECTGEOMETRYFAMILIES Balance geometry families within coverage cells.
%
% Geometry is not a stopping axis. This selector only avoids repeatedly
% generating the same family when multiple families can address the same
% purity-diffusivity deficit.
%
% Historical support is measured using independent simulation runs rather
% than patch counts.

arguments
    requests (:,1) struct
    assigned_examples table

    options.GeometryVariable (1,1) string = ...
        "campaign_geometry_family"

    options.RunVariable (1,1) string = ...
        "campaign_run_id"

    options.PlannerSeed (1,1) double = 1
end

validate_options(options);

if isempty(requests)
    selected = requests;
    return
end

validate_history(assigned_examples, options);

selected = requests;

for request_index = 1:numel(requests)
    request = requests(request_index);
    validate_request(request);

    candidates = eligible_families(request);

    counts = zeros(numel(candidates), 1);

    for candidate_index = 1:numel(candidates)
        counts(candidate_index) = historical_run_count( ...
            assigned_examples, ...
            request, ...
            candidates(candidate_index), ...
            options);
    end

    minimum_count = min(counts);
    tied = find(counts == minimum_count);

    tie_index = deterministic_index( ...
        numel(tied), ...
        request_index, ...
        options.PlannerSeed);

    chosen_index = tied(tie_index);

    selected(request_index).geometry_family = ...
        candidates(chosen_index);

    selected(request_index).geometry_candidates = ...
        candidates;

    selected(request_index).geometry_historical_run_counts = ...
        counts;

    selected(request_index).geometry_selection_basis = ...
        "minimum_historical_run_count_in_coverage_cell";
end

end


function count = historical_run_count( ...
        examples, request, family, options)

if isempty(examples)
    count = 0;
    return
end

mask = ...
    double(examples.coverage_purity_bin) == ...
        double(request.purity_bin) & ...
    double(examples.coverage_diffusivity_bin) == ...
        double(request.diffusivity_bin) & ...
    logical(examples.coverage_valid) & ...
    string(examples.(options.GeometryVariable)) == family;

runs = string(examples.(options.RunVariable));
runs = runs(mask);
runs = runs(~ismissing(runs) & strlength(runs) > 0);

count = numel(unique(runs));

end


function candidates = eligible_families(request)

purity_range = double(request.purity_range);

if numel(purity_range) ~= 2 || ...
        any(~isfinite(purity_range))

    error("reqml:InvalidGeometrySelectionRequest", ...
        "purity_range must contain two finite values.");
end

% Homogeneous media can only produce materially pure patches.
if purity_range(1) >= 0.98
    candidates = [
        "homogeneous"
        "bilayer"
        "circular_inclusion"
        ];
else
    candidates = [
        "bilayer"
        "circular_inclusion"
        ];
end

end


function validate_history(examples, options)

required = [
    "coverage_purity_bin"
    "coverage_diffusivity_bin"
    "coverage_valid"
    options.GeometryVariable
    options.RunVariable
    ];

available = string(examples.Properties.VariableNames);

for variable = required.'
    if ~ismember(variable, available)
        error("reqml:MissingGeometrySelectionVariable", ...
            "Assigned examples are missing variable '%s'.", ...
            variable);
    end
end

end


function validate_request(request)

required = [
    "purity_bin"
    "purity_range"
    "diffusivity_bin"
    ];

missing = setdiff( ...
    required, ...
    string(fieldnames(request)));

if ~isempty(missing)
    error("reqml:InvalidGeometrySelectionRequest", ...
        "Condition request is missing field '%s'.", ...
        missing(1));
end

end


function validate_options(options)

if ~isfinite(options.PlannerSeed) || ...
        options.PlannerSeed < 0 || ...
        options.PlannerSeed ~= fix(options.PlannerSeed)

    error("reqml:InvalidAdaptivePlannerSeed", ...
        "PlannerSeed must be a nonnegative integer.");
end

end


function index = deterministic_index(count, ordinal, planner_seed)

index = mod( ...
    double(ordinal) + double(planner_seed) - 2, ...
    count) + 1;

end
