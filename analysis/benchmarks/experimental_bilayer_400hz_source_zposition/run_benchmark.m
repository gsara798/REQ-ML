function result = run_benchmark(config_file)
%RUN_BENCHMARK Compare frozen-Q0 response to SOURCE-X axial contact position.
% Consumes three existing simulation results; never runs k-Wave or training.

if nargin<1 || isempty(config_file)
    root=fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))));
    config_file=fullfile(root,'configs','benchmarks', ...
        'experimental_bilayer_400hz_source_zposition.json');
end
root=string(fileparts(fileparts(fileparts(fileparts(mfilename('fullpath'))))));
sim_root=string(getenv('SWSIM_ROOT'));
if strlength(sim_root)==0
    sim_root=fullfile(fileparts(root),'shear-wave-simulation-framework');
end
addpath(fullfile(root,'src')); addpath(fullfile(sim_root,'src'));
c=jsondecode(fileread(config_file)); vars=struct('SWSIM_ROOT',sim_root);
model_file=reqml.config.resolveWorkspacePath(c.model_file, ...
    RepositoryRoot=root,Variables=vars);
output_root=reqml.config.resolveWorkspacePath(c.output_root, ...
    RepositoryRoot=root,Variables=vars);
baseline_root=reqml.config.resolveWorkspacePath(c.baseline_analysis_root, ...
    RepositoryRoot=root,Variables=vars);
preflight_root=reqml.config.resolveWorkspacePath(c.preflight_root, ...
    RepositoryRoot=root,Variables=vars);
if isfolder(output_root)
    error('reqml:benchmark:OutputExists', ...
        'Source-z-position output already exists; refusing overwrite: %s',output_root);
end
mkdir(output_root); mkdir(fullfile(output_root,'component_samples'));
mkdir(fullfile(output_root,'figures')); mkdir(fullfile(output_root,'spectra'));
copy_preflight(preflight_root,output_root);
bundle=load(model_file,'model','model_metadata','predictor_names');

products=cell(numel(c.positions),1); patch_parts=cell(numel(c.positions),1);
spectral_parts={}; radial_parts={}; angular_parts={}; ns=0;
for i=1:numel(c.positions)
    spec=c.positions(i); fprintf('Q0 analysis: %s (%d/%d)\n', ...
        spec.id,i,numel(c.positions));
    result_file=reqml.config.resolveWorkspacePath(spec.result_file, ...
        RepositoryRoot=root,Variables=vars);
    loaded=load(result_file,'result'); simulation=loaded.result;
    [uz,uz_file]=make_sample(simulation,"axial_total",output_root,i);
    [ux,ux_file]=make_sample(simulation,"lateral_total",output_root,i);
    q0=reqml.benchmarks.sourcePolarization.predictQ0Data(uz,bundle, ...
        M=c.req.M,StepPixels=c.req.step_pixels,UseParallel=true);
    p=reqml.benchmarks.experimentalBilayer.buildPatchTable("BILAYER", ...
        "REQ-ML Q0",q0.cs_map,q0.x_idx,q0.z_idx, ...
        q0.metadata.patch_width_pixels,uz,M=c.req.M, ...
        InterfaceZM=c.interface_z_m);
    p.source_position(:)=string(spec.id);
    p.incident_material(:)=string(spec.incident_material);
    p.material_side=repmat("soft",height(p),1);
    p.material_side(p.center_material_id==2)="stiff";
    patch_parts{i}=p;
    products{i}=struct('source_position',string(spec.id), ...
        'incident_material',string(spec.incident_material), ...
        'result_file',string(result_file),'simulation',simulation, ...
        'uz',uz,'ux',ux,'uz_file',uz_file,'ux_file',ux_file,'q0',q0);
    for r=1:numel(c.regions)
        ns=ns+1;
        [spectral_parts{ns},radial_parts{ns},angular_parts{ns}]= ...
            reqml.benchmarks.sourcePolarization.analyzeQ0RegionSpectrum( ...
            uz,ux,q0,c.regions(r),SourcePosition=spec.id, ...
            InterfaceZM=c.interface_z_m,M=c.req.M,CsGuess=c.req.cs_guess_m_s);
    end
end
patches=vertcat(patch_parts{:}); patches=mark_common_support(patches);
spectral_summary=vertcat(spectral_parts{:});
radial_curves=vertcat(radial_parts{:}); angular_curves=vertcat(angular_parts{:});

overall=summarize(patches,["source_position","material_side"]);
by_distance=summarize(patches,["source_position","material_side","distance_bin"]);
by_purity=summarize(patches,["source_position","material_side","purity_bin"]);
tidy=summarize(patches,["source_position","material_side", ...
    "distance_bin","purity_bin"]);
