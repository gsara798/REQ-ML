function [map,x_mm,z_mm] = patchesToGrid(patches,value_name)
%PATCHESTOGRID Reconstruct a regular native estimator grid for imagesc.

arguments
    patches table
    value_name {mustBeTextScalar} = "estimate_m_s"
end
if isempty(patches)
    map=[]; x_mm=[]; z_mm=[]; return
end
[x_m,~,ix]=unique(double(patches.x_m),'sorted');
[z_m,~,iz]=unique(double(patches.z_m),'sorted');
map=nan(numel(z_m),numel(x_m));
linear=sub2ind(size(map),iz,ix);
if numel(unique(linear))~=height(patches)
    error('reqml:benchmark:DuplicateGridPoint', ...
        'Patch table has duplicate physical grid points.');
end
map(linear)=double(patches.(string(value_name)));
x_mm=1e3*x_m(:).'; z_mm=1e3*z_m(:);
end
