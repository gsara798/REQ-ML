function design = materializeCartesianDesign(config)
%MATERIALIZECARTESIANDESIGN Build controlled homogeneous conditions and runs.

arguments
    config (1,1) struct
end

validate_config(config);
cs_values=double(config.design.cs_m_s(:));
frequencies=double(config.design.frequency_hz(:));
spacings=double(config.design.spacing_m(:));
fields=config.field_regimes(:);
M_values=reqml.homogeneous.resolveReqMValues(config);
realization_count=double(config.design.base_realizations_per_condition);
condition_count=numel(cs_values)*numel(frequencies)* ...
    numel(spacings)*numel(fields);
run_count=condition_count*realization_count;

condition_rows=cell(condition_count,1);
run_rows=cell(run_count,1);
condition_ordinal=0;
run_ordinal=0;

for cs=cs_values'
    for frequency=frequencies'
        for spacing=spacings'
            geometries=cell(numel(M_values),1);
            for m_index=1:numel(M_values)
                geometries{m_index}=reqml.homogeneous.computePatchGeometry( ...
                    frequency,spacing,spacing,M=M_values(m_index), ...
                    CsGuessMPerS=double(config.req.cs_guess_m_s), ...
                    MinimumStridePixels=double(config.patch_sampling.minimum_stride_pixels), ...
                    StrideWindowFraction=double(config.patch_sampling.stride_window_fraction), ...
                    MinimumPlacementsPerAxis=double(config.patch_sampling.minimum_placements_per_axis));
            end
            domain_points=cellfun(@(g) g.domain_points_x,geometries);
            [~,maximum_index]=max(domain_points); geometry=geometries{maximum_index};
            geometry_M2=find_geometry(M_values,geometries,2);
            geometry_M3=find_geometry(M_values,geometries,3);
            geometry_M2=on_physical_domain(geometry_M2,geometry.domain_points_x);
            geometry_M3=on_physical_domain(geometry_M3,geometry.domain_points_x);
            for field_index=1:numel(fields)
                field=fields(field_index);
                condition_ordinal=condition_ordinal+1;
                condition_id=make_condition_id( ...
                    cs,frequency,spacing,string(field.name));
                angular_level=get_field(field,"angular_level",NaN);
                support_fraction=double(field.solid_angle_sr)/(4*pi);
                legacy_Dnom=reqml.coverage.computeNominalAngularCoverage( ...
                    double(field.direction_count),double(field.solid_angle_sr));
                condition_rows{condition_ordinal}=table( ...
                    condition_ordinal,condition_id,cs,frequency,spacing,spacing, ...
                    string(field.name),angular_level,support_fraction,legacy_Dnom, ...
                    double(field.direction_count),double(field.in_plane_count),double(field.solid_angle_sr), ...
                    geometry.patch_width_px,geometry.patch_height_px, ...
                    geometry.stride_x_px,geometry.stride_z_px, ...
                    geometry.domain_x_m,geometry.domain_z_m,M_values(maximum_index), ...
                    geometry_M2.patch_width_px,geometry_M2.stride_x_px, ...
                    geometry_M2.available_patch_count,geometry_M3.patch_width_px, ...
                    geometry_M3.stride_x_px,geometry_M3.available_patch_count, ...
                    realization_count, ...
                    VariableNames=["condition_ordinal","condition_id", ...
                    "cs_m_s","frequency_hz","dx_m","dz_m", ...
                    "field_regime","angular_level","angular_support_fraction", ...
                    "legacy_Dnom","direction_count","in_plane_count", ...
                    "solid_angle_sr","patch_width_px","patch_height_px", ...
                    "stride_x_px","stride_z_px","domain_x_m","domain_z_m", ...
                    "domain_basis_M","m2_patch_width_px","m2_stride_px", ...
                    "m2_available_patch_count","m3_patch_width_px","m3_stride_px", ...
                    "m3_available_patch_count", ...
                    "base_realization_count"]);
                for realization=1:realization_count
                    run_ordinal=run_ordinal+1;
                    seed=double(config.design.base_seed)+ ...
                        (condition_ordinal-1)*double( ...
                            config.design.condition_seed_stride)+realization;
                    stream=RandStream("Threefry","Seed",seed);
                    axis_angle=2*pi*rand(stream);
                    axis_xyz=[cos(axis_angle),0,sin(axis_angle)];
                    design_id=compose("%s_r%03d",condition_id,realization);
                    run_rows{run_ordinal}=table(run_ordinal,design_id, ...
                        condition_id,realization,seed,axis_angle, ...
                        axis_xyz(1),axis_xyz(2),axis_xyz(3),false, ...
                        VariableNames=["run_ordinal","design_id", ...
                        "condition_id","realization_index","seed", ...
                        "axis_angle_rad","axis_x","axis_y","axis_z", ...
                        "supplementary_run"]);
                end
            end
        end
    end
end

design=struct();
design.schema_name="reqml_homogeneous_cartesian_design";
design.schema_version="1.0";
design.campaign_id=string(config.campaign_id);
design.conditions=vertcat(condition_rows{:});
design.runs=vertcat(run_rows{:});
design.condition_count=height(design.conditions);
design.run_count=height(design.runs);
design.base_realizations_per_condition=realization_count;
design.req_M_values=M_values;
end

function geometry=find_geometry(M_values,geometries,target)
index=find(M_values==target,1);
if isempty(index)
    geometry=struct("patch_width_px",NaN,"stride_x_px",NaN, ...
        "available_patch_count",NaN);
else
    geometry=geometries{index};
end
end

function geometry=on_physical_domain(geometry,domain_points)
if isfinite(geometry.patch_width_px)
    placements=floor((domain_points-geometry.patch_width_px)/geometry.stride_x_px)+1;
    geometry.available_patch_count=max(0,placements)^2;
end
end

function value=get_field(s,name,default)
if isfield(s,name), value=double(s.(name)); else, value=default; end
end


function id=make_condition_id(cs,frequency,spacing,field)
id=compose("homq0_cs%03d_f%03d_dx%03d_%s", ...
    round(100*cs),round(frequency),round(1e6*spacing),field);
end


function validate_config(config)
required=["campaign_id","paths","design","field_regimes","req", ...
    "patch_sampling"];
missing=required(~isfield(config,required));
if ~isempty(missing)
    error("reqml:InvalidHomogeneousCartesianConfig", ...
        "Config is missing: %s",strjoin(missing,", "));
end
M_values=reqml.homogeneous.resolveReqMValues(config);
if double(config.req.cs_guess_m_s)~=3
    error("reqml:InvalidHomogeneousQ0ReqContract", ...
        "The controlled baseline requires M=2 and cs_guess_m_s=3.");
end
names=string({config.field_regimes.name});
if isequal(M_values,[2;3])
    expected=reqml.homogeneous.buildAngularFieldFamilyV2();
    valid_fields=isequal(names(:),expected.name);
else
    valid_fields=isequal(names(:),["single";"directional";"intermediate";"diffuse"]);
end
if ~valid_fields
    error("reqml:InvalidHomogeneousFieldRegimes", ...
        "Field regimes must be single, directional, intermediate, diffuse.");
end
end
