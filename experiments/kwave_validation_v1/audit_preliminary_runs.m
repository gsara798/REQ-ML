function audit_preliminary_runs()

repo_root = string(fileparts(fileparts(fileparts(mfilename("fullpath")))));
sim_root = string(getenv("SWSIM_ROOT"));
addpath(fullfile(sim_root,"src"));
addpath(fullfile(repo_root,"src"));

root = fullfile( ...
    repo_root, ...
    "outputs","validation","kwave_validation_v1", ...
    "simulations","preliminary");

out_root = fullfile( ...
    repo_root, ...
    "outputs","validation","kwave_validation_v1", ...
    "analysis","audit");

if ~isfolder(out_root)
    mkdir(out_root);
end

cfg_files = dir(fullfile(root,"**","resolved_config.json"));
assert(numel(cfg_files) == 8, ...
    "Expected 8 preliminary runs, found %d.", numel(cfg_files));

rows = repmat(struct(), numel(cfg_files), 1);

fprintf("\nREQ-ML preliminary k-Wave audit\n");
fprintf("===============================\n");
fprintf("Runs found: %d\n\n", numel(cfg_files));

for i = 1:numel(cfg_files)

    cfg_file = fullfile(cfg_files(i).folder,cfg_files(i).name);
    run_dir = string(fileparts(fileparts(cfg_file)));

    cfg = jsondecode(fileread(cfg_file));

    sample_file = fullfile(run_dir,"data","wavefield_sample.mat");
    validation_file = fullfile(run_dir,"data","validation_summary.txt");

    assert(isfile(sample_file), ...
        "Missing wavefield sample: %s", sample_file);

    assert(isfile(validation_file), ...
        "Missing validation summary: %s", validation_file);

    data = reqml.io.load_wavefield_sample(sample_file);

    src = cfg.source;
    g = src.geometry_metrics;

    run_id = string(get_last_folder(run_dir));
    geometry = infer_geometry(run_dir);

    N = double(g.source_count);
    P = double(g.in_plane_contact_count);
    Pout = double(g.out_of_plane_contact_count);
    omega = double(src.angular_support_solid_angle_sr);

    regime = infer_regime(N,P,omega);

    % -----------------------------------------------------
    % Core configuration checks
    % -----------------------------------------------------
    dimension_ok = double(cfg.dimension) == 3;

    grid_ok = ...
        double(cfg.grid.Nx) == 140 && ...
        double(cfg.grid.Ny) == 96  && ...
        double(cfg.grid.Nz) == 140;

    spacing_ok = all(abs([ ...
        double(cfg.grid.dx_m), ...
        double(cfg.grid.dy_m), ...
        double(cfg.grid.dz_m)] - 0.0005) < 1e-12);

    pml = double(cfg.solver.pml_size_points(:)).';
    pml_ok = isequal(pml,[10 8 10]);

    frequency_ok = abs(double(src.f0_hz)-500) < 1e-12;

    % -----------------------------------------------------
    % Regime/source checks
    % -----------------------------------------------------
    switch regime
        case "directional"
            source_contract_ok = ...
                N == 1 && P == 1 && Pout == 0 && ...
                abs(omega-0.01) < 1e-8;

        case "intermediate"
            source_contract_ok = ...
                N == 16 && P == 4 && Pout == 12 && ...
                abs(omega-pi) < 1e-6;

        case "diffuse_like"
            source_contract_ok = ...
                N == 32 && P == 8 && Pout == 24 && ...
                abs(omega-4*pi) < 1e-6;

        otherwise
            source_contract_ok = false;
    end

    % -----------------------------------------------------
    % Material/geometry truth checks
    % -----------------------------------------------------
    truth_values = unique(double(data.truth.cs_m_s_zx( ...
        logical(data.truth.valid_mask_zx))));
    truth_values = truth_values(:).';

    switch geometry
        case "homogeneous"
            materials_ok = numel(truth_values) == 1 && ...
                any(abs(truth_values-[2 3 4]) < 1e-12);

        case "bilayer"
            materials_ok = isequal_tol(truth_values,[2 3]);

        case "inclusion"
            materials_ok = isequal_tol(truth_values,[2 4]);

        otherwise
            materials_ok = false;
    end

    geometry_contract_ok = true;

    if geometry == "bilayer"
        b = cfg.geometry.bilayer;

        geometry_contract_ok = ...
            logical(b.enabled) && ...
            max(abs(double(b.interface_point_m_xyz(:)).' - ...
                [0.035 0.024 0.035])) < 1e-12 && ...
            max(abs(double(b.normal_xyz(:)).' - ...
                [cosd(30) 0 sind(30)])) < 1e-12 && ...
            abs(double(b.negative_material.cs_m_s)-2) < 1e-12 && ...
            abs(double(b.positive_material.cs_m_s)-3) < 1e-12;

    elseif geometry == "inclusion"
        obj = cfg.geometry.objects(1);

        geometry_contract_ok = ...
            string(obj.type) == "sphere" && ...
            max(abs(double(obj.center_m_xyz(:)).' - ...
                [0.035 0.024 0.035])) < 1e-12 && ...
            abs(double(obj.radius_m)-0.0175) < 1e-12 && ...
            abs(double(obj.cs_m_s)-4) < 1e-12;
    end

    % -----------------------------------------------------
    % Wavefield-sample contract
    % -----------------------------------------------------
    wavefield = data.wavefield_zx;

    wavefield_finite = all(isfinite(real(wavefield)),"all") && ...
        all(isfinite(imag(wavefield)),"all");

    truth_aligned = ...
        isequal(size(wavefield),size(data.truth.cs_m_s_zx)) && ...
        numel(data.axes.x_m) == size(wavefield,2) && ...
        numel(data.axes.z_m) == size(wavefield,1);

    sample_frequency_ok = ...
        abs(double(data.frequency_hz)-500) < 1e-12;

    quantity_ok = lower(string(data.quantity)) == "displacement";

    truth_available = logical(data.has_truth);

    simulation_valid = logical(data.simulation_valid);
    analysis_ready = logical(data.analysis_ready);

    % -----------------------------------------------------
    % Physical validation summary
    % -----------------------------------------------------
    txt = string(fileread(validation_file));

    validation_file_ok = strlength(txt) > 0;

    % Keep these as text-derived flags without assuming all scenarios
    % contain identical summary fields.
    mentions_valid = contains(lower(txt),"valid=1") || ...
        contains(lower(txt),"valid = 1");

    % -----------------------------------------------------
    % Coordinate contract after bug fix
    % -----------------------------------------------------
    pred = reqml.predictSWS( ...
        sample_file, ...
        Model=fullfile( ...
            repo_root, ...
            "outputs","homogeneous_cartesian_q0_v2", ...
            "training","final_frozen_q0_v2","model_bundle.mat"), ...
        M=2, ...
        StepPixels=2);

    T = pred.patch_examples;

    cx = round(double(T.cx));
    cz = round(double(T.cz));

    expected_x = double(data.axes.x_m(cx));
    expected_z = double(data.axes.z_m(cz));

    coordinate_contract_ok = ...
        max(abs(double(T.x_center_m)-expected_x(:))) < 1e-12 && ...
        max(abs(double(T.z_center_m)-expected_z(:))) < 1e-12;

    req_metadata_ok = ...
        double(pred.metadata.M) == 2 && ...
        double(pred.metadata.cs_guess_m_s) == 3 && ...
        double(pred.metadata.step_pixels) == 2 && ...
        abs(double(pred.metadata.frequency_hz)-500) < 1e-12;

    overall_ok = all([ ...
        dimension_ok, ...
        grid_ok, ...
        spacing_ok, ...
        pml_ok, ...
        frequency_ok, ...
        source_contract_ok, ...
        materials_ok, ...
        geometry_contract_ok, ...
        wavefield_finite, ...
        truth_aligned, ...
        sample_frequency_ok, ...
        quantity_ok, ...
        truth_available, ...
        simulation_valid, ...
        analysis_ready, ...
        validation_file_ok, ...
        coordinate_contract_ok, ...
        req_metadata_ok]);

    rows(i).geometry = geometry;
    rows(i).run_id = run_id;
    rows(i).regime = regime;

    rows(i).f0_hz = double(src.f0_hz);
    rows(i).Nx = double(cfg.grid.Nx);
    rows(i).Ny = double(cfg.grid.Ny);
    rows(i).Nz = double(cfg.grid.Nz);

    rows(i).dx_mm = 1e3*double(cfg.grid.dx_m);
    rows(i).dy_mm = 1e3*double(cfg.grid.dy_m);
    rows(i).dz_mm = 1e3*double(cfg.grid.dz_m);

    rows(i).N = N;
    rows(i).P = P;
    rows(i).Pout = Pout;
    rows(i).omega_sr = omega;
    rows(i).unique_faces = double(g.unique_face_count);
    rows(i).D_eff = double(g.effective_angular_dimension);
    rows(i).directional_bias = double(g.directional_bias);

    rows(i).truth_materials = ...
        strjoin(string(truth_values),",");

    rows(i).wavefield_finite = wavefield_finite;
    rows(i).truth_aligned = truth_aligned;
    rows(i).simulation_valid = simulation_valid;
    rows(i).analysis_ready = analysis_ready;
    rows(i).validation_mentions_valid = mentions_valid;

    rows(i).dimension_ok = dimension_ok;
    rows(i).grid_ok = grid_ok;
    rows(i).spacing_ok = spacing_ok;
    rows(i).pml_ok = pml_ok;
    rows(i).frequency_ok = frequency_ok;
    rows(i).source_contract_ok = source_contract_ok;
    rows(i).materials_ok = materials_ok;
    rows(i).geometry_contract_ok = geometry_contract_ok;
    rows(i).coordinate_contract_ok = coordinate_contract_ok;
    rows(i).req_metadata_ok = req_metadata_ok;

    rows(i).overall_ok = overall_ok;

    fprintf( ...
        "%-12s %-12s %-24s | N=%2d P=%d | D=%.3f bias=%.3f | %s\n", ...
        geometry, ...
        regime, ...
        run_id, ...
        N, P, ...
        rows(i).D_eff, ...
        rows(i).directional_bias, ...
        passfail(overall_ok));

