function [V_processed, diagnostics] = preprocess_req_patch( ...
    V_raw, window, options)
%PREPROCESS_REQ_PATCH Canonical preprocessing for local REQ spectra.
%
% Processing order:
%   1. identify finite samples;
%   2. mask the spatial window at invalid samples;
%   3. compute a window-weighted complex local mean;
%   4. subtract the mean before applying the window;
%   5. normalize by RMS magnitude.
%
% This preserves zero values outside the spatial-window support.

arguments
    V_raw {mustBeNumeric}
    window {mustBeNumeric}

    options.MinValidFraction (1,1) double = 0
    options.RequireFiniteCenter (1,1) logical = true
end

if ~isequal(size(V_raw), size(window))
    error("reqml:PatchWindowSizeMismatch", ...
        "Patch and window must have identical dimensions.");
end

if options.MinValidFraction < 0 || ...
        options.MinValidFraction > 1
    error("reqml:InvalidMinimumValidFraction", ...
        "MinValidFraction must be between 0 and 1.");
end

valid_mask = isfinite(V_raw);

center_z = floor(size(V_raw, 1)/2) + 1;
center_x = floor(size(V_raw, 2)/2) + 1;

valid_fraction = nnz(valid_mask) / numel(valid_mask);

diagnostics = struct();
diagnostics.valid = false;
diagnostics.valid_fraction = valid_fraction;
diagnostics.local_mean = NaN;
diagnostics.rms_value = NaN;

V_processed = zeros(size(V_raw), "like", V_raw);

if options.RequireFiniteCenter && ...
        ~valid_mask(center_z, center_x)
    return
end

if valid_fraction < options.MinValidFraction
    return
end

Wvalid = cast(window, "like", V_raw);
Wvalid(~valid_mask) = 0;

weight_sum = sum(Wvalid(:));

if ~isfinite(weight_sum) || weight_sum <= 0
    return
end

V_filled = V_raw;
V_filled(~valid_mask) = 0;

local_mean = ...
    sum(V_filled(:) .* Wvalid(:)) / weight_sum;

V_processed = ...
    (V_filled - local_mean) .* Wvalid;

rms_value = sqrt(mean( ...
    abs(V_processed(:)).^2, ...
    "omitnan"));

if ~isfinite(rms_value) || rms_value <= eps
    V_processed(:) = 0;
    return
end

V_processed = V_processed / rms_value;
V_processed(~isfinite(V_processed)) = 0;

diagnostics.valid = true;
diagnostics.local_mean = local_mean;
diagnostics.rms_value = rms_value;

end
