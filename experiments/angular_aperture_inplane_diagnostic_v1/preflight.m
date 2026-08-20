function result = preflight()

[conditions,runs,cfg] = materialize_design();

assert(height(conditions)==12);
assert(height(runs)==12);

assert(numel(unique(conditions.condition_id))==12);
assert(numel(unique(runs.run_id))==12);
assert(numel(unique(runs.seed))==12);

assert(all(conditions.direction_count==2000));
assert(all(conditions.in_plane_count>=0));
assert(all(conditions.in_plane_count<=conditions.direction_count));
assert(all(abs(conditions.solid_angle_sr-4*pi)<1e-10));

fprintf("\nFull-sphere in-plane diagnostic preflight\n");
fprintf("========================================\n");
fprintf("Physical conditions : %d\n",height(conditions));
fprintf("Planned runs        : %d\n",height(runs));
fprintf("SWS                 : %s m/s\n", ...
    strjoin(string(unique(conditions.cs_true_m_s).'),", "));
fprintf("N directions        : %d\n",unique(conditions.direction_count));
fprintf("Omega               : %.6f sr = 4pi\n",unique(conditions.solid_angle_sr));

fprintf("\nIn-plane design\n");
disp(unique(conditions(:,["in_plane_count","in_plane_fraction"])));

result = struct("conditions",conditions,"runs",runs,"config",cfg);

end
