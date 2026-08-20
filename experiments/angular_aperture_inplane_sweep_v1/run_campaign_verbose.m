function report = run_campaign_verbose()

repo_root = string(fileparts(fileparts(fileparts(mfilename("fullpath")))));

sim_root = string(getenv("SWSIM_ROOT"));
assert(strlength(sim_root)>0, ...
    "SWSIM_ROOT is not defined.");

sim_src = fullfile(sim_root,"src");
assert(isfolder(sim_src), ...
    "Simulation framework src not found: %s",sim_src);

addpath(sim_src);

campaign_file = fullfile( ...
    repo_root, ...
    "outputs","validation", ...
    "angular_aperture_inplane_sweep_v1", ...
    "campaign","simulation_campaign.json");

assert(isfile(campaign_file), ...
    "Campaign file not found: %s",campaign_file);

fprintf("\nStarting angular aperture x in-plane sweep\n");
fprintf("==========================================\n");
fprintf("Simulation root : %s\n",sim_root);
fprintf("Campaign        : %s\n\n",campaign_file);

t0 = tic;

report = simcampaigns.runCampaign( ...
    campaign_file, ...
    Resume=true, ...
    ContinueOnError=false, ...
    Executor=@verbose_executor);

elapsed = toc(t0);

fprintf("\nCampaign complete.\n");
fprintf("Elapsed: %.2f s = %.2f min\n",elapsed,elapsed/60);
fprintf("%s\n",string(report.summary));

end


function outcome = verbose_executor(config,backend,run_directory)

persistent run_counter campaign_timer

if isempty(run_counter)
    run_counter = 0;
    campaign_timer = tic;
end

run_counter = run_counter + 1;

fprintf("[%03d] starting | ",run_counter);

if isfield(config,"medium") && isfield(config.medium,"background_cs_m_s")
    fprintf("cs=%.1f | ",double(config.medium.background_cs_m_s));
end

if isfield(config,"directions") && isfield(config.directions,"in_plane_count")
    fprintf("P=%d | ",double(config.directions.in_plane_count));
end

if isfield(config,"directions") && ...
        isfield(config.directions,"support") && ...
        isfield(config.directions.support,"solid_angle_sr")

    omega = double(config.directions.support.solid_angle_sr);
    fprintf("alpha=%.6f | ",omega/(4*pi));
end

t = tic;

outcome = simcampaigns.backends.executeRun( ...
    config,backend,run_directory);

dt = toc(t);
total_elapsed = toc(campaign_timer);

fprintf("done %.2f s | total %.1f s\n", ...
    dt,total_elapsed);

end