end

T = struct2table(rows);

T = sortrows(T,["geometry","regime","run_id"]);

csv_file = fullfile(out_root,"kwave_validation_v1_audit.csv");
writetable(T,csv_file);

txt_file = fullfile(out_root,"kwave_validation_v1_audit.txt");
fid = fopen(txt_file,"w");
cleanup = onCleanup(@() fclose(fid));

fprintf(fid,"REQ-ML k-Wave preliminary audit\n");
fprintf(fid,"===============================\n\n");
fprintf(fid,"Runs: %d\n",height(T));
fprintf(fid,"Passed: %d\n",nnz(T.overall_ok));
fprintf(fid,"Failed: %d\n\n",nnz(~T.overall_ok));

for i = 1:height(T)
    fprintf(fid, ...
        "%s | %s | %s | N=%d P=%d | D_eff=%.4f | bias=%.4f | %s\n", ...
        T.geometry(i), ...
        T.regime(i), ...
        T.run_id(i), ...
        T.N(i), ...
        T.P(i), ...
        T.D_eff(i), ...
        T.directional_bias(i), ...
        passfail(T.overall_ok(i)));
end

fprintf("\nAudit CSV:\n%s\n",csv_file);
fprintf("Audit TXT:\n%s\n",txt_file);

disp(T(:,{ ...
    "geometry","run_id","regime", ...
    "N","P","Pout","unique_faces","D_eff","directional_bias", ...
    "truth_materials","simulation_valid","coordinate_contract_ok", ...
    "overall_ok"}));

