function result = run_benchmark(config_file, refresh_derived_outputs)
%RUN_BENCHMARK Run the frozen-Q0, theory-discrete REQ, and AIA comparison.
% This consumes existing k-Wave samples and never simulates or trains.

if nargin<1 || isempty(config_file)
    root=fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))));
    config_file=fullfile(root,'configs','benchmarks', ...
        'experimental_bilayer_400hz.json');
end
if nargin<2, refresh_derived_outputs=false; end
root=string(fileparts(fileparts(fileparts(fileparts(mfilename('fullpath'))))));
addpath(fullfile(root,'src'));
addpath(fullfile(root,'analysis','benchmarks','experimental_bilayer_400hz','aia'));
config=jsondecode(fileread(config_file));
simulation_root=string(getenv('SWSIM_ROOT'));
if strlength(simulation_root)==0
    simulation_root=fullfile(fileparts(root),'shear-wave-simulation-framework');
end
variables=struct('SWSIM_ROOT',simulation_root);
model_file=reqml.config.resolveWorkspacePath(config.model_file, ...
    RepositoryRoot=root,Variables=variables);
output_root=reqml.config.resolveWorkspacePath(config.output_root, ...
    RepositoryRoot=root,Variables=variables);
if isfolder(output_root)
    cache_file=fullfile(output_root,'benchmark_results.mat');
    manifest_file=fullfile(output_root,'manifest.json');
    if isfile(cache_file) && ...
            (~isfile(manifest_file) || refresh_derived_outputs)
        cached=load(cache_file,'patches','overall','by_distance', ...
            'by_purity','config');
        patches=reqml.benchmarks.experimentalBilayer.markCommonSupport( ...
            cached.patches);
        overall=reqml.benchmarks.experimentalBilayer.summarizePatches(patches, ...
            ["condition","estimator","preprocessing","M", ...
            "center_material_id"]);
        by_distance=reqml.benchmarks.experimentalBilayer.summarizePatches( ...
            patches(patches.condition=="BILAYER",:), ...
            ["condition","estimator","preprocessing","M", ...
            "center_material_id","distance_bin"]);
        by_purity=reqml.benchmarks.experimentalBilayer.summarizePatches( ...
            patches(patches.condition=="BILAYER",:), ...
            ["condition","estimator","preprocessing","M", ...
            "center_material_id","purity_bin"]);
        config=cached.config;
        writetable(patches,fullfile(output_root,'patch_results.csv'));
        writetable(overall,fullfile(output_root,'summary_overall.csv'));
        writetable(by_distance,fullfile(output_root,'summary_by_distance.csv'));
        writetable(by_purity,fullfile(output_root,'summary_by_purity.csv'));
        save(cache_file,'patches','overall','by_distance','by_purity', ...
            'config','-v7.3');
        samples=cell(numel(config.conditions),1);
        for index=1:numel(config.conditions)
            sample_file=reqml.config.resolveWorkspacePath( ...
                config.conditions(index).sample_file,RepositoryRoot=root, ...
                Variables=variables);
            samples{index}=reqml.io.load_wavefield_sample(sample_file);
        end
        figures_folder=fullfile(output_root,'figures');
        if ~isfolder(figures_folder), mkdir(figures_folder); end
        make_figures(samples,patches,overall,by_distance,by_purity, ...
            figures_folder);
        write_manifest(output_root,config,config_file,model_file);
        result=struct('patches',patches,'overall',overall, ...
            'by_distance',by_distance,'by_purity',by_purity, ...
            'output_root',output_root);
        return
    end
    error('reqml:benchmark:OutputExists', ...
        'Complete or non-resumable benchmark output already exists: %s', ...
        output_root);
end
mkdir(output_root); mkdir(fullfile(output_root,'figures'));

