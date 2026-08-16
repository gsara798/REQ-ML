function result = run_experimental_multifrequency_q0_pre_ius(options)
%RUN_EXPERIMENTAL_MULTIFREQUENCY_Q0_PRE_IUS Limited frozen-Q0 consistency audit.
% Uses existing experimental data only. It may materialize the validated
% isotropic/donut wavefield_sample contract, but never runs another estimator.

arguments
    options.ExperimentalRoot {mustBeTextScalar} = ...
        "/Users/sara/Library/CloudStorage/Box-Box/Research/Papers/REQ/data/Experiments"
    options.ModelFile {mustBeTextScalar} = ""
    options.OutputRoot {mustBeTextScalar} = ""
    options.UseParallel (1,1) logical = true
end
root=string(fileparts(fileparts(fileparts(mfilename('fullpath')))));
addpath(fullfile(root,'src'));
rswe_root="/Users/sara/Library/CloudStorage/Box-Box/Research/clean_codes_RSWE";
if ~isfolder(rswe_root)
    error('reqml:diagnostics:MissingRSWE', ...
        'Validated experimental preprocessing package is unavailable: %s',rswe_root);
end
addpath(rswe_root);
model_file=resolve_default(options.ModelFile,fullfile(root,'outputs', ...
    'homogeneous_cartesian_q0_v2','training','final_frozen_q0_v2', ...
    'model_bundle.mat'));
output_root=resolve_default(options.OutputRoot,fullfile(root,'outputs', ...
    'diagnostics','experimental_multifrequency_q0_pre_ius_v1'));
if ~isfile(model_file),error('reqml:diagnostics:MissingModel', ...
        'Frozen model is unavailable: %s',model_file);end

completed_manifest=fullfile(output_root,'manifest.json');
if isfile(completed_manifest)
    error('reqml:diagnostics:OutputExists', ...
        'Completed diagnostic already exists; refusing overwrite: %s',output_root);
end
for folder=[output_root,fullfile(output_root,'figures'),fullfile(output_root,'samples')]
    if ~isfolder(folder),mkdir(folder);end
end

inventory=discover_conditions(string(options.ExperimentalRoot));
writetable(inventory,fullfile(output_root,'discovery_inventory.csv'));
disp('Experimental multifrequency discovery inventory:');
disp(inventory(:,{'phantom','field_type','acquisition_id','frequency_hz', ...
    'has_pv_cal','has_data_filt','has_existing_sample','has_existing_q0', ...
    'planned_action'}));
rois=roi_definitions();
writetable(rois,fullfile(output_root,'roi_definitions.csv'));

checkpoint_file=fullfile(output_root,'analysis_checkpoint.mat');
parts=cell(height(inventory),1);errors=strings(height(inventory),1);
generated_sample=false(height(inventory),1);sample_files=strings(height(inventory),1);
if isfile(checkpoint_file)
    saved=load(checkpoint_file,'parts','errors','generated_sample','sample_files');
    parts=saved.parts;errors=saved.errors;generated_sample=saved.generated_sample;
    sample_files=saved.sample_files;
end

for i=1:height(inventory)
    if ~isempty(parts{i})||strlength(errors(i))>0,continue,end
    fprintf('\n[%d/%d] %s %s %s %g Hz\n',i,height(inventory), ...
        inventory.phantom(i),inventory.field_type(i), ...
        inventory.acquisition_id(i),inventory.frequency_hz(i));
    try
        [sample_file,was_generated]=resolve_sample(inventory(i,:),output_root);
        prediction=reqml.predictSWS(sample_file,Model=model_file,M=2, ...
            StepPixels=1,UseParallel=options.UseParallel);
        data=reqml.io.load_wavefield_sample(sample_file);
        condition_rois=rois(rois.phantom==inventory.phantom(i),:);
        parts{i}=summarize_prediction(prediction,data,inventory(i,:),condition_rois);
        sample_files(i)=sample_file;generated_sample(i)=was_generated;
    catch exception
        errors(i)=string(getReport(exception,'extended','hyperlinks','off'));
        warning('reqml:diagnostics:ConditionFailed', ...
            'Condition failed and will be reported: %s',exception.message);
    end
    save(checkpoint_file,'parts','errors','generated_sample','sample_files','-v7.3');
end

successful=~cellfun(@isempty,parts);
if ~any(successful)
    error('reqml:diagnostics:NoSuccessfulConditions', ...
        'No experimental condition produced a valid frozen-Q0 summary.');