vector_summary=vector_metrics(products);
[axial_profiles,transition_summary]=axial_profiles_and_width(patches,c);
far_control=far_high_purity_control(patches,baseline_root);

writetable(patches,fullfile(output_root,'patch_results.csv'));
writetable(overall,fullfile(output_root,'summary_overall.csv'));
writetable(by_distance,fullfile(output_root,'summary_by_distance.csv'));
writetable(by_purity,fullfile(output_root,'summary_by_purity.csv'));
writetable(tidy,fullfile(output_root,'summary_distance_purity_tidy.csv'));
writetable(vector_summary,fullfile(output_root,'vector_wavefield_summary.csv'));
writetable(far_control,fullfile(output_root,'far_high_purity_control.csv'));
writetable(axial_profiles,fullfile(output_root,'axial_profiles.csv'));
writetable(transition_summary,fullfile(output_root,'transition_width_summary.csv'));
writetable(spectral_summary,fullfile(output_root,'spectral_region_summary.csv'));
writetable(radial_curves,fullfile(output_root,'spectra','radial_curves.csv'));
writetable(angular_curves,fullfile(output_root,'spectra','angular_curves.csv'));
make_figures(products,patches,by_distance,by_purity,far_control, ...
    axial_profiles,spectral_summary,radial_curves,output_root,c);
save(fullfile(output_root,'benchmark_results.mat'),'patches','overall', ...
    'by_distance','by_purity','tidy','vector_summary','far_control', ...
    'axial_profiles','transition_summary','spectral_summary','radial_curves', ...
    'angular_curves','c','-v7.3');
write_manifest(output_root,c,config_file,model_file,products,preflight_root);
result=struct('output_root',output_root,'patches',patches,'overall',overall, ...
    'by_distance',by_distance,'by_purity',by_purity,'tidy',tidy, ...
    'vector_summary',vector_summary,'far_control',far_control, ...
    'transition_summary',transition_summary,'spectral_summary',spectral_summary);
end

function [data,filename]=make_sample(simulation,component,root,index)
wavefield_sample=kwsim.samples.buildWavefieldSample(simulation, ...
    Quantity="displacement",Component=component);
filename=fullfile(root,'component_samples',sprintf('%02d_%s.mat',index,component));
save(filename,'wavefield_sample','-v7.3'); data=reqml.io.load_wavefield_sample(filename);
end

function p=mark_common_support(p)
[g,~]=findgroups(p.cx,p.cz); count=splitapply(@(v)nnz(v),p.valid,g);
npos=numel(unique(p.source_position)); p.common_support=p.valid&count(g)==npos;
end

function out=summarize(p,groups)
p=p(p.valid&p.common_support,:);
[g,values]=findgroups(p(:,groups)); out=values;
out.N=splitapply(@numel,p.estimate_m_s,g);
out.truth_m_s=splitapply(@median,p.truth_m_s,g);
out.mean_estimate_m_s=splitapply(@mean,p.estimate_m_s,g);
out.median_estimate_m_s=splitapply(@median,p.estimate_m_s,g);
out.std_estimate_m_s=splitapply(@std,p.estimate_m_s,g);
out.bias_m_s=splitapply(@mean,p.signed_error_m_s,g);
out.MAPE_percent=splitapply(@mean,p.absolute_error_percent,g);
end

function out=vector_metrics(products)
rows=cell(numel(products),1);
for i=1:numel(products)
    p=products{i}; ux=abs(p.ux.wavefield_zx); uz=abs(p.uz.wavefield_zx);
    ratio=ux./max(uz,eps); examples=p.q0.patch_examples;
    ang=NaN; bins=NaN;
    if ismember('ang_entropy',examples.Properties.VariableNames)
        a=double(examples.ang_entropy); ang=median(a,'omitnan');
        feature_config=reqml.config.default_feature_config(M=2,cs_guess=3);
        bins=median(exp(a*log(feature_config.Nang)),'omitnan');
    end
    rows{i}=table(p.source_position,numel(ux),median(uz,'all'), ...
        sqrt(mean(uz.^2,'all')),median(ux,'all'),sqrt(mean(ux.^2,'all')), ...
        median(ratio,'all'),prctile(ratio(:),25),prctile(ratio(:),75), ...
        ang,bins,'VariableNames',{'source_position','N_pixels', ...
        'median_abs_Uz','rms_abs_Uz','median_abs_Ux','rms_abs_Ux', ...
        'median_Ux_Uz_ratio','Ux_Uz_ratio_q25','Ux_Uz_ratio_q75', ...
        'median_angular_entropy','median_effective_angular_bins'});
end
out=vertcat(rows{:});
end

