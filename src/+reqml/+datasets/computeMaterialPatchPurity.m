function [purity, dominant_material_id, counts] = ...
    computeMaterialPatchPurity(material_patch, valid_patch)
%COMPUTEMATERIALPATCHPURITY Compute modal material fraction in a patch.
%
% This is the canonical REQ-ML material-purity definition used by both
% dataset extraction and analytic geometry planning. Invalid pixels are
% excluded. Purity is the fraction of valid pixels assigned to the modal
% material ID.

arguments
    material_patch {mustBeNumericOrLogical}
    valid_patch = true(size(material_patch))
end

if ~isequal(size(material_patch), size(valid_patch))
    error("reqml:MaterialPurityMaskSizeMismatch", ...
        "material_patch and valid_patch must have identical sizes.");
end

valid_patch = logical(valid_patch);
valid_materials = double(material_patch(valid_patch));

if isempty(valid_materials)
    purity = NaN;
    dominant_material_id = NaN;
    counts = zeros(0, 2);
    return
end

[material_ids, ~, groups] = unique(valid_materials);
material_counts = accumarray(groups, 1);

[dominant_count, dominant_index] = max(material_counts);

dominant_material_id = material_ids(dominant_index);
purity = dominant_count / numel(valid_materials);
counts = [material_ids, material_counts];

end