patch_parts=cell(numel(config.conditions)*3,1); samples=cell(numel(config.conditions),1);
part=0;
for index=1:numel(config.conditions)
    condition=string(config.conditions(index).id);
    sample_file=reqml.config.resolveWorkspacePath( ...
        config.conditions(index).sample_file,RepositoryRoot=root,Variables=variables);
    data=reqml.io.load_wavefield_sample(sample_file); samples{index}=data;
    interface_z=NaN; if condition=="BILAYER", interface_z=config.interface_z_m; end

    q0=reqml.predictSWS(sample_file,Model=model_file,M=config.req.M, ...
        StepPixels=config.req.step_pixels,UseParallel=true);
    e=q0.patch_examples; x_idx=unique(double(e.cx),'stable').';
    z_idx=unique(double(e.cz),'stable');
    part=part+1;
    patch_parts{part}=reqml.benchmarks.experimentalBilayer.buildPatchTable( ...
        condition,"REQ-ML Q0",q0.cs_map,x_idx,z_idx, ...
        q0.metadata.patch_width_pixels,data,M=config.req.M, ...
        InterfaceZM=interface_z);

    physical=struct('dx',data.dx_m,'dz',data.dz_m, ...
        'f0',data.frequency_hz,'cs_bg',config.req.cs_guess_m_s);
    features=reqml.config.default_feature_config('M',config.req.M, ...
        'cs_guess',config.req.cs_guess_m_s);
    theory=reqml.estimators.req_estimator_map(data.wavefield_zx,physical,features, ...
        'StepX',config.req.step_pixels,'StepZ',config.req.step_pixels, ...
        'QuantileMode','theory_discrete', ...
        'TheoryFieldType',config.theory_discrete.field_type, ...
        'TheoryMode',config.theory_discrete.theory_mode, ...
        'ReturnFeatures',false,'ReturnFeatureTable',false, ...
        'StoreReqCurves',false,'UseWindowParfor',true);
    part=part+1;
    patch_parts{part}=reqml.benchmarks.experimentalBilayer.buildPatchTable( ...
        condition,"REQ theory-discrete",theory.cs_map,theory.x_idx,theory.z_idx, ...
        theory.win_size,data,M=config.req.M,InterfaceZM=interface_z);

    [aia_cs,~,~,~,aia_diag]=aia_estimator_RSWE(data.wavefield_zx, ...
        data.dx_m,data.dz_m,data.frequency_hz,'M',config.aia.M, ...
        'cs_guess',config.aia.cs_guess_m_s,'StepX',config.aia.step_pixels, ...
        'StepZ',config.aia.step_pixels,'EdgeMode',config.aia.edge_mode, ...
        'NumAngles',config.aia.num_angles,'AutoDecimate',config.aia.auto_decimate, ...
        'UseParfor',config.aia.use_parfor);
    part=part+1;
    patch_parts{part}=reqml.benchmarks.experimentalBilayer.buildPatchTable( ...
        condition,"AIA source-faithful",aia_cs,aia_diag.cx_list,aia_diag.cz_list, ...
        [aia_diag.win_z aia_diag.win_x],data,M=config.aia.M,InterfaceZM=interface_z);
end
patches=vertcat(patch_parts{1:part});
patches=reqml.benchmarks.experimentalBilayer.markCommonSupport(patches);
overall=reqml.benchmarks.experimentalBilayer.summarizePatches(patches, ...
    ["condition","estimator","preprocessing","M","center_material_id"]);
by_distance=reqml.benchmarks.experimentalBilayer.summarizePatches( ...
    patches(patches.condition=="BILAYER",:), ...
    ["condition","estimator","preprocessing","M","center_material_id","distance_bin"]);
by_purity=reqml.benchmarks.experimentalBilayer.summarizePatches( ...
    patches(patches.condition=="BILAYER",:), ...
    ["condition","estimator","preprocessing","M","center_material_id","purity_bin"]);
writetable(patches,fullfile(output_root,'patch_results.csv'));
writetable(overall,fullfile(output_root,'summary_overall.csv'));
writetable(by_distance,fullfile(output_root,'summary_by_distance.csv'));
writetable(by_purity,fullfile(output_root,'summary_by_purity.csv'));
save(fullfile(output_root,'benchmark_results.mat'), ...
    'patches','overall','by_distance','by_purity','config','-v7.3');
make_figures(samples,patches,overall,by_distance,by_purity, ...
    fullfile(output_root,'figures'));
write_manifest(output_root,config,config_file,model_file);
result=struct('patches',patches,'overall',overall,'by_distance',by_distance, ...
    'by_purity',by_purity,'output_root',output_root);
end

function write_manifest(output_root,config,config_file,model_file)
manifest=struct('schema_name','reqml_experimental_bilayer_benchmark_result', ...
    'schema_version','1.0','benchmark_id',string(config.benchmark_id), ...
    'source_config',string(config_file),'model_file',model_file, ...
    'fixed_q_status','not_run_no_traceable_experimental_fixed_q', ...
    'fixed_q_substitute','REQ theory-discrete', ...
    'created_utc',string(datetime('now','TimeZone','UTC')));
fid=fopen(fullfile(output_root,'manifest.json'),'w');
cleanup=onCleanup(@() fclose(fid)); fprintf(fid,'%s\n',jsonencode(manifest,PrettyPrint=true));
end

function make_figures(samples,p,overall,distance,purity,folder)
labels=["H_SOFT","H_STIFF","BILAYER"];
fig=figure('Visible','off','Color','w','Position',[100 100 1200 380]);
tiledlayout(1,3,'TileSpacing','compact');
for i=1:3
    nexttile;
    imagesc(1e3*samples{i}.axes.x_m,1e3*samples{i}.axes.z_m, ...
        samples{i}.truth.cs_m_s_zx);
    axis image; clim([1.4 3.4]); colorbar;
    title(labels(i),'Interpreter','none');
