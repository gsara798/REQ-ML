function result = preflight()

[conditions,runs,cfg] = materialize_design();

repo_root = string(fileparts(fileparts(fileparts(mfilename("fullpath")))));
sim_root = string(getenv("SWSIM_ROOT"));

assert(strlength(sim_root)>0,"SWSIM_ROOT is not defined.");

assert(height(conditions)==30, ...
    "Expected 30 physical conditions.");

assert(height(runs)==60, ...
    "Expected 60 runs.");

assert(numel(unique(conditions.condition_id))==30);
assert(numel(unique(runs.design_id))==60);
assert(numel(unique(runs.seed))==60);
assert(numel(unique(runs.geometry_seed))==60);

assert(all(ismember(conditions.frequency_hz,[300 500])));
assert(all(conditions.vibrator_count>=1));

assert(all(conditions.exact_in_plane_sources <= ...
    conditions.vibrator_count));

assert(all(conditions.minimum_in_plane_sources + ...
    conditions.minimum_out_of_plane_sources <= ...
    conditions.vibrator_count));

assert(all(conditions.solid_angle_sr>0 & ...
    conditions.solid_angle_sr<=4*pi));

%% Required 3D bases
base_files = [
    resolve_path(string(cfg.paths.homogeneous_base_config),repo_root,sim_root)
    resolve_path(string(cfg.paths.bilayer_base_config),repo_root,sim_root)
    resolve_path(string(cfg.paths.inclusion_base_config),repo_root,sim_root)
];

for i = 1:numel(base_files)

    assert(isfile(base_files(i)), ...
        "Missing base config: %s",base_files(i));

    b = jsondecode(fileread(base_files(i)));

    assert(double(b.dimension)==3, ...
        "Base config is not 3D: %s",base_files(i));

    assert(logical(b.output.save_wavefield_sample), ...
        "Wavefield sample export disabled: %s",base_files(i));

    assert(double(b.grid.Nx)==140);
    assert(double(b.grid.Ny)==96);
    assert(double(b.grid.Nz)==140);

    assert(abs(double(b.grid.dx_m)-0.5e-3)<1e-12);
    assert(abs(double(b.grid.dy_m)-0.5e-3)<1e-12);
    assert(abs(double(b.grid.dz_m)-0.5e-3)<1e-12);
end

%% Inclusion contract
inc = jsondecode(fileread(base_files(3)));

assert(numel(inc.geometry.objects)==1);
assert(string(inc.geometry.objects(1).type)=="sphere");
assert(abs(double(inc.geometry.objects(1).cs_m_s)-4)<1e-12);
assert(abs(double(inc.geometry.objects(1).cp_m_s)-40)<1e-12);

fprintf("\nk-Wave final validation preflight\n");
fprintf("=================================\n");

fprintf("Dimension            : 3D\n");
fprintf("Physical conditions  : %d\n",height(conditions));
fprintf("Realizations/point   : %d\n", ...
    cfg.design.realizations_per_condition);
fprintf("Total runs           : %d\n",height(runs));

fprintf("\nGeometry counts:\n");
disp(groupsummary(conditions,"geometry"));

fprintf("Frequencies           : %s Hz\n", ...
    strjoin(string(unique(conditions.frequency_hz).'),", "));

fprintf("Regimes               : %s\n", ...
    strjoin(unique(string(conditions.regime)).',", "));

fprintf("\nHomogeneous SWS       : %s m/s\n", ...
    strjoin(string(unique( ...
        conditions.cs_target_m_s(conditions.geometry=="homogeneous")).'),", "));

fprintf("Bilayer               : 2 -> 3 m/s\n");
fprintf("Inclusion             : 2 -> 4 m/s\n");

fprintf("\nBase configurations:\n");
for i = 1:numel(base_files)
    fprintf("  %s\n",base_files(i));
end

result = struct( ...
    "conditions",conditions, ...
    "runs",runs, ...
    "config",cfg);

end


function path = resolve_path(path,repo_root,sim_root)

path = replace(path,"${REPOSITORY_ROOT}",repo_root);
path = replace(path,"${SWSIM_ROOT}",sim_root);

end
