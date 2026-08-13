function result = selectDeficitAwareCenters( ...
    truth, win_size, pre_iteration_state, analytic_target, options)
%SELECTDEFICITAWARECENTERS Preserve an analytic target and fill deficits.
%
% Selection is deterministic and read-only with respect to coverage state.
% Every candidate is classified from the actual truth patch. Multiple
% selected centers remain examples from one run and one condition.

arguments
    truth (1,1) struct
    win_size (1,1) double {mustBeInteger, mustBePositive}
    pre_iteration_state table
    analytic_target (1,1) struct

    options.PurityEdges (1,:) double
    options.DiffusivityEdges (1,:) double
    options.SwsEdges (1,:) double
    options.FrequencyEdges (1,:) double
    options.FrequencyHz (1,1) double {mustBeFinite}
    options.Dnom (1,1) double {mustBeFinite}

    options.GridSpacingM (1,2) double = ...
        [0.0005 0.0005]

    options.DiscretizationPairsM (:,2) double = ...
        [0.0005 0.0005]

    options.DiscretizationTolerance (1,1) double = 1e-12

    options.CandidateStepPixels (1,1) double = 2
    options.MaximumCentersPerRun (1,1) double = 12
    options.MaximumCentersPerCellPerRun (1,1) double = 2
    options.MinimumCenterSeparationFraction (1,1) double = 0.75
    options.SeparationPolicy (1,1) string = "uniform"
    options.AnalyticToOpportunisticSeparationFraction (1,1) double = 0.25
    options.DifferentCellSeparationFraction (1,1) double = 0.25
    options.SameCellSeparationFraction (1,1) double = 0.50
    options.MinimumValidFraction (1,1) double = 1
    options.RealizationsPerCondition (1,1) double = 2
    options.DeterministicSeed (1,1) double = 1
    options.RunId (1,1) string = ""
    options.ConditionId (1,1) string = ""
    options.XCoordinatesM (:,1) double = zeros(0,1)
    options.ZCoordinatesM (:,1) double = zeros(0,1)
    options.InterfaceOrientation (1,1) string = "x"
    options.InterfacePositionM (1,1) double = NaN
end

validate_inputs(truth, win_size, pre_iteration_state, analytic_target, options);

half_win = floor(win_size / 2);
[nz, nx] = size(truth.material_id_zx);
step = round(options.CandidateStepPixels);
minimum_distance = options.MinimumCenterSeparationFraction * win_size;

if isempty(options.XCoordinatesM)
    x_m = (0:nx-1)' * 1;
else
    x_m = options.XCoordinatesM;
end
if isempty(options.ZCoordinatesM)
    z_m = (0:nz-1)' * 1;
else
    z_m = options.ZCoordinatesM;
end

[grid_x, grid_z] = meshgrid(1:step:nx, 1:step:nz);
candidate_xy = [grid_x(:), grid_z(:)];
target_xy = double(analytic_target.center_indices_xz(:))';
candidate_xy = [target_xy; candidate_xy];
candidate_xy = unique(candidate_xy, "rows", "stable");

rejections = empty_rejections(options.RunId, options.ConditionId);
rows = repmat(empty_candidate(), 0, 1);

for index = 1:size(candidate_xy, 1)
    cx = candidate_xy(index,1);
    cz = candidate_xy(index,2);
    is_target = cx == target_xy(1) && cz == target_xy(2);

    if cx-half_win < 1 || cx+half_win > nx || ...
            cz-half_win < 1 || cz+half_win > nz
        rejections.patch_outside_domain = ...
            rejections.patch_outside_domain + 1;
        if is_target
            error("reqml:AnalyticTargetPatchOutsideDomain", ...
                "Analytic target center [%d,%d] has invalid patch support.", ...
                cx, cz);
        end
        continue
    end

    x_idx = (cx-half_win):(cx+half_win);
    z_idx = (cz-half_win):(cz+half_win);
    valid_patch = logical(truth.valid_mask_zx(z_idx,x_idx));
    valid_fraction = mean(valid_patch, "all");
    if valid_fraction < options.MinimumValidFraction
        rejections.insufficient_valid_fraction = ...
            rejections.insufficient_valid_fraction + 1;
        if is_target
            error("reqml:AnalyticTargetInsufficientValidFraction", ...
                "Analytic target valid fraction is %g, below %g.", ...
                valid_fraction, options.MinimumValidFraction);
        end
        continue
    end

    center_sws = double(truth.cs_m_s_zx(cz,cx));
    if ~isfinite(center_sws) || center_sws <= 0
        rejections.invalid_truth_value = rejections.invalid_truth_value + 1;
        if is_target
            error("reqml:AnalyticTargetInvalidTruth", ...
                "Analytic target center has invalid SWS truth.");
        end
        continue
    end

    purity = reqml.datasets.computeMaterialPatchPurity( ...
        truth.material_id_zx(z_idx,x_idx), valid_patch);
    bins = resolve_bins(center_sws, purity, options);
    if ~bins.valid
        rejections.outside_coverage_grid = ...
            rejections.outside_coverage_grid + 1;
        if ~is_target
            continue
        end
    end

    candidate = empty_candidate();
    candidate.cx = cx;
    candidate.cz = cz;
    candidate.center_x_m = x_m(cx);
    candidate.center_z_m = z_m(cz);
    candidate.achieved_local_sws_m_s = center_sws;
    candidate.achieved_purity = purity;
    candidate.achieved_cell_key = bins.cell_key;
    candidate.achieved_sws_bin = bins.sws_bin;
    candidate.achieved_frequency_bin = bins.frequency_bin;
    candidate.achieved_purity_bin = bins.purity_bin;
    candidate.achieved_dnom_bin = bins.dnom_bin;
    candidate.achieved_discretization_bin = ...
        bins.discretization_bin;
    candidate.frequency_hz = options.FrequencyHz;
    candidate.nominal_angular_coverage = options.Dnom;
    candidate.coverage_valid = bins.valid;
    candidate.is_analytic_target = is_target;
    candidate.tie_breaker = deterministic_key(cx, cz, options.DeterministicSeed);
    candidate.distance_to_interface_m = distance_to_interface( ...
        candidate.center_x_m, candidate.center_z_m, options);
    rows(end+1,1) = candidate; %#ok<AGROW>
