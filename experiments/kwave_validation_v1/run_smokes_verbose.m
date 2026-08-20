function reports = run_smokes_verbose()

repo_root = string(fileparts(fileparts(fileparts(mfilename("fullpath")))));

sim_root = string(getenv("SWSIM_ROOT"));
assert(strlength(sim_root)>0,"SWSIM_ROOT is not defined.");

addpath(fullfile(sim_root,"src"));

campaign_root = fullfile( ...
    repo_root,"outputs","validation", ...
    "kwave_validation_v1","campaign");

files = [
    "smoke_homogeneous.json"
    "smoke_bilayer.json"
    "smoke_inclusion.json"
];

reports = cell(numel(files),1);

fprintf("\nk-Wave smoke execution\n");
fprintf("======================\n");

for i = 1:numel(files)

    f = fullfile(campaign_root,files(i));

    fprintf("\n[%d/%d] %s\n",i,numel(files),files(i));
    fprintf("------------------------------\n");

    t = tic;

    reports{i} = simcampaigns.runCampaign( ...
        f, ...
        Resume=true, ...
        ContinueOnError=false, ...
        Executor=@verbose_executor);

    dt = toc(t);

    fprintf("Completed in %.2f s = %.2f min\n",dt,dt/60);
    fprintf("%s\n",string(reports{i}.summary));
end

end


function outcome = verbose_executor(config,backend,run_directory)

fprintf("  starting | ");

if isfield(config,"scenario")
    fprintf("%s | ",string(config.scenario));
end

if isfield(config,"source")
    if isfield(config.source,"f0_hz")
        fprintf("f=%d Hz | ",double(config.source.f0_hz));
    end

    if isfield(config.source,"vibrator_count")
        fprintf("N=%d | ",double(config.source.vibrator_count));
    end

    if isfield(config.source,"exact_in_plane_sources")
        fprintf("P=%d | ",double(config.source.exact_in_plane_sources));
    end

    if isfield(config.source,"angular_support_solid_angle_sr")
        fprintf("alpha=%.4f | ", ...
            double(config.source.angular_support_solid_angle_sr)/(4*pi));
    end
end

t = tic;

outcome = simcampaigns.backends.executeRun( ...
    config,backend,run_directory);

fprintf("done %.2f s\n",toc(t));

end
