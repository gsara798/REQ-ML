function selection = selectCoverageCenters( ...
    truth, win_size, requested_cells, options)
%SELECTCOVERAGECENTERS Select patch centers for deficient coverage cells.
%
% Candidate centers are classified using inexpensive truth-map quantities
% before running REQ:
%
%   local center SWS
%   dominant-material patch purity
%   run frequency
%   run field-coverage value
%
% One physical simulation can therefore contribute patches to multiple
% SWS and purity bins.
%
% requested_cells must contain:
%
%   sws_bin
%   frequency_bin
%   purity_bin
%   diffusivity_bin
%
% It may optionally contain:
%
%   needed_example_count

arguments
    truth (1,1) struct
    win_size (1,1) double {mustBeInteger, mustBePositive}
    requested_cells table

    options.PurityEdges (1,:) double
    options.DiffusivityEdges (1,:) double
    options.SwsEdges (1,:) double
    options.FrequencyEdges (1,:) double

    options.FrequencyHz (1,1) double {mustBeFinite}
    options.DiffusivityValue (1,1) double {mustBeFinite}

    options.CandidateStepPixels (1,1) double = 1
    options.MaximumPerCell (1,1) double = 8
    options.MinimumCenterDistancePixels (1,1) double = 0
    options.MinimumValidFraction (1,1) double = 1
    options.RandomSeed (1,1) double = 1
end

validate_truth(truth);
validate_requested_cells(requested_cells);

if mod(win_size, 2) == 0
    error("reqml:EvenCoverageCenterWindow", ...
        "win_size must be odd.");
end

candidate_step = round(options.CandidateStepPixels);
maximum_per_cell = round(options.MaximumPerCell);
minimum_distance = double(options.MinimumCenterDistancePixels);

if candidate_step < 1
    error("reqml:InvalidCandidateStep", ...
        "CandidateStepPixels must be at least one.");
end

if maximum_per_cell < 1
    error("reqml:InvalidMaximumPerCell", ...
        "MaximumPerCell must be at least one.");
end

if options.MinimumValidFraction < 0 || ...
        options.MinimumValidFraction > 1
    error("reqml:InvalidMinimumValidFraction", ...
        "MinimumValidFraction must be between zero and one.");
end

material_map = truth.material_id_zx;
cs_map = double(truth.cs_m_s_zx);
valid_map = logical(truth.valid_mask_zx);

[nz, nx] = size(material_map);
half_win = floor(win_size / 2);

x_centers = ...
    (1 + half_win):candidate_step:(nx - half_win);

z_centers = ...
    (1 + half_win):candidate_step:(nz - half_win);

if isempty(x_centers) || isempty(z_centers)
    error("reqml:CoverageCenterFieldTooSmall", ...
        "The truth maps are too small for win_size=%d.", ...
        win_size);
end

[candidate_x, candidate_z] = meshgrid( ...
    x_centers, ...
    z_centers);

candidate_x = candidate_x(:);
candidate_z = candidate_z(:);
candidate_count = numel(candidate_x);

truth_cs_center_m_s = nan(candidate_count, 1);
truth_material_purity = nan(candidate_count, 1);
truth_valid_fraction = nan(candidate_count, 1);

for index = 1:candidate_count
    cx = candidate_x(index);
    cz = candidate_z(index);

    x_idx = (cx - half_win):(cx + half_win);
    z_idx = (cz - half_win):(cz + half_win);

    material_patch = material_map(z_idx, x_idx);
    valid_patch = valid_map(z_idx, x_idx);

    truth_cs_center_m_s(index) = cs_map(cz, cx);
    truth_valid_fraction(index) = mean(valid_patch, "all");

    truth_material_purity(index) = ...
        reqml.datasets.computeMaterialPatchPurity( ...
            material_patch, valid_patch);
end

candidates = table();
candidates.cx = candidate_x;
candidates.cz = candidate_z;
candidates.truth_cs_center_m_s = truth_cs_center_m_s;
candidates.truth_material_purity = truth_material_purity;
candidates.truth_valid_fraction = truth_valid_fraction;

candidates.campaign_frequency_hz = repmat( ...
    double(options.FrequencyHz), ...
    candidate_count, ...
    1);

candidates.campaign_angular_entropy = repmat( ...
    double(options.DiffusivityValue), ...
    candidate_count, ...
    1);

candidates = reqml.coverage.assignCoverageBins( ...
    candidates, ...
    PurityEdges=options.PurityEdges, ...
    DiffusivityEdges=options.DiffusivityEdges, ...
    SwsEdges=options.SwsEdges, ...
    FrequencyEdges=options.FrequencyEdges, ...
    FieldCoverageMode="measured_entropy", ...
    DiffusivityVariable="campaign_angular_entropy");