end
summary=vertcat(parts{successful});
inventory.sample_file_used=sample_files;
inventory.sample_generated=generated_sample;
inventory.analysis_status=repmat("completed",height(inventory),1);
inventory.analysis_status(~successful)="failed";
inventory.analysis_error=errors;
writetable(inventory,fullfile(output_root,'discovery_inventory.csv'));
writetable(summary,fullfile(output_root,'experimental_q0_frequency_summary.csv'));
interpretation=frequency_consistency(summary);
writetable(interpretation,fullfile(output_root, ...
    'frequency_consistency_interpretation.csv'));
save(fullfile(output_root,'experimental_q0_frequency_summary.mat'), ...
    'summary','inventory','rois','interpretation','-v7.3');

make_material_figure(summary,"soft","median_sws_m_s", ...
    fullfile(output_root,'figures','soft_sws_vs_frequency.png'));
make_material_figure(summary,"hard","median_sws_m_s", ...
    fullfile(output_root,'figures','hard_sws_vs_frequency.png'));
make_material_figure(summary,"soft","median_q", ...
    fullfile(output_root,'figures','soft_q_vs_frequency.png'));
make_material_figure(summary,"hard","median_q", ...
    fullfile(output_root,'figures','hard_q_vs_frequency.png'));
make_per_phantom_figure(summary,fullfile(output_root,'figures', ...
    'per_phantom_sws_vs_frequency.png'));
normalized=normalized_to_400(summary);
if ~isempty(normalized)
    writetable(normalized,fullfile(output_root,'normalized_within_phantom.csv'));
    make_normalized_figure(normalized,fullfile(output_root,'figures', ...
        'normalized_within_phantom_sws_vs_frequency.png'));
end

bundle=load(model_file,'model','model_metadata','predictor_names');
manifest=struct('schema_name','reqml_experimental_multifrequency_pre_ius', ...
    'schema_version','1.0','model_file',model_file, ...
    'model_id',string(bundle.model.model_id), ...
    'model_provenance',bundle.model_metadata,'predictor_names', ...
    string(bundle.predictor_names(:)),'M',2,'StepPixels',1, ...
    'UseParallel',options.UseParallel,'cs_guess_m_s',3, ...
    'preprocessing',struct('lockin_cycles',12,'donut_cs_min_m_s',1, ...
    'donut_cs_max_m_s',10,'donut_taper_rel',.06, ...
    'axial_decimation_factor',2,'required_grid','dz=dx'), ...
    'roi_definitions',table2struct(rois),'condition_inventory', ...
    table2struct(inventory),'missing_or_failed_conditions', ...
    table2struct(inventory(~successful,:)),'created_utc', ...
    string(datetime('now','TimeZone','UTC')));
write_json(completed_manifest,manifest);
delete(checkpoint_file);
disp('Frozen-Q0 experimental frequency summary:');disp(summary);
disp('Within-series frequency consistency:');disp(interpretation);
result=struct('output_root',output_root,'summary',summary, ...
    'inventory',inventory,'rois',rois,'interpretation',interpretation, ...
    'normalized',normalized,'manifest',manifest);
end

function value=resolve_default(value,default_value)
value=string(value);if strlength(value)==0,value=string(default_value);end
end

function t=discover_conditions(experimental_root)
specs={ ...
    "H5","single-point","h5_single", "2026Feb27_homo_5perc_sp"; ...
    "H10","single-point","h10_single","2026Feb27_homo_10perc_sp"; ...
    "BILAYER","single-point","bilayer_single","2026Feb27_dl_sp_M2"; ...
    "H5","reverberant","h5_reverb_a","2026Feb27_homo_5perc_rswe"; ...
    "H5","reverberant","h5_reverb_b","2026Feb27_homo_5perc_rswe_test2"; ...
    "H10","reverberant","h10_reverb","2026Feb27_homo_10perc_rswe"; ...
    "BILAYER","reverberant","bilayer_reverb","2026Feb27_dl_rswe_M2"};
