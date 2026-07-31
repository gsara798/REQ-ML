function q = evaluate_quantile_at_wavenumber(mapping, k_target_rad_m)
%EVALUATE_QUANTILE_AT_WAVENUMBER Evaluate cumulative REQ energy at target k.

arguments
    mapping (1,1) struct
    k_target_rad_m (1,1) double
end

if ~isfield(mapping, "k_cent") || ...
        ~isfield(mapping, "Ecum")
    error("reqml:InvalidReqMapping", ...
        "REQ mapping must contain k_cent and Ecum.");
end

if ~isfinite(k_target_rad_m) || ...
        k_target_rad_m <= 0
    q = NaN;
    return
end

k_cent = double(mapping.k_cent(:));
Ecum = double(mapping.Ecum(:));

valid = isfinite(k_cent) & isfinite(Ecum);

if nnz(valid) < 2
    q = NaN;
    return
end

k_valid = k_cent(valid);
q_valid = Ecum(valid);

[k_valid, unique_index] = unique( ...
    k_valid, ...
    "stable");

q_valid = q_valid(unique_index);

if numel(k_valid) < 2
    q = NaN;
    return
end

q = interp1( ...
    k_valid, ...
    q_valid, ...
    k_target_rad_m, ...
    "linear", ...
    "extrap");

q = max(0, min(1, q));

end
