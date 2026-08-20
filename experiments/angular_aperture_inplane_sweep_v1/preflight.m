function result = preflight()

[conditions,runs,cfg] = materialize_design();

assert(height(conditions)==114);
expected_runs = height(conditions) * double(cfg.design.realizations_per_condition);
assert(height(runs)==expected_runs);

assert(numel(unique(conditions.condition_id))==114);
assert(numel(unique(runs.run_id))==expected_runs);
assert(numel(unique(runs.seed))==expected_runs);

assert(all(conditions.cs_true_m_s==2));
assert(all(conditions.direction_count==2000));

expected_omega = 4*pi*conditions.solid_angle_fraction;

assert(all(abs(conditions.solid_angle_sr-expected_omega)<1e-12), ...
    "solid_angle_sr does not equal 4*pi*solid_angle_fraction.");

assert(all(conditions.solid_angle_sr>0 & conditions.solid_angle_sr<=4*pi), ...
    "solid_angle_sr outside physical range (0,4*pi].");

fprintf("\nAngular aperture x in-plane sweep\n");
fprintf("=================================\n");

fprintf("SWS                 : %.1f m/s\n",unique(conditions.cs_true_m_s));
fprintf("Frequency           : %d Hz\n",unique(conditions.frequency_hz));
fprintf("Directions          : %d\n",unique(conditions.direction_count));
fprintf("In-plane levels     : %d\n",numel(unique(conditions.in_plane_count)));
fprintf("Aperture levels     : %d\n",numel(unique(conditions.solid_angle_fraction)));
fprintf("Physical conditions : %d\n",height(conditions));
fprintf("Realizations/point  : %d\n",cfg.design.realizations_per_condition);
fprintf("Total runs          : %d\n",height(runs));

fprintf("\nIn-plane counts:\n");
disp(unique(conditions(:,["in_plane_count","in_plane_fraction"])));

result = struct( ...
    "conditions",conditions, ...
    "runs",runs, ...
    "config",cfg);

end