end

if isempty(rows) || ~rows(1).is_analytic_target
    error("reqml:AnalyticTargetCenterNotEvaluated", ...
        "The analytic target center could not be evaluated.");
end

candidates = struct2table(rows);
selected_indices = 1;
selected_cell_counts = containers.Map("KeyType","char","ValueType","double");
if candidates.coverage_valid(1)
    selected_cell_counts(char(candidates.achieved_cell_key(1))) = 1;
end

while numel(selected_indices) < options.MaximumCentersPerRun
    best_index = 0;
    best_score = [];

    for index = 2:height(candidates)
        if ismember(index, selected_indices)
            rejections.duplicate_center = rejections.duplicate_center + 1;
            continue
        end

        key = candidates.achieved_cell_key(index);
        state_index = find(pre_iteration_state.cell_key == key, 1);
        if isempty(state_index) || ~candidates.coverage_valid(index)
            rejections.outside_coverage_grid = ...
                rejections.outside_coverage_grid + 1;
            continue
        end
        state = pre_iteration_state(state_index,:);
        if logical(state.coverage_complete)
            rejections.cell_already_complete = ...
                rejections.cell_already_complete + 1;
            continue
        end

        count = 0;
        if isKey(selected_cell_counts, char(key))
            count = selected_cell_counts(char(key));
        end
        useful_quota = useful_cell_quota(state, ...
            options.MaximumCentersPerCellPerRun, ...
            options.RealizationsPerCondition);
        if count >= useful_quota
            rejections.per_cell_quota_reached = ...
                rejections.per_cell_quota_reached + 1;
            continue
        end

        selected_candidates = candidates(selected_indices,:);
        [distance,separation_satisfied] = evaluate_separation( ...
            candidates(index,:),selected_candidates,win_size,options);
        if ~separation_satisfied
            rejections.insufficient_spatial_separation = ...
                rejections.insufficient_spatial_separation + 1;
            continue
        end

        score = [ ...
            double(state.independent_run_deficit), ...
            double(state.independent_condition_deficit), ...
            double(state.example_deficit), ...
            double(state.deficit_score), ...
            double(state.example_count == 0), ...
            distance, ...
            -double(candidates.tie_breaker(index))];
        if isempty(best_score) || lexicographically_greater(score, best_score)
            best_score = score;
            best_index = index;
        end
    end

    if best_index == 0
        rejections.no_remaining_deficit = ...
            rejections.no_remaining_deficit + 1;
        break
    end

    selected_indices(end+1,1) = best_index; %#ok<AGROW>
    key = char(candidates.achieved_cell_key(best_index));
    if isKey(selected_cell_counts, key)
        selected_cell_counts(key) = selected_cell_counts(key) + 1;
    else
        selected_cell_counts(key) = 1;
    end
end

if numel(selected_indices) >= options.MaximumCentersPerRun && ...
        height(candidates) > numel(selected_indices)
    rejections.per_run_quota_reached = ...
        height(candidates) - numel(selected_indices);
end

selection = candidates(selected_indices,:);
selection.center_selection_role = repmat( ...
    "opportunistic_deficit_fill", height(selection), 1);
selection.center_selection_role(1) = "analytic_target";
selection.center_rank = (1:height(selection))';
selection.requested_condition_cell_key = repmat( ...
    string(analytic_target.requested_cell_key), height(selection), 1);