function [profiles,transition]=axial_profiles_and_width(p,c)
p=p(p.common_support,:); positions=unique(p.source_position,'stable'); parts={}; rows={};
for i=1:numel(positions)
    q=p(p.source_position==positions(i),:); [g,z]=findgroups(q.z_m);
    estimate=splitapply(@median,q.estimate_m_s,g); truth=splitapply(@median,q.truth_m_s,g);
    parts{i}=table(repmat(positions(i),numel(z),1),z,estimate,truth, ...
        'VariableNames',{'source_position','z_m','median_estimate_m_s','truth_m_s'});
    fraction=(estimate-1.74)/(3.05-1.74); mixed=z(fraction>=.1&fraction<=.9);
    width=NaN; if ~isempty(mixed),width=1e3*(max(mixed)-min(mixed));end
    [~,nearest]=min(abs(z-c.interface_z_m));
    rows{i}=table(positions(i),width,1e3*(z(nearest)-c.interface_z_m), ...
        'VariableNames',{'source_position','transition_10_90_width_mm', ...
        'nearest_profile_center_to_interface_mm'});
end
profiles=vertcat(parts{:}); transition=vertcat(rows{:});
end

function out=far_high_purity_control(p,baseline_root)
q=p(p.common_support&p.window_purity==1&p.absolute_distance_mm>8,:);
bilayer=summarize(q,["source_position","material_side"]);
bilayer.reference_type(:)="bilayer purity=1 and distance>8 mm";
old=readtable(fullfile(baseline_root,'patch_results.csv'),TextType='string');
old=old(old.source_polarization=="X"&old.observed_component=="Uz"& ...
    old.estimator=="REQ-ML Q0"&ismember(old.condition,["H_SOFT","H_STIFF"]),:);
if ismember('common_support',old.Properties.VariableNames)
    support=old.common_support;
    if isnumeric(support),support=support~=0;elseif ~islogical(support),support=lower(string(support))=="true";end
    old=old(support,:);
end
old.material_side=repmat("soft",height(old),1); old.material_side(old.condition=="H_STIFF")="stiff";
old.source_position=repmat("HOMOGENEOUS_SOURCE_X",height(old),1);
hom=summarize(old,["source_position","material_side"]);
hom.reference_type(:)="homogeneous SOURCE-X reference";
out=[bilayer;hom];
end

function copy_preflight(preflight,root)
files=["source_position_geometry.csv","source_position_geometry.json"];
for f=files
    source=fullfile(preflight,f); if ~isfile(source),error('reqml:benchmark:MissingPreflight','Missing %s',source);end
    copyfile(source,fullfile(root,f));
end
source=fullfile(preflight,'source_position_geometry.png');
if ~isfile(source),error('reqml:benchmark:MissingPreflight','Missing %s',source);end
copyfile(source,fullfile(root,'figures','source_position_geometry.png'));
end

function make_figures(products,p,distance,purity,far,profiles,spectral,radial,root,c)
folder=fullfile(root,'figures'); names=string({c.positions.id});
max_uz=max(cellfun(@(x)max(abs(x.uz.wavefield_zx),[],'all'),products));
max_ux=max(cellfun(@(x)max(abs(x.ux.wavefield_zx),[],'all'),products));
fig=figure('Visible','off','Color','w','Position',[50 50 1550 950]);
tiledlayout(3,5,'TileSpacing','compact','Padding','compact');
for i=1:3
    x=1e3*products{i}.uz.axes.x_m; z=1e3*products{i}.uz.axes.z_m;
    ux=products{i}.ux.wavefield_zx; uz=products{i}.uz.wavefield_zx;
    maps={abs(uz),cos(angle(uz)),abs(ux),cos(angle(ux)), ...
        20*log10(abs(ux)./max(abs(uz),eps))};
    titles=["|Uz|","cos phase Uz","|Ux|","cos phase Ux","20log10 |Ux|/|Uz|"];
    for j=1:5
        nexttile((i-1)*5+j); imagesc(x,z,maps{j}); axis image;
        if j==1,clim([0 max_uz]);elseif j==3,clim([0 max_ux]);elseif ismember(j,[2 4]),clim([-1 1]);else,clim([-30 30]);end
        colorbar; title(names(i)+" "+titles(j),'Interpreter','none'); xlabel('x (mm)');ylabel('z (mm)');
    end
end
sgtitle('SOURCE-X vector wavefields: common physical scales'); save_png(fig,folder,'vector_wavefields');

fig=figure('Visible','off','Color','w','Position',[50 50 1300 430]); tiledlayout(1,3,'TileSpacing','compact');
for i=1:3
    q=p(p.source_position==names(i),:); [map,x,z]=reqml.benchmarks.sourcePolarization.patchesToGrid(q);
    nexttile; imagesc(x,z,map); axis image; clim([1.4 3.4]);colorbar;
    title(names(i),'Interpreter','none');xlabel('x (mm)');ylabel('z (mm)');
