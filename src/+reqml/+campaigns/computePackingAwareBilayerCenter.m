function packing = computePackingAwareBilayerCenter( ...
        win_size, grid_spacing_m, options)
%COMPUTEPACKINGAWAREBILAYERCENTER Place an analytic target for reuse.
%
% The interface-normal coordinate remains centered. The tangential
% coordinate is placed at the low legal edge, leaving the largest contiguous
% legal span for opportunistic centers. Domain expansion is deterministic and
% occurs only when another useful center is requested and the default domain
% cannot meet the target-to-opportunistic separation.

arguments
    win_size (1,1) double {mustBeInteger,mustBePositive}
    grid_spacing_m (1,2) double {mustBePositive}
    options.InterfaceOrientation (1,1) string = "x"
    options.MinimumDomainMarginPixels (1,1) double = 0
    options.DomainPolicyMode (1,1) string = "fixed"
    options.DefaultDomainSizeM (1,2) double = [0.05 0.05]
    options.ExpandedDomainSizeM (1,2) double = [0.07 0.07]
    options.MinimumPackableCenters (1,1) double = 2
    options.AnalyticToOpportunisticSeparationFraction (1,1) double = 0.25
    options.RequireAdditionalUsefulCenter (1,1) logical = true
end

validate_options(win_size, grid_spacing_m, options);
normal_axis = 1;
if lower(options.InterfaceOrientation)=="z", normal_axis=2; end
tangential_axis = 3-normal_axis;

normal = evaluate_domain(options.DefaultDomainSizeM,win_size, ...
    grid_spacing_m,normal_axis,tangential_axis,options);
selected = normal;
expansion_required = false;

needs_expansion = options.RequireAdditionalUsefulCenter && ...
    normal.maximum_geometrically_packable_center_count < ...
        options.MinimumPackableCenters;
if options.DomainPolicyMode=="adaptive_for_center_packing" && needs_expansion
    selected = evaluate_domain(options.ExpandedDomainSizeM,win_size, ...
        grid_spacing_m,normal_axis,tangential_axis,options);
    expansion_required = true;
end

if options.RequireAdditionalUsefulCenter && ...
        selected.maximum_geometrically_packable_center_count < ...
            options.MinimumPackableCenters
    error("reqml:InsufficientPackingDomain", ...
        "Selected domain cannot pack the requested minimum center count.");
end

packing = selected;
packing.schema_name = "reqml_packing_aware_bilayer_center";
packing.schema_version = "1.0";
packing.packing_strategy = "tangential_low_edge_normal_centered";
packing.interface_orientation = lower(options.InterfaceOrientation);
packing.interface_normal_axis = normal_axis;
packing.interface_tangential_axis = tangential_axis;
packing.default_domain_size_m = options.DefaultDomainSizeM;
packing.expanded_domain_size_m = options.ExpandedDomainSizeM;
packing.expansion_required = expansion_required;
packing.additional_useful_center_required = ...
    options.RequireAdditionalUsefulCenter;

end


function value = evaluate_domain(domain_size_m,win,spacing,normal_axis, ...
        tangential_axis,options)

pixels = round(domain_size_m./spacing)+1;
reconstructed = (pixels-1).*spacing;
if any(abs(reconstructed-domain_size_m) > ...
        64*eps(max(domain_size_m,spacing)))
    error("reqml:PackingDomainGridMismatch", ...
        "Domain dimensions must be integer multiples of grid spacing.");
end
half=floor(win/2);
margin=round(options.MinimumDomainMarginPixels);
legal_min=repmat(1+half+margin,1,2);
legal_max=pixels-half-margin;
if any(legal_max<legal_min)
    error("reqml:InvalidPackingWindowSupport", ...
        "REQ window does not fit inside the selected domain.");
end

center=zeros(1,2);
center(normal_axis)=round((legal_min(normal_axis)+legal_max(normal_axis))/2);
center(tangential_axis)=legal_min(tangential_axis);
span=legal_max(tangential_axis)-legal_min(tangential_axis);
minimum_distance=options.AnalyticToOpportunisticSeparationFraction*win;
if minimum_distance==0
    count=prod(legal_max-legal_min+1);
else
    count=1+floor(span/minimum_distance);
end

value=struct();
value.selected_domain_size_m=domain_size_m;
value.selected_domain_size_pixels=pixels;
value.resolved_window_size_pixels=win;
value.selected_patch_center_indices_xz=center;
value.legal_center_min_indices_xz=legal_min;
value.legal_center_max_indices_xz=legal_max;
value.available_packing_span_pixels=span;
value.available_packing_span_m=span*spacing(tangential_axis);
value.maximum_geometrically_packable_center_count=count;

end


function validate_options(win,spacing,options)
if mod(win,2)==0
    error("reqml:EvenPackingWindow","win_size must be odd.");
end
if any(~isfinite(spacing)) || any(spacing<=0) || ...
        ~ismember(lower(options.InterfaceOrientation),["x","z"])
    error("reqml:InvalidPackingConfiguration", ...
        "Grid spacing and interface orientation are invalid.");
end
if ~ismember(options.DomainPolicyMode,["fixed","adaptive_for_center_packing"])
    error("reqml:InvalidDomainPolicyMode","Unsupported domain policy mode.");
end
if options.MinimumPackableCenters<1 || ...
        options.MinimumPackableCenters~=fix(options.MinimumPackableCenters) || ...
        options.AnalyticToOpportunisticSeparationFraction<0
    error("reqml:InvalidPackingConfiguration", ...
        "Packing count and separation must be nonnegative integers/fractions.");
end
end