rows=cell(128,1);n=0;
for si=1:size(specs,1)
    experiment_folder=fullfile(experimental_root,specs{si,4});
    dirs=dir(fullfile(experiment_folder,'Results_*Hz'));
    dirs=dirs([dirs.isdir]);
    for di=1:numel(dirs)
        tokens=regexp(dirs(di).name,'Results_(test\d+)_(\d+)Hz','tokens','once');
        if isempty(tokens),continue,end
        n=n+1;result_folder=string(fullfile(dirs(di).folder,dirs(di).name));
        frequency=str2double(tokens{2});
        data_file=fullfile(result_folder,sprintf('data_freq_%d',frequency),'data_filt.mat');
        pv_file=fullfile(result_folder,'pv_cal.mat');
        sample_match=dir(fullfile(result_folder,'wavefield_sample*isotropic_donut.mat'));
        q0_match=dir(fullfile(result_folder,'REQML*results.mat'));
        sample_file="";if ~isempty(sample_match)
            sample_file=string(fullfile(sample_match(1).folder,sample_match(1).name));end
        q0_file="";if ~isempty(q0_match)
            q0_file=string(fullfile(q0_match(1).folder,q0_match(1).name));end
        available=isfile(data_file)&&isfile(pv_file);
        action="missing_inputs";
        if available&&strlength(sample_file)>0,action="reuse_sample_predict_q0";
        elseif available,action="generate_sample_predict_q0";end
        series=string(specs{si,3})+"_"+string(tokens{1});
        rows{n}=table(string(specs{si,1}),string(specs{si,2}),series, ...
            string(tokens{1}),frequency,string(experiment_folder),result_folder, ...
            string(pv_file),string(data_file),isfile(pv_file),isfile(data_file), ...
            strlength(sample_file)>0,strlength(q0_file)>0,sample_file,q0_file,action, ...
            'VariableNames',{'phantom','field_type','acquisition_id','test_id', ...
            'frequency_hz','experiment_folder','result_folder','pv_cal_file', ...
            'data_filt_file','has_pv_cal','has_data_filt','has_existing_sample', ...
            'has_existing_q0','existing_sample_file','existing_q0_file','planned_action'});
    end
end
rows=rows(1:n);t=vertcat(rows{:});
t=sortrows(t,{'field_type','phantom','acquisition_id','frequency_hz'});
end

function t=roi_definitions()
t=table(["H5";"H10";"BILAYER";"BILAYER"], ...
    ["homogeneous_soft";"homogeneous_hard";"bilayer_soft";"bilayer_hard"], ...
    ["soft";"hard";"soft";"hard"],[12.5;12;12;12],[27.5;26;26;26], ...
    [12.5;18;12;24],[27.5;29;15;27], ...
    ["historical H5 15x15 mm ROI"; ...
    "fixed envelope of established H10 LOW and GOOD regions"; ...
    "established bilayer ROI away from interface"; ...
    "established bilayer ROI away from interface"], ...
    'VariableNames',{'phantom','roi_id','material_class','x_lower_mm', ...
    'x_upper_mm','z_lower_mm','z_upper_mm','provenance'});
end

function [sample_file,generated]=resolve_sample(row,output_root)
if row.has_existing_sample
    sample_file=row.existing_sample_file;generated=false;return
end
safe_name=sprintf('%s_%s_%dHz_isotropic_donut.mat', ...
    lower(row.phantom),row.acquisition_id,row.frequency_hz);
sample_file=fullfile(output_root,'samples',safe_name);generated=true;
if isfile(sample_file),return,end
pv=load(row.pv_cal_file,'dinf');raw=load(row.data_filt_file,'u_temp_filt');
if ~isfield(pv,'dinf')||~isfield(raw,'u_temp_filt')
    error('reqml:diagnostics:InvalidExperimentalInput', ...
        'Expected dinf and u_temp_filt in %s',row.result_folder);
end
dinf=pv.dinf;frequency=double(row.frequency_hz);
comp=rswe.lockin_complex(raw.u_temp_filt,dinf.PRFe,frequency,12);
[comp_donut,~,~,~]=rswe.donut_filter_kspace( ...
    comp,dinf.dx,dinf.dz,frequency,1,10,.06);
nz_new=floor(size(comp_donut,1)/2);nx=size(comp_donut,2);
comp_iso=zeros(nz_new,nx,'like',comp_donut);
for ix=1:nx
    column=decimate(comp_donut(:,ix),2);comp_iso(:,ix)=column(1:nz_new);
end
dx=double(dinf.dx);dz=2*double(dinf.dz);
if abs(dx-dz)>1e-9*max(dx,dz)
    error('reqml:diagnostics:NonIsotropicGrid', ...
        'Axial x2 decimation did not produce dz=dx (dx %.9g, dz %.9g).',dx,dz);