assert(all(T.overall_ok), ...
    "One or more preliminary k-Wave runs failed the audit.");

fprintf("\nAUDIT PASSED: %d/%d runs.\n", ...
    nnz(T.overall_ok),height(T));

end


function geometry = infer_geometry(run_dir)

p = lower(string(run_dir));

if contains(p,"/homogeneous/")
    geometry = "homogeneous";
elseif contains(p,"/bilayer/")
    geometry = "bilayer";
elseif contains(p,"/inclusion/")
    geometry = "inclusion";
else
    error("Could not infer geometry from %s",run_dir);
end

end


function regime = infer_regime(N,P,omega)

if N == 1 && P == 1 && abs(omega-0.01) < 1e-8
    regime = "directional";
elseif N == 16 && P == 4 && abs(omega-pi) < 1e-6
    regime = "intermediate";
elseif N == 32 && P == 8 && abs(omega-4*pi) < 1e-6
    regime = "diffuse_like";
else
    regime = "unknown";
end

end


function tf = isequal_tol(a,b)

a = sort(double(a(:)));
b = sort(double(b(:)));

tf = numel(a) == numel(b) && ...
    max(abs(a-b)) < 1e-12;

end


function name = get_last_folder(path_string)

[~,name] = fileparts(char(path_string));
name = string(name);

end


function s = passfail(tf)

if tf
    s = "PASS";
else
    s = "FAIL";
end

end