selection.selected_for_requested_cell = ...
    selection.achieved_cell_key == string(analytic_target.requested_cell_key);
selection.selected_for_opportunistic_cell = ...
    selection.center_selection_role == "opportunistic_deficit_fill";
selection.predicted_discrete_purity = repmat(NaN, height(selection), 1);
selection.predicted_discrete_purity(1) = ...
    double(analytic_target.predicted_discrete_purity);
selection.target_cell_mismatch = false(height(selection),1);
selection.target_cell_mismatch(1) = ...
    ~selection.selected_for_requested_cell(1);
rejections.target_cell_mismatch = double(selection.target_cell_mismatch(1));

metadata = attach_state_metadata(selection, pre_iteration_state);
selection = [selection metadata];
selection.distance_to_nearest_selected_center_pixels = zeros(height(selection),1);
selection.distance_to_nearest_selected_center_window_fraction = ...
    zeros(height(selection),1);
for index = 2:height(selection)
    distance = nearest_distance(selection(index,:), selection(1:index-1,:));
    selection.distance_to_nearest_selected_center_pixels(index) = distance;
    selection.distance_to_nearest_selected_center_window_fraction(index) = ...
        distance / win_size;
end
selection.selection_priority = compose( ...
    "run=%d;condition=%d;example=%d;score=%.6g", ...
    selection.pre_iteration_independent_run_deficit, ...
    selection.pre_iteration_independent_condition_deficit, ...
    selection.pre_iteration_example_deficit, ...
    selection.pre_iteration_deficit_score);

result = struct();
result.centers = selection;
result.rejection_counts = struct2table(rejections);
result.minimum_center_separation_pixels = minimum_distance;
result.separation_policy = options.SeparationPolicy;
result.relationship_separation_pixels = struct( ...
    "analytic_to_opportunistic", ...
        options.AnalyticToOpportunisticSeparationFraction*win_size, ...
    "different_cell",options.DifferentCellSeparationFraction*win_size, ...
    "same_cell",options.SameCellSeparationFraction*win_size);
result.analytic_target_matches_requested_cell = ...
    ~selection.target_cell_mismatch(1);

end


function bins = resolve_bins(sws, purity, options)

s = double(discretize( ...
    sws, ...
    options.SwsEdges));

f = double(discretize( ...
    options.FrequencyHz, ...
    options.FrequencyEdges));

p = double(discretize( ...
    purity, ...
    options.PurityEdges));

d = double(discretize( ...
    options.Dnom, ...
    options.DiffusivityEdges));

g = resolve_discretization_bin( ...
    options.GridSpacingM, ...
    options.DiscretizationPairsM, ...
    options.DiscretizationTolerance);

bins.valid = ...
    all(isfinite([s f p d g])) && ...
    all([s f p d g] > 0);

bins.sws_bin = s;
bins.frequency_bin = f;
bins.purity_bin = p;
bins.dnom_bin = d;
bins.discretization_bin = g;

if bins.valid
    bins.cell_key = compose( ...
        "s%02d_f%02d_p%02d_d%02d_g%02d", ...
        s, f, p, d, g);
else
    bins.cell_key = "out_of_range";
end

end


function bin = resolve_discretization_bin( ...
        spacing_m, pairs_m, tolerance)

spacing_m = double(spacing_m(:))';
pairs_m = double(pairs_m);

distance = max( ...
    abs(pairs_m - spacing_m), ...
    [], ...
    2);

matches = find(distance <= tolerance);

if numel(matches) == 1
    bin = double(matches);
else
    bin = NaN;
end

end

function quota = useful_cell_quota(state, maximum, realizations_per_condition)
example_quota = ceil( ...
    double(state.example_deficit) / realizations_per_condition);
needed = max([example_quota, ...
    double(state.independent_run_deficit > 0), ...
    double(state.independent_condition_deficit > 0)]);
quota = min(maximum, max(1, needed));
end

function metadata = attach_state_metadata(selection, state)
n = height(selection);
names = ["example_count","independent_run_count", ...
    "independent_condition_count","example_deficit", ...
    "independent_run_deficit","independent_condition_deficit", ...
    "deficit_score"];
metadata = table();
for name = names
    values = nan(n,1);
    for i = 1:n
        j = find(state.cell_key == selection.achieved_cell_key(i),1);
        if ~isempty(j), values(i) = double(state.(name)(j)); end
    end
    metadata.("pre_iteration_" + name) = values;
end
end

function value = nearest_distance(row, selected)
value = min(hypot(double(selected.cx)-double(row.cx), ...
    double(selected.cz)-double(row.cz)));
end

function [nearest,satisfied] = evaluate_separation(row,selected,win,options)
distances=hypot(double(selected.cx)-double(row.cx), ...
    double(selected.cz)-double(row.cz));