end
wavefield_sample=struct('schema_name',"wavefield_sample",'schema_version',"1.0", ...
    'generator',struct('type',"experimental",'modality',"ultrasound", ...
    'system',"Verasonics"),'coordinates',struct('x_m',(0:nx-1)*dx, ...
    'z_m',(0:nz_new-1)*dz,'dx_m',dx,'dz_m',dz,'array_order',"zx"), ...
    'wavefield',struct('data_zx',comp_iso,'frequency_hz',frequency, ...
    'component',"axial",'quantity',"particle_velocity",'units',"m/s"), ...
    'validation',struct('analysis_ready',true), ...
    'provenance',struct('source_type',"experiment", ...
    'source_file',string(row.data_filt_file),'pv_cal_file',string(row.pv_cal_file), ...
    'processing',"temporal filtering + SVD denoising + harmonic lock-in + donut filter + axial decimation x2", ...
    'lockin_cycles',12,'donut_cs_min_m_s',1,'donut_cs_max_m_s',10, ...
    'donut_taper_rel',.06,'axial_decimation_factor',2));
save(sample_file,'wavefield_sample','-v7.3');
end

function out=summarize_prediction(prediction,data,condition,rois)
rows=cell(height(rois),1);x=double(prediction.x_mm);z=double(prediction.z_mm);
[xg,zg]=meshgrid(x,z);
for i=1:height(rois)
    mask=xg>=rois.x_lower_mm(i)&xg<=rois.x_upper_mm(i)& ...
        zg>=rois.z_lower_mm(i)&zg<=rois.z_upper_mm(i)&prediction.valid_mask;
    sws=double(prediction.cs_map(mask));q=double(prediction.q_map(mask));
    amplitude=roi_amplitude(data,rois(i,:));
    if isempty(sws)
        error('reqml:diagnostics:EmptyROI', ...
            'No valid Q0 patches in %s %s %g Hz.',condition.phantom, ...
            rois.roi_id(i),condition.frequency_hz);
    end
    rows{i}=table(condition.phantom,condition.field_type, ...
        condition.acquisition_id,condition.test_id,condition.frequency_hz, ...
        rois.roi_id(i),rois.material_class(i),rois.x_lower_mm(i), ...
        rois.x_upper_mm(i),rois.z_lower_mm(i),rois.z_upper_mm(i), ...
        numel(sws),median(sws),mean(sws),std(sws),iqr(sws), ...
        prctile(sws,25),prctile(sws,75),median(q),iqr(q), ...
        prctile(q,25),prctile(q,75),amplitude, ...
        'VariableNames',{'phantom','field_type','acquisition_id','test_id', ...
        'frequency_hz','roi_id','material_class','x_lower_mm','x_upper_mm', ...
        'z_lower_mm','z_upper_mm','N_valid_patches','median_sws_m_s', ...
        'mean_sws_m_s','std_sws_m_s','IQR_sws_m_s','sws_q25_m_s', ...
        'sws_q75_m_s','median_q','IQR_q','q_q25','q_q75','median_amplitude'});
end
out=vertcat(rows{:});
end

function value=roi_amplitude(data,roi)
x=1e3*double(data.axes.x_m(:));z=1e3*double(data.axes.z_m(:));
mask_x=x>=roi.x_lower_mm&x<=roi.x_upper_mm;
mask_z=z>=roi.z_lower_mm&z<=roi.z_upper_mm;
a=abs(data.wavefield_zx(mask_z,mask_x));value=median(a,'all','omitnan');
end

function t=frequency_consistency(summary)
[groups,series,roi]=findgroups(summary.acquisition_id,summary.roi_id);
rows=cell(max(groups),1);
for g=1:max(groups)
    q=summary(groups==g,:);[frequency,order]=sort(q.frequency_hz);sws=q.median_sws_m_s(order);
    slope=NaN;if numel(frequency)>=2,p=polyfit(frequency,sws,1);slope=100*p(1);end
    reference=q.median_sws_m_s(q.frequency_hz==400);if isempty(reference),reference=NaN;end
    rows{g}=table(series(g),q.phantom(1),q.field_type(1),roi(g),numel(frequency), ...
        min(frequency),max(frequency),min(sws),max(sws), ...
        100*(max(sws)-min(sws))/median(sws),slope,reference, ...
        'VariableNames',{'acquisition_id','phantom','field_type','roi_id', ...
        'N_frequencies','min_frequency_hz','max_frequency_hz','min_median_sws_m_s', ...
        'max_median_sws_m_s','relative_range_percent','linear_slope_m_s_per_100hz', ...
        'median_sws_at_400hz_m_s'});
end
t=vertcat(rows{:});
end

