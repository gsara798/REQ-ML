function campaign = buildSimulationCampaign(geometry, options)
%BUILDSIMULATIONCAMPAIGN Build one inexpensive pedagogical Eikonal case.
% This function constructs configuration only; it does not run a solver.

arguments
    geometry {mustBeTextScalar}
    options.OutputDirectory {mustBeTextScalar}
    options.Cs (1,1) double {mustBePositive} = 2
    options.CsBackground (1,1) double {mustBePositive} = 2
    options.CsInclusion (1,1) double {mustBePositive} = 3
    options.InclusionRadiusMm (1,1) double {mustBePositive} = 15
    options.FrequencyHz (1,1) double {mustBePositive} = 400
    options.FieldRegime {mustBeTextScalar} = "directional"
    options.Seed (1,1) double {mustBeInteger,mustBePositive} = 1001
end

geometry = lower(string(geometry));
if ~ismember(geometry, ["homogeneous" "inclusion"])
    error("reqml:UnknownExampleGeometry", ...
        "Geometry must be homogeneous or inclusion.");
end
regime = reqml.examples.resolveFieldRegime(options.FieldRegime);
domain_m = 0.08;
if geometry == "inclusion" && options.InclusionRadiusMm >= 40
    error("reqml:ExampleInclusionOutsideDomain", ...
        "InclusionRadiusMm must be smaller than 40 mm.");
end

campaign = struct();
campaign.schema_version = "1.2";
campaign.backend = "swsynth";
campaign.campaign_name = "reqml_example_" + geometry;
campaign.base_config = "configs/swsynth/scientific/reqml_q0_v2/" + ...
    geometry + "_base.json";
campaign.output = struct("directory", string(options.OutputDirectory));
overrides = [ ...
    override("seed", options.Seed)
    override("domain.Lx_m", domain_m)
    override("domain.Lz_m", domain_m)
    override("wavefield.frequency_hz", options.FrequencyHz)
    override("directions.count", regime.direction_count)
    override("directions.in_plane_count", regime.in_plane_count)
    override("directions.support.solid_angle_sr", regime.solid_angle_sr)];
if geometry == "homogeneous"
    overrides(end+1) = override( ...
        "medium.background_cs_m_s", options.Cs);
else
    overrides(end+1) = override( ...
        "medium.background_cs_m_s", options.CsBackground);
    overrides(end+1) = override( ...
        "medium.objects[1].cs_m_s", options.CsInclusion);
    overrides(end+1) = override( ...
        "medium.objects[1].center_xz_m", [domain_m/2 domain_m/2]);
    overrides(end+1) = override( ...
        "medium.objects[1].radius_m", 1e-3*options.InclusionRadiusMm);
end
run = struct("design_id", "example_"+geometry+"_"+regime.name, ...
    "condition_id", "example_"+geometry+"_"+regime.name, ...
    "realization_id", 1, "overrides", overrides);
campaign.runs = run;
end

function value = override(path, content)
value = struct("path", string(path), "value", content);
end