end
sgtitle('Exact SWS truth (m/s)'); savefigs(fig,folder,'truth_maps');
fig=figure('Visible','off','Color','w','Position',[100 100 1200 700]);
tiledlayout(2,3,'TileSpacing','compact');
amplitude_limit=max(cellfun(@(s) max(abs(s.wavefield_zx),[],'all'),samples));
for i=1:3
    U=samples{i}.wavefield_zx;
    nexttile;
    imagesc(1e3*samples{i}.axes.x_m,1e3*samples{i}.axes.z_m,abs(U));
    axis image; clim([0 amplitude_limit]); colorbar;
    title(labels(i)+" amplitude",'Interpreter','none');
    nexttile(i+3);
    imagesc(1e3*samples{i}.axes.x_m,1e3*samples{i}.axes.z_m, ...
        cos(angle(U)));
    axis image; clim([-1 1]); colorbar;
    title(labels(i)+" cos(phase)",'Interpreter','none');
end
savefigs(fig,folder,'wavefields_amplitude_phase');
estimators=unique(p.estimator,'stable'); stems=["reqml_maps","theory_discrete_maps","aia_maps"];
for e=1:numel(estimators)
    fig=figure('Visible','off','Color','w','Position',[100 100 1200 380]);
    tiledlayout(1,3);
    for i=1:3
        nexttile;
        q=p(p.estimator==estimators(e)&p.condition==labels(i),:);
        scatter(1e3*q.x_m,1e3*q.z_m,12,q.estimate_m_s,'filled');
        axis ij equal tight; clim([1.4 3.4]); colorbar;
        title(labels(i),'Interpreter','none');
        xlabel('x (mm)'); ylabel('z (mm)');
    end
    sgtitle(estimators(e)+' SWS (m/s)'); savefigs(fig,folder,stems(e));
end
fig=figure('Visible','off','Color','w','Position',[100 100 1200 380]);
tiledlayout(1,3);
for e=1:numel(estimators)
    nexttile;
    q=p(p.condition=="BILAYER"&p.estimator==estimators(e),:);
    scatter(1e3*q.x_m,1e3*q.z_m,12,q.signed_error_m_s,'filled');
    axis ij equal tight; clim([-1 1]); colorbar; title(estimators(e));
end
sgtitle('Bilayer signed SWS error (m/s)'); savefigs(fig,folder,'bilayer_error_maps');
fig=figure('Visible','off','Color','w'); hold on;
for e=1:numel(estimators)
    q=p(p.condition=="BILAYER"&p.estimator==estimators(e)&p.common_support,:);
    [g,z]=findgroups(q.z_m);
    plot(1e3*z,splitapply(@median,q.estimate_m_s,g),'LineWidth',1.5);
end
q=p(p.condition=="BILAYER"&p.common_support,:);
[g,z]=findgroups(q.z_m);
plot(1e3*z,splitapply(@median,q.truth_m_s,g),'k--','LineWidth',2);
xline(19,':'); grid on;
legend([estimators;"truth"],'Location','best'); xlabel('z (mm)'); ylabel('SWS (m/s)');
savefigs(fig,folder,'axial_profile');
plot_group_metric(distance,'distance_bin',estimators,folder,'error_vs_distance');
plot_group_metric(purity,'purity_bin',estimators,folder,'error_vs_purity');
comparison_labels=overall.condition+" material "+string(overall.center_material_id);
comparison_categories=unique(comparison_labels,'stable');
comparison_values=nan(numel(comparison_categories),numel(estimators));
for e=1:numel(estimators)
    for c=1:numel(comparison_categories)
        q=overall(overall.estimator==estimators(e) & ...
            comparison_labels==comparison_categories(c),:);
        if ~isempty(q), comparison_values(c,e)=q.MAPE_percent(1); end
    end
end
fig=figure('Visible','off','Color','w','Position',[100 100 1000 500]);
bar(categorical(comparison_categories,comparison_categories), ...
    comparison_values,'grouped');
ylabel('MAPE (%)'); title('Homogeneous vs bilayer material estimates');
legend(estimators,'Location','best'); grid on;
savefigs(fig,folder,'homogeneous_vs_bilayer');
end

function plot_group_metric(t,field,estimators,folder,stem)
fig=figure('Visible','off','Color','w'); hold on;
cats=unique(string(t.(field)),'stable');
for e=1:numel(estimators)
    y=nan(size(cats));
    for c=1:numel(cats)
        q=t(t.estimator==estimators(e)&string(t.(field))==cats(c),:);
        if ~isempty(q), y(c)=mean(q.MAPE_percent,'omitnan'); end
    end
    plot(1:numel(cats),y,'-o','LineWidth',1.5);
end
xticks(1:numel(cats)); xticklabels(cats); ylabel('MAPE (%)'); grid on; legend(estimators);
savefigs(fig,folder,stem);
end

function savefigs(fig,folder,stem)
filename=fullfile(folder,string(stem)+".png");
exportgraphics(fig,filename,'Resolution',220); close(fig);
end