function t=normalized_to_400(summary)
[groups,~,~]=findgroups(summary.acquisition_id,summary.roi_id);
keep=false(height(summary),1);ratio=nan(height(summary),1);
for g=1:max(groups)
    rows=find(groups==g);reference=summary.median_sws_m_s(rows(summary.frequency_hz(rows)==400));
    if isscalar(reference),keep(rows)=true;ratio(rows)=summary.median_sws_m_s(rows)/reference;end
end
t=summary(keep,{'phantom','field_type','acquisition_id','frequency_hz', ...
    'roi_id','material_class'});t.sws_ratio_to_400=ratio(keep);
end

function make_material_figure(t,material,metric,filename)
q=t(t.material_class==material,:);fig=figure('Visible','off','Color','w', ...
    'Position',[100 100 1300 560]);layout=tiledlayout(1,2,'TileSpacing','compact');
for panel=1:2
    nexttile;hold on;grid on;field=["single-point","reverberant"];p=q(q.field_type==field(panel),:);
    series=unique(p.acquisition_id,'stable');
    for s=series.'
        r=sortrows(p(p.acquisition_id==s,:),'frequency_hz');
        y=r.(metric);errorbar(r.frequency_hz,y,lower_error(r,metric), ...
            upper_error(r,metric),'-o','LineWidth',1.4,'DisplayName',plot_label(r));
    end
    xlabel('frequency (Hz)');ylabel(metric_label(metric));title(field(panel));
    legend('Location','best','Interpreter','none');
end
title(layout,sprintf('%s material: %s versus frequency',upper(material),metric_label(metric)));
exportgraphics(fig,filename,'Resolution',220);close(fig);
end

function e=lower_error(t,metric)
if metric=="median_sws_m_s",e=t.median_sws_m_s-t.sws_q25_m_s;
else,e=t.median_q-t.q_q25;end
end

function e=upper_error(t,metric)
if metric=="median_sws_m_s",e=t.sws_q75_m_s-t.median_sws_m_s;
else,e=t.q_q75-t.median_q;end
end

function label=plot_label(t)
label=t.phantom(1)+" "+t.roi_id(1)+" "+t.acquisition_id(1);
end

function label=metric_label(metric)
if metric=="median_sws_m_s",label='median SWS (m/s), IQR';
else,label='median q, IQR';end
end

function make_per_phantom_figure(t,filename)
phantoms=["H5","H10","BILAYER"];fig=figure('Visible','off','Color','w', ...
    'Position',[100 100 1600 520]);layout=tiledlayout(1,3,'TileSpacing','compact');
for panel=1:3
    nexttile;hold on;grid on;q=t(t.phantom==phantoms(panel),:);
    [groups,series,roi]=findgroups(q.acquisition_id,q.roi_id);
    for g=1:max(groups)
        r=sortrows(q(groups==g,:),'frequency_hz');
        style="-";if r.field_type(1)=="reverberant",style="--";end
        plot(r.frequency_hz,r.median_sws_m_s,style+'o','LineWidth',1.4, ...
            'DisplayName',series(g)+" "+roi(g));
    end
    title(phantoms(panel));xlabel('frequency (Hz)');ylabel('median SWS (m/s)');
    legend('Location','best','Interpreter','none');
end
title(layout,'Within-phantom frozen-Q0 frequency trends');
exportgraphics(fig,filename,'Resolution',220);close(fig);
end

function make_normalized_figure(t,filename)
fig=figure('Visible','off','Color','w','Position',[100 100 1200 700]);hold on;grid on;
[groups,series,roi]=findgroups(t.acquisition_id,t.roi_id);
for g=1:max(groups)
    r=sortrows(t(groups==g,:),'frequency_hz');
    plot(r.frequency_hz,r.sws_ratio_to_400,'-o','LineWidth',1.3, ...
        'DisplayName',series(g)+" "+roi(g));
end
yline(1,'k:');xlabel('frequency (Hz)');ylabel('median SWS(f) / median SWS(400 Hz)');
title('Normalized within-phantom frequency response');
legend('Location','eastoutside','Interpreter','none');
exportgraphics(fig,filename,'Resolution',220);close(fig);
end

function write_json(filename,value)
fid=fopen(filename,'w');if fid<0,error('reqml:diagnostics:WriteFailed', ...
        'Cannot write %s',filename);end
cleanup=onCleanup(@() fclose(fid));fprintf(fid,'%s',jsonencode(value,PrettyPrint=true));
end
