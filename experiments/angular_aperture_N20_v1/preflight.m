function result = preflight()

[conditions,runs,cfg] = materialize_design();

expected_conditions = ...
    numel(cfg.design.cs_m_s) * ...
    numel(cfg.design.in_plane_count) * ...
    numel(cfg.design.solid_angle_fraction);

expected_runs = ...
    expected_conditions * double(cfg.design.realizations_per_condition);

assert(height(conditions)==expected_conditions);
assert(height(runs)==expected_runs);

assert(all(conditions.direction_count==20));
assert(all(conditions.in_plane_count<=conditions.direction_count));

expected_omega = 4*pi*conditions.solid_angle_fraction;

assert(all(abs(conditions.solid_angle_sr-expected_omega)<1e-12));
assert(all(conditions.solid_angle_sr>0 & conditions.solid_angle_sr<=4*pi));

assert(numel(unique(runs.run_id))==expected_runs);
assert(numel(unique(runs.seed))==expected_runs);

fprintf("\nN=20 angular-aperture sweep\n");
fprintf("===========================\n");
fprintf("SWS values           : %s m/s\n", ...
    strjoin(string(unique(conditions.cs_true_m_s).'),", "));
fprintf("Directions           : %d\n",unique(conditions.direction_count));
fprintf("In-plane levels      : %d\n",numel(unique(conditions.in_plane_count)));
fprintf("Aperture levels      : %d\n",numel(unique(conditions.solid_angle_fraction)));
fprintf("Physical conditions  : %d\n",height(conditions));
fprintf("Realizations/point   : %d\n",cfg.design.realizations_per_condition);
fprintf("Total runs           : %d\n",height(runs));

disp(unique(conditions(:,["in_plane_count","in_plane_fraction"])));

result = struct("conditions",conditions,"runs",runs,"config",cfg);

end
