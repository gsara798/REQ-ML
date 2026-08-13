function [roi,distance_m] = classifyExternalRoi(geometry,material_id, ...
        purity,cx,cz,dx_m,dz_m)
%CLASSIFYEXTERNALROI Assign physically traceable core/interface ROIs.
% Interface-band patches are exactly those whose REQ support contains more
% than one material (truth purity < 1). Remaining pure patches are assigned
% by their centre material. Distance is centre-to-nearest-interface distance.

arguments
    geometry (:,1) string
    material_id (:,1) double
    purity (:,1) double
    cx (:,1) double
    cz (:,1) double
    dx_m (1,1) double {mustBePositive}
    dz_m (1,1) double {mustBePositive}
end
n=numel(purity);
if any([numel(geometry),numel(material_id),numel(cx),numel(cz)]~=n)
    error("reqml:ExternalRoiSizeMismatch","ROI inputs must have equal length.");
end
roi=strings(n,1); distance_m=nan(n,1);
mixed=isfinite(purity) & purity<1-1e-12;
roi(mixed)="interface_band";
finite_ids=material_id(isfinite(material_id));
if isempty(finite_ids)
    error("reqml:MissingExternalMaterialId", ...
        "External ROI classification requires finite material IDs.");
end
background_id=min(finite_ids);
for index=find(~mixed).'
    if geometry(index)=="inclusion"
        if material_id(index)==background_id, roi(index)="background_far";
        else, roi(index)="inclusion_core"; end
    elseif geometry(index)=="bilayer"
        if material_id(index)==background_id, roi(index)="layer_1_core";
        else, roi(index)="layer_2_core"; end
    else
        roi(index)="homogeneous";
    end
end
% The classification itself has an exact physical meaning: a patch is in
% the interface band iff its full REQ support intersects both materials.
% Centre-to-interface distance is intentionally left NaN here because it
% cannot be reconstructed exactly from centre samples alone.
distance_m(:)=NaN;
end