nearest=min(distances);
if options.SeparationPolicy=="uniform"
    required=repmat(options.MinimumCenterSeparationFraction*win, ...
        height(selected),1);
elseif options.SeparationPolicy=="relationship_aware"
    required=zeros(height(selected),1);
    required(1)=options.AnalyticToOpportunisticSeparationFraction*win;
    for i=2:height(selected)
        if selected.achieved_cell_key(i)==row.achieved_cell_key
            required(i)=options.SameCellSeparationFraction*win;
        else
            required(i)=options.DifferentCellSeparationFraction*win;
        end
    end
else
    error("reqml:InvalidCenterSeparationPolicy", ...
        "Unsupported center separation policy '%s'.",options.SeparationPolicy);
end
satisfied=all(distances>=required);
end

function tf = lexicographically_greater(a,b)
k = find(a ~= b,1);
tf = ~isempty(k) && a(k) > b(k);
end

function key = deterministic_key(cx,cz,seed)
key = mod(uint64(cx)*73856093 + uint64(cz)*19349663 + ...
    uint64(max(0,round(seed)))*83492791, uint64(2^31-1));
end

function distance = distance_to_interface(x,z,options)
if ~isfinite(options.InterfacePositionM)
    distance = NaN;
elseif lower(options.InterfaceOrientation) == "x"
    distance = x-options.InterfacePositionM;
else
    distance = z-options.InterfacePositionM;
end
end

function candidate = empty_candidate()
candidate = struct("cx",NaN,"cz",NaN,"center_x_m",NaN, ...
    "center_z_m",NaN,"distance_to_interface_m",NaN, ...
    "achieved_local_sws_m_s",NaN,"achieved_purity",NaN, ...
    "achieved_cell_key","","achieved_sws_bin",NaN, ...
    "achieved_frequency_bin",NaN,"achieved_purity_bin",NaN, ...
    "achieved_dnom_bin",NaN, ...
    "achieved_discretization_bin",NaN, ...
    "frequency_hz",NaN, ...
    "nominal_angular_coverage",NaN, ...
    "coverage_valid",false,"is_analytic_target",false, ...
    "tie_breaker",uint64(0));
end

function value = empty_rejections(run_id,condition_id)
value = struct("run_id",run_id,"condition_id",condition_id, ...
    "patch_outside_domain",0,"insufficient_valid_fraction",0, ...
    "outside_coverage_grid",0,"cell_already_complete",0, ...
    "no_remaining_deficit",0,"per_cell_quota_reached",0, ...
    "per_run_quota_reached",0,"insufficient_spatial_separation",0, ...
    "duplicate_center",0,"target_cell_mismatch",0, ...
    "invalid_truth_value",0);
end

function validate_inputs(truth,win,state,target,options)
required_truth = ["material_id_zx","cs_m_s_zx","valid_mask_zx"];
if any(~isfield(truth,required_truth))
    error("reqml:InvalidDeficitAwareTruth", "Truth maps are incomplete.");
end
required_state = ["cell_key","coverage_complete","example_count", ...
    "independent_run_count","independent_condition_count", ...
    "required_example_count","required_independent_run_count", ...
    "required_independent_condition_count","example_deficit", ...
    "independent_run_deficit","independent_condition_deficit","deficit_score"];
missing = setdiff(required_state,string(state.Properties.VariableNames));
if ~isempty(missing)
    error("reqml:MissingPreIterationDeficitData", ...
        "Pre-iteration deficit state is missing: %s",strjoin(missing,", "));
end
if ~isfield(target,"center_indices_xz") || ...
        ~isfield(target,"requested_cell_key") || ...
        ~isfield(target,"predicted_discrete_purity")
    error("reqml:InvalidAnalyticTargetMetadata", ...
        "Analytic target metadata is incomplete.");
end
if mod(win,2)==0, error("reqml:EvenDeficitAwareWindow","win_size must be odd."); end
if ~ismember(lower(options.InterfaceOrientation),["x","z"])
    error("reqml:UnsupportedBilayerInterfaceOrientation", ...
        "InterfaceOrientation must be 'x' or 'z'.");
end
if options.MaximumCentersPerRun < 1 || options.MaximumCentersPerCellPerRun < 1
    error("reqml:InvalidDeficitAwareCenterQuota","Center quotas must be positive.");
end
fractions=[options.MinimumCenterSeparationFraction, ...
    options.AnalyticToOpportunisticSeparationFraction, ...
    options.DifferentCellSeparationFraction, ...
    options.SameCellSeparationFraction];
if any(~isfinite(fractions)) || any(fractions<0) || ...
        ~ismember(options.SeparationPolicy,["uniform","relationship_aware"])
    error("reqml:InvalidCenterSeparationPolicy", ...
        "Center separation policy or fractions are invalid.");
end
end