end
sgtitle('Frozen Q0 M=2, SOURCE-X observed through Uz');save_png(fig,folder,'q0_sws_maps');

plot_binned(distance,'distance_bin',folder,'error_vs_distance');
plot_binned(purity,'purity_bin',folder,'error_vs_purity');

fig=figure('Visible','off','Color','w','Position',[50 50 1050 470]);
cats=far.source_position+" "+far.material_side;
bar(categorical(cats,cats),far.MAPE_percent);ylabel('MAPE (%)');grid on;
title('High-purity far-field versus homogeneous SOURCE-X');xtickangle(25);save_png(fig,folder,'far_high_purity_control');

fig=figure('Visible','off','Color','w');hold on;
for i=1:3
    q=profiles(profiles.source_position==names(i),:);
    plot(1e3*q.z_m,q.median_estimate_m_s,'LineWidth',1.6,'DisplayName',names(i));
end
yline(1.74,'k:');yline(3.05,'k:');xline(19,'k--');grid on;legend('Interpreter','none');
xlabel('z (mm)');ylabel('median Q0 SWS (m/s)');save_png(fig,folder,'axial_profiles');

regions=unique(spectral.region,'stable');
fig=figure('Visible','off','Color','w','Position',[50 50 1400 900]); tiledlayout(4,2,'TileSpacing','compact');
for r=1:numel(regions)
    nexttile;hold on;
    for i=1:3
        q=radial(radial.region==regions(r)&radial.source_position==names(i),:);
        plot(q.k_rad_m,q.normalized_energy,'LineWidth',1.4,'DisplayName',names(i));
        xline(median(q.k_q),':','Color',[.4 .4 .4],'HandleVisibility','off');
    end
    xline(2*pi*400/1.74,'k--','k soft');xline(2*pi*400/3.05,'k:','k stiff');grid on;
    title(regions(r),'Interpreter','none');ylabel('normalized E(k)');
    nexttile;hold on;
    for i=1:3
        q=radial(radial.region==regions(r)&radial.source_position==names(i),:);
        plot(q.k_rad_m,q.cumulative_energy,'LineWidth',1.4,'DisplayName',names(i));
        s=spectral(spectral.region==regions(r)&spectral.source_position==names(i),:);
        plot(s.k_q,s.q_pred,'o','HandleVisibility','off');
    end
    ylim([0 1]);grid on;ylabel('C(k)');
end
legend('Location','best','Interpreter','none');sgtitle('Source-position spectral comparison on Uz');
save_png(fig,folder,'spectral_overlays');
end

function plot_binned(t,field,folder,stem)
fig=figure('Visible','off','Color','w','Position',[50 50 1100 450]); tiledlayout(1,2);
for material=["soft","stiff"]
    nexttile;hold on;q=t(t.material_side==material,:); cats=unique(string(q.(field)),'stable');
    for position=unique(q.source_position,'stable').'
        y=nan(size(cats));s=q(q.source_position==position,:);
        for k=1:numel(cats),row=s(string(s.(field))==cats(k),:);if ~isempty(row),y(k)=row.MAPE_percent(1);end,end
        plot(1:numel(cats),y,'-o','LineWidth',1.4,'DisplayName',position);
    end
    xticks(1:numel(cats));xticklabels(cats);title(material);ylabel('MAPE (%)');grid on;
end
legend('Interpreter','none');save_png(fig,folder,stem);
end

function save_png(fig,folder,stem)
exportgraphics(fig,fullfile(folder,string(stem)+".png"),'Resolution',220);close(fig);
end

function write_manifest(root,c,config_file,model_file,products,preflight)
runtimes=zeros(numel(products),1); files=strings(numel(products),1);
for i=1:numel(products),runtimes(i)=double(products{i}.simulation.runtime_s);files(i)=products{i}.result_file;end
manifest=struct('schema_name','reqml_source_zposition_benchmark_result', ...
    'schema_version','1.0','benchmark_id',string(c.benchmark_id), ...
    'source_config',string(config_file),'model_file',string(model_file), ...
    'q0_M',c.req.M,'q0_step_pixels',c.req.step_pixels, ...
    'AIA_status','not run by explicit scope','theory_discrete_status','not run', ...
    'simulation_result_files',files,'simulation_runtime_s',runtimes, ...
    'new_simulation_runtime_s',sum(runtimes(2:3)), ...
    'preflight_geometry',fullfile(preflight,'source_position_geometry.json'), ...
    'created_utc',string(datetime('now','TimeZone','UTC')));
fid=fopen(fullfile(root,'manifest.json'),'w');cleanup=onCleanup(@()fclose(fid));
fprintf(fid,'%s\n',jsonencode(manifest,PrettyPrint=true));
end