eligible = ...
    candidates.coverage_valid & ...
    candidates.truth_valid_fraction >= ...
        options.MinimumValidFraction;

candidates = candidates(eligible, :);

requested = normalize_requested_cells( ...
    requested_cells, ...
    maximum_per_cell);

selected_rows = zeros(0, 1);
selection_target_cell_key = strings(0, 1);
selection_target_ordinal = zeros(0, 1);

stream = RandStream( ...
    "mt19937ar", ...
    "Seed", round(options.RandomSeed));

for request_index = 1:height(requested)
    matches = ...
        candidates.coverage_sws_bin == ...
            requested.sws_bin(request_index) & ...
        candidates.coverage_frequency_bin == ...
            requested.frequency_bin(request_index) & ...
        candidates.coverage_purity_bin == ...
            requested.purity_bin(request_index) & ...
        candidates.coverage_diffusivity_bin == ...
            requested.diffusivity_bin(request_index);

    available_rows = find(matches);

    if isempty(available_rows)
        continue
    end

    available_rows = available_rows( ...
        randperm(stream, numel(available_rows)));

    quota = requested.selection_quota(request_index);
    selected_for_cell = zeros(0, 1);

    for row = reshape(available_rows, 1, [])
        if numel(selected_for_cell) >= quota
            break
        end

        if any(selected_rows == row)
            continue
        end

        if violates_minimum_distance( ...
                candidates.cx(row), ...
                candidates.cz(row), ...
                candidates, ...
                selected_rows, ...
                minimum_distance)
            continue
        end

        selected_rows(end + 1, 1) = row; %#ok<AGROW>
        selected_for_cell(end + 1, 1) = row; %#ok<AGROW>

        selection_target_cell_key(end + 1, 1) = ...
            requested.coverage_cell_key(request_index); %#ok<AGROW>

        selection_target_ordinal(end + 1, 1) = ...
            request_index; %#ok<AGROW>
    end
end

selection = candidates(selected_rows, :);
selection.selection_target_cell_key = ...
    selection_target_cell_key;
selection.selection_target_ordinal = ...
    selection_target_ordinal;

if isempty(selection)
    selection.selection_target_cell_key = strings(0, 1);
    selection.selection_target_ordinal = zeros(0, 1);
end

end


function requested = normalize_requested_cells( ...
    requested_cells, maximum_per_cell)

requested = requested_cells;

if ismember( ...
        "needed_example_count", ...
        string(requested.Properties.VariableNames))
    needed = max( ...
        0, ...
        round(double(requested.needed_example_count)));
else
    needed = repmat( ...
        maximum_per_cell, ...
        height(requested), ...
        1);
end

requested.selection_quota = min( ...
    needed, ...
    maximum_per_cell);

requested.coverage_cell_key = compose( ...
    "s%02d_f%02d_p%02d_d%02d", ...
    requested.sws_bin, ...
    requested.frequency_bin, ...
    requested.purity_bin, ...
    requested.diffusivity_bin);

end


function result = violates_minimum_distance( ...
    cx, cz, candidates, selected_rows, minimum_distance)

if minimum_distance <= 0 || isempty(selected_rows)
    result = false;
    return
end

dx = double(candidates.cx(selected_rows)) - double(cx);
dz = double(candidates.cz(selected_rows)) - double(cz);

result = any(hypot(dx, dz) < minimum_distance);

end


function validate_truth(truth)

required = [
    "cs_m_s_zx"
    "material_id_zx"
    "valid_mask_zx"
    ];

for name = required.'
    if ~isfield(truth, name)
        error("reqml:InvalidCoverageCenterTruth", ...
            "Truth is missing '%s'.", name);
    end
end

expected_size = size(truth.material_id_zx);

for name = required.'
    if ~isequal(size(truth.(name)), expected_size)
        error("reqml:InvalidCoverageCenterTruth", ...
            "Truth map '%s' has an inconsistent size.", name);
    end
end

end


function validate_requested_cells(requested_cells)

required = [
    "sws_bin"
    "frequency_bin"
    "purity_bin"
    "diffusivity_bin"
    ];

missing = setdiff( ...
    required, ...
    string(requested_cells.Properties.VariableNames));

if ~isempty(missing)
    error("reqml:MissingRequestedCoverageCellVariable", ...
        "Requested cells are missing '%s'.", ...
        missing(1));
end

end
