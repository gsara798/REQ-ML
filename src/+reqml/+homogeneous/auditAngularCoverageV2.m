function result=auditAngularCoverageV2(options)
%AUDITANGULARCOVERAGEV2 Compare legacy v1 fields with the frozen v2 family.

arguments
    options.V1ConfigFile {mustBeTextScalar} = ...
        "${REPOSITORY_ROOT}/archive/legacy_v1/configs/homogeneous/homogeneous_cartesian_q0_v1.json"
    options.V1CampaignRunsCsv {mustBeTextScalar} = ...
        "${SWSIM_ROOT}/outputs/campaigns/homogeneous_cartesian_q0_v1/campaign_runs.csv"
    options.OutputDirectory {mustBeTextScalar} = ""
end
root=string(fileparts(fileparts(fileparts(fileparts(mfilename("fullpath"))))));
config_file=reqml.config.resolveWorkspacePath(string(options.V1ConfigFile),RepositoryRoot=root);
config=jsondecode(fileread(config_file));
fields=config.field_regimes(:); n=numel(fields);
field_name=string({fields.name})'; direction_count=double([fields.direction_count])';
in_plane_count=double([fields.in_plane_count])'; solid_angle_sr=double([fields.solid_angle_sr])';
solid_angle_fraction=solid_angle_sr/(4*pi);
legacy_Dnom=reqml.coverage.computeNominalAngularCoverage(direction_count,solid_angle_sr);
direction_density_per_sr=direction_count./solid_angle_sr;
requested_in_plane_fraction=in_plane_count./direction_count;
v1=table(field_name,direction_count,in_plane_count,solid_angle_sr, ...
    solid_angle_fraction,legacy_Dnom,direction_density_per_sr,requested_in_plane_fraction);
v1.retained_direction_count=nan(n,1); v1.retained_in_plane_count=nan(n,1);
v1.realized_in_plane_fraction=nan(n,1); v1.angular_entropy=nan(n,1);
v1.angular_effective_bins=nan(n,1); v1.radial_entropy=nan(n,1);
v1.radial_effective_bins=nan(n,1);
csv=reqml.config.resolveWorkspacePath(string(options.V1CampaignRunsCsv),RepositoryRoot=root);
if isfile(csv)
    runs=readtable(csv,TextType="string");
    for i=1:n
        mask=runs.direction_count==direction_count(i) & ...
            abs(runs.solid_angle_sr-solid_angle_sr(i))<1e-12;
        v1.retained_direction_count(i)=median(runs.retained_direction_count(mask),"omitnan");
        v1.retained_in_plane_count(i)=median(runs.retained_in_plane_count(mask),"omitnan");
        v1.realized_in_plane_fraction(i)=median(runs.retained_in_plane_fraction(mask),"omitnan");
        v1.angular_entropy(i)=median(runs.angular_entropy(mask),"omitnan");
        v1.angular_effective_bins(i)=median(runs.angular_effective_bins(mask),"omitnan");
        v1.radial_entropy(i)=median(runs.radial_entropy(mask),"omitnan");
        v1.radial_effective_bins(i)=median(runs.radial_effective_bins(mask),"omitnan");
    end
end
v2=reqml.homogeneous.buildAngularFieldFamilyV2();
assessment=struct("legacy_Dnom_preserved",true, ...
    "primary_v2_coordinate","angular_support_fraction", ...
    "legacy_Dnom_primary_suitable",false, ...
    "rationale",["Legacy Dnom multiplies two coupled design controls and " + ...
    "compresses v1 levels nonuniformly. Support fraction is direct, bounded, " + ...
    "monotonic, and keeps N/P as adequacy controls rather than independent axes."]);
paths=struct(); output=string(options.OutputDirectory);
if strlength(output)>0
    output=reqml.config.resolveWorkspacePath(output,RepositoryRoot=root);
    if ~isfolder(output), mkdir(output); end
    paths.v1=fullfile(output,"v1_angular_coverage_audit.csv");
    paths.v2=fullfile(output,"v2_angular_field_family.csv");
    paths.assessment=fullfile(output,"angular_coordinate_assessment.json");
    writetable(v1,paths.v1); writetable(v2,paths.v2); write_json(paths.assessment,assessment);
end
result=struct("v1",v1,"v2",v2,"assessment",assessment,"paths",paths);
end

function write_json(path,value)
fid=fopen(path,"w"); if fid<0, error("reqml:CannotWriteAngularAudit","Cannot write %s",path); end
cleanup=onCleanup(@() fclose(fid)); fprintf(fid,"%s\n",jsonencode(value,PrettyPrint=true));
end
