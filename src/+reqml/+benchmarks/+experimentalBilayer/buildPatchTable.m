function patches = buildPatchTable(condition, estimator, cs_map, x_idx, z_idx, window_size, data, options)
%BUILDPATCHTABLE Attach exact truth, distance, and window purity to estimates.

arguments
    condition {mustBeTextScalar}
    estimator {mustBeTextScalar}
    cs_map double
    x_idx (1,:) double
    z_idx (:,1) double
    window_size (1,:) double
    data (1,1) struct
    options.M (1,1) double = NaN
    options.Preprocessing {mustBeTextScalar} = "raw"
    options.InterfaceZM (1,1) double = NaN
end
if isscalar(window_size), window_size=[window_size window_size]; end
if numel(window_size)~=2 || any(mod(window_size,2)~=1)
    error('reqml:benchmark:InvalidWindow','Window size must be odd [Nz Nx].');
end
if ~isequal(size(cs_map),[numel(z_idx) numel(x_idx)])
    error('reqml:benchmark:MapSizeMismatch', ...
        'Estimate map size does not match its center axes.');
end
if ~data.has_truth
    error('reqml:benchmark:TruthRequired','Controlled benchmark requires truth.');
end
[CX,CZ]=meshgrid(double(x_idx),double(z_idx));
cx=CX(:); cz=CZ(:); estimate_m_s=double(cs_map(:)); n=numel(cx);
truth_m_s=nan(n,1); center_material_id=zeros(n,1,'uint16');
window_purity=nan(n,1); half_z=floor(window_size(1)/2); half_x=floor(window_size(2)/2);
for index=1:n
    center_material_id(index)=data.truth.material_id_zx(cz(index),cx(index));
    truth_m_s(index)=data.truth.cs_m_s_zx(cz(index),cx(index));
    patch=data.truth.material_id_zx( ...
        cz(index)-half_z:cz(index)+half_z, ...
        cx(index)-half_x:cx(index)+half_x);
    window_purity(index)=mean(patch(:)==center_material_id(index));
end
x_m=data.axes.x_m(cx); z_m=data.axes.z_m(cz);
distance_to_interface_mm=1e3*(z_m-options.InterfaceZM);
if ~isfinite(options.InterfaceZM), distance_to_interface_mm(:)=NaN; end
absolute_distance_mm=abs(distance_to_interface_mm);
distance_bin=repmat("homogeneous",n,1);
if isfinite(options.InterfaceZM)
    distance_bin(:)=">8"; distance_bin(absolute_distance_mm<8)="5-8";
    distance_bin(absolute_distance_mm<5)="3-5";
    distance_bin(absolute_distance_mm<3)="1-3";
    distance_bin(absolute_distance_mm<1)="0-1";
end
purity_bin=repmat("1",n,1); purity_bin(window_purity<1)="0.98-1";
purity_bin(window_purity<.98)="0.9-0.98";
purity_bin(window_purity<.9)="0.7-0.9";
purity_bin(window_purity<.7)="0.5-0.7";
valid=isfinite(estimate_m_s)&estimate_m_s>0;
signed_error_m_s=estimate_m_s-truth_m_s;
absolute_error_percent=100*abs(signed_error_m_s)./truth_m_s;
patches=table(repmat(string(condition),n,1),repmat(string(estimator),n,1), ...
    repmat(string(options.Preprocessing),n,1),repmat(options.M,n,1),cx,cz, ...
    x_m,z_m,center_material_id,truth_m_s,estimate_m_s,signed_error_m_s, ...
    absolute_error_percent,window_purity,distance_to_interface_mm, ...
    absolute_distance_mm,distance_bin,purity_bin,valid, ...
    VariableNames=["condition","estimator","preprocessing","M","cx","cz", ...
    "x_m","z_m","center_material_id","truth_m_s","estimate_m_s", ...
    "signed_error_m_s","absolute_error_percent","window_purity", ...
    "distance_to_interface_mm","absolute_distance_mm","distance_bin", ...
    "purity_bin","valid"]);
end
