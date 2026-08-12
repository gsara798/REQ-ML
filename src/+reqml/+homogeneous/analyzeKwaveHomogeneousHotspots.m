function result=analyzeKwaveHomogeneousHotspots(options)
%ANALYZEKWAVEHOMOGENEOUSHOTSPOTS Post-hoc diagnostic of saved v2 predictions.
arguments
    options.PredictionDirectory {mustBeTextScalar} = ""
    options.ModelBundle {mustBeTextScalar} = ""
    options.OutputDirectory {mustBeTextScalar} = ""
end
repo=string(fileparts(fileparts(fileparts(fileparts(mfilename("fullpath"))))));
prediction_dir=resolve_default(options.PredictionDirectory,fullfile(repo,"outputs", ...
    "homogeneous_cartesian_q0_v2","external_partial_available","tables"));
model_file=resolve_default(options.ModelBundle,fullfile(repo,"outputs", ...
    "homogeneous_cartesian_q0_v2","training","final_frozen_q0_v2","model_bundle.mat"));
output=resolve_default(options.OutputDirectory,fullfile(repo,"outputs", ...
    "homogeneous_cartesian_q0_v2","diagnostics","kwave_homogeneous_hotspots_v1"));
if ~isfolder(output), mkdir(output); end
files=dir(fullfile(prediction_dir,"kwave_hom_cs*_M*_dense_predictions.csv"));
if numel(files)~=12
    error("reqml:IncompleteKwaveHomogeneousDiagnostic", ...
        "Expected 12 completed homogeneous k-Wave case-M tables; found %d.",numel(files));
end
loaded=load(model_file,"model","predictor_names");
summary_parts=cell(numel(files),1); selected_parts=cell(numel(files),1);
location_parts=cell(numel(files),1);
for i=1:numel(files)
    p=readtable(fullfile(files(i).folder,files(i).name),TextType="string");
    stride=p(p.sampling_mode=="stride_matched" & p.sws_valid,:);
    map=p(ismember(p.sampling_mode,["dense_map","spatial_map"]),:);
    summary_parts{i}=summarize_stride(stride);
    selected=reqml.homogeneous.selectHotspotControlPatches(map);
    selected=attach_selected_features(selected,loaded,predictor_names(loaded));
    selected_parts{i}=selected;
    location_parts{i}=summarize_location(selected,map);
end
sws_summary=vertcat(summary_parts{:}); selected=vertcat(selected_parts{:});
locations=vertcat(location_parts{:});
feature_names=["cs_true_m_s","cs_pred_m_s","cs_error_percent", ...
    "cs_absolute_error_percent","local_wavefield_rms", ...
    "radial_entropy","width_75_25_rel","width_90_10_rel","ang_entropy", ...
    "circ_var","dom_dir_frac","window_max_frac", ...
    "srad_proxy_peak_k_norm","srad_proxy_peak_to_centroid"];
group_summary=summarize_groups(selected);
feature_summary=summarize_features(selected,feature_names);
ood_summary=summarize_ood(selected);
writetable(sws_summary,fullfile(output,"kwave_homogeneous_sws_by_field.csv"));
writetable(group_summary,fullfile(output,"hotspot_vs_control.csv"));
writetable(feature_summary,fullfile(output,"hotspot_feature_summary.csv"));
writetable(ood_summary,fullfile(output,"hotspot_ood_summary.csv"));
writetable(locations,fullfile(output,"hotspot_locations.csv"));
make_sws_figure(selected_sws_tables(files,prediction_dir),sws_summary,output,"mean_sd");
make_sws_figure(selected_sws_tables(files,prediction_dir),sws_summary,output,"median_iqr");
make_feature_figure(selected,feature_names,output);
make_location_figure(locations,output);
manifest=struct("schema_name","reqml_kwave_homogeneous_hotspots", ...
    "schema_version","1.0","case_M_count",numel(files), ...
    "hotspot_definition","Top 1% absolute SWS error among valid saved map-grid patches.", ...
    "control_definition","Deterministic equal-N subset below median absolute error.", ...
    "ood_definition","RMS standardized distance to frozen training centroid using model mu/sigma.", ...
    "map_sampling_note","Uses the already saved dense_map or spatial_map prediction rows; no maps are re-extracted.", ...
    "created_utc",string(datetime("now","TimeZone","UTC")));
write_json(fullfile(output,"diagnostic_manifest.json"),manifest);
result=struct("sws_summary",sws_summary,"group_summary",group_summary, ...
    "feature_summary",feature_summary,"ood_summary",ood_summary, ...
    "locations",locations,"output_directory",output);
end

function value=resolve_default(value,fallback)
value=string(value); if strlength(value)==0, value=string(fallback); end
end

function names=predictor_names(loaded), names=string(loaded.predictor_names(:)); end

function t=summarize_stride(p)
n=height(p); values=double(p.cs_pred_m_s);
t=table(string(p.case_label(1)),double(p.cs_true_m_s(1)),string(p.field_regime(1)), ...
    double(p.REQ_M(1)),n,mean(values),std(values),median(values),iqr(values), ...
    mean(p.cs_absolute_error_percent),mean(p.cs_error_percent), ...
    VariableNames=["case_label","true_sws_m_s","angular_regime","REQ_M","N", ...
    "mean_predicted_sws_m_s","sd_predicted_sws_m_s","median_predicted_sws_m_s", ...
    "iqr_predicted_sws_m_s","sws_mape","signed_bias_percent"]);
end

function selected=attach_selected_features(selected,loaded,predictors)
sample=reqml.io.load_wavefield_sample(string(selected.sample_file(1)));
valid_truth=double(sample.truth.cs_m_s_zx(logical(sample.truth.valid_mask_zx)));
cfg=struct("dx",double(sample.dx_m),"dz",double(sample.dz_m), ...
    "f0",double(sample.frequency_hz),"cs_bg",median(valid_truth),"WaveModel","wavefield_sample");
M=double(selected.REQ_M(1)); feat=reqml.config.default_feature_config("M",M,"cs_guess",3);
centers=double(selected{:, ["cx","cz"]});
out=reqml.estimators.req_estimator_map(sample.wavefield_zx,cfg,feat, ...
    CenterIndices=centers,ReturnFeatures=false,ReturnFeatureTable=true, ...
    StoreReqCurves=false,ReuseReqSpectrumForFeatures=true,UseWindowParfor=false);
f=out.feature_table;
[found,index]=ismember(centers,double(f{:, ["cx","cz"]}),"rows");
if ~all(found), error("reqml:MissingHotspotFeatureRow","Selected centers were not re-evaluated exactly."); end
f=f(index,:); f.campaign_frequency_hz=repmat(double(sample.frequency_hz),height(f),1);
copy_names=intersect(predictors,string(f.Properties.VariableNames),"stable");
for name=copy_names.', selected.(name)=double(f.(name)); end
half=floor(double(selected.patch_width_px)/2); rms_value=nan(height(selected),1);
for row=1:height(selected)
    x=(selected.cx(row)-half(row)):(selected.cx(row)+half(row));
    z=(selected.cz(row)-half(row)):(selected.cz(row)+half(row));
    patch=sample.wavefield_zx(z,x); rms_value(row)=sqrt(mean(abs(double(patch(:))).^2));
end
selected.local_wavefield_rms=rms_value;
X=nan(height(selected),numel(predictors));
for j=1:numel(predictors)
    if ismember(predictors(j),string(selected.Properties.VariableNames))
        X(:,j)=double(selected.(predictors(j)));
    end
end
mu=double(loaded.model.mu(:).'); sigma=double(loaded.model.sigma(:).');
active=isfinite(mu) & isfinite(sigma) & sigma>0;
Z=(X(:,active)-mu(active))./sigma(active);
selected.ood_standardized_rms=sqrt(mean(Z.^2,2,"omitnan"));
selected.ood_finite_predictor_fraction=mean(isfinite(Z),2);
selected.x_normalized=(selected.cx-min(selected.cx))./max(1,max(selected.cx)-min(selected.cx));
selected.z_normalized=(selected.cz-min(selected.cz))./max(1,max(selected.cz)-min(selected.cz));
end

function t=summarize_location(selected,map)
h=selected(selected.selection_group=="hotspot",:);
xmin=min(map.cx); xmax=max(map.cx); zmin=min(map.cz); zmax=max(map.cz);
x=(h.cx-xmin)/max(1,xmax-xmin); z=(h.cz-zmin)/max(1,zmax-zmin);
t=table(string(h.case_label(1)),double(h.cs_true_m_s(1)),string(h.field_regime(1)), ...
    double(h.REQ_M(1)),height(h),mean(x),mean(z),std(x),std(z), ...
    VariableNames=["case_label","true_sws_m_s","angular_regime","REQ_M", ...
    "hotspot_N","centroid_x_normalized","centroid_z_normalized", ...
    "sd_x_normalized","sd_z_normalized"]);
end

function t=summarize_groups(p)
keys=["case_label","cs_true_m_s","field_regime","REQ_M","selection_group"];
[g,t]=findgroups(p(:,keys));
t.N=splitapply(@numel,p.cs_pred_m_s,g);
t.mean_predicted_sws_m_s=splitapply(@mean,p.cs_pred_m_s,g);
t.median_predicted_sws_m_s=splitapply(@median,p.cs_pred_m_s,g);
t.mean_signed_error_percent=splitapply(@mean,p.cs_error_percent,g);
t.mean_absolute_error_percent=splitapply(@mean,p.cs_absolute_error_percent,g);
t.median_local_wavefield_rms=splitapply(@median,p.local_wavefield_rms,g);
t.median_ood_distance=splitapply(@median,p.ood_standardized_rms,g);
end

function t=summarize_features(p,names)
parts=cell(0,1); keys=["case_label","cs_true_m_s","field_regime","REQ_M","selection_group"];
[g,base]=findgroups(p(:,keys));
for name=names
    values=double(p.(name)); q=base; q.feature=repmat(name,height(q),1);
    q.mean=splitapply(@(x) mean(x,"omitnan"),values,g);
    q.median=splitapply(@(x) median(x,"omitnan"),values,g);
    q.iqr=splitapply(@(x) iqr(x),values,g); parts{end+1}=q; %#ok<AGROW>
end
t=vertcat(parts{:});
end

function t=summarize_ood(p)
keys=["case_label","cs_true_m_s","field_regime","REQ_M"];
[g,t]=findgroups(p(:,keys));
hot=p.selection_group=="hotspot"; control=~hot; distance=p.ood_standardized_rms;
t.hotspot_median_distance=splitapply(@(x,h) median(x(h),"omitnan"),distance,hot,g);
t.hotspot_iqr_distance=splitapply(@(x,h) iqr(x(h)),distance,hot,g);
t.control_median_distance=splitapply(@(x,c) median(x(c),"omitnan"),distance,control,g);
t.control_iqr_distance=splitapply(@(x,c) iqr(x(c)),distance,control,g);
t.median_difference=t.hotspot_median_distance-t.control_median_distance;
t.median_ratio=t.hotspot_median_distance./t.control_median_distance;
end

function all=selected_sws_tables(files,root)
parts=cell(numel(files),1);
for i=1:numel(files)
    p=readtable(fullfile(root,files(i).name),TextType="string");
    parts{i}=p(p.sampling_mode=="stride_matched" & p.sws_valid,:);
end
all=vertcat(parts{:});
end

function make_sws_figure(p,s,output,mode)
anchors=["low","mid","high"]; M_values=[2 3]; cs_values=[2 3];
f=figure("Visible","off","Color","w","Position",[100 100 1250 850]);
tiledlayout(2,2,"TileSpacing","compact","Padding","compact");
for ci=1:2
    for mi=1:2
        nexttile; hold on; q=p(p.cs_true_m_s==cs_values(ci) & p.REQ_M==M_values(mi),:);
        for ai=1:3
            a=q(q.field_regime==anchors(ai),:); n=height(a);
            jitter=.14*((mod((1:n)'*37,101)/100)-.5);
            scatter(ai+jitter,a.cs_pred_m_s,8,[.45 .55 .75],"filled","MarkerFaceAlpha",.22);
        end
        rows=s(s.true_sws_m_s==cs_values(ci) & s.REQ_M==M_values(mi),:);
        [~,order]=ismember(rows.angular_regime,anchors); [~,idx]=sort(order); rows=rows(idx,:);
        if mode=="mean_sd"
            errorbar(1:3,rows.mean_predicted_sws_m_s,rows.sd_predicted_sws_m_s, ...
                "o-","LineWidth",1.7,"MarkerFaceColor",[.1 .25 .65],"Color",[.1 .25 .65]);
        else
            errorbar(1:3,rows.median_predicted_sws_m_s,.5*rows.iqr_predicted_sws_m_s, ...
                "s-","LineWidth",1.7,"MarkerFaceColor",[.65 .2 .15],"Color",[.65 .2 .15]);
        end
        yline(cs_values(ci),"k--","True SWS","LineWidth",1.2);
        xlim([.6 3.4]); xticks(1:3); xticklabels(anchors); ylabel("Predicted SWS (m/s)");
        title(sprintf("True SWS %g m/s, M=%d",cs_values(ci),M_values(mi))); grid on;
    end
end
if mode=="mean_sd", title_text="k-Wave homogeneous SWS: mean +/- 1 SD";
else, title_text="k-Wave homogeneous SWS: median +/- 0.5 IQR"; end
sgtitle(title_text); exportgraphics(f,fullfile(output,"kwave_sws_by_field_"+mode+".png"),"Resolution",300); close(f);
end

function make_feature_figure(p,names,output)
M_values=[2 3]; effects=nan(numel(names),2);
for i=1:numel(names)
    values=double(p.(names(i))); scale=iqr(values); if ~isfinite(scale) || scale<=eps, scale=std(values); end
    for j=1:2
        q=values(p.REQ_M==M_values(j)); groups=p.selection_group(p.REQ_M==M_values(j));
        effects(i,j)=(median(q(groups=="hotspot"),"omitnan")- ...
            median(q(groups=="control"),"omitnan"))/scale;
    end
end
f=figure("Visible","off","Color","w","Position",[100 100 850 850]);
imagesc(effects); colorbar; colormap(redblue()); clim(max(abs(effects),[],"all")*[-1 1]);
xticks(1:2); xticklabels("M="+string(M_values)); yticks(1:numel(names));
yticklabels(replace(names,"_"," ")); set(gca,"TickLabelInterpreter","none");
xlabel("REQ window M"); title("Hotspot - control median difference / pooled IQR");
exportgraphics(f,fullfile(output,"hotspot_vs_control_features.png"),"Resolution",300); close(f);
end

function make_location_figure(t,output)
anchors=["low","mid","high"]; colors=lines(3); markers=["o","s"];
f=figure("Visible","off","Color","w","Position",[100 100 1100 520]);
for M=[2 3]
    subplot(1,2,M-1); hold on;
    for ai=1:3
        for ci=1:2
            cs=[2 3]; q=t(t.REQ_M==M & t.angular_regime==anchors(ai) & t.true_sws_m_s==cs(ci),:);
            scatter(q.centroid_x_normalized,q.centroid_z_normalized,95,colors(ai,:),markers(ci), ...
                "filled","MarkerEdgeColor","k","LineWidth",.8, ...
                "DisplayName",anchors(ai)+", cs="+cs(ci));
        end
    end
    axis square; xlim([0 1]); ylim([0 1]); grid on; xlabel("Normalized x"); ylabel("Normalized z");
    title("M="+M); legend("Location","best");
end
sgtitle("Centroids of top-1% absolute-error patches");
exportgraphics(f,fullfile(output,"hotspot_locations.png"),"Resolution",300); close(f);
end

function map=redblue()
n=256; half=n/2; map=[linspace(0,1,half)' linspace(0,1,half)' ones(half,1); ...
    ones(half,1) linspace(1,0,half)' linspace(1,0,half)'];
end

function write_json(path,value)
fid=fopen(path,"w"); if fid<0, error("reqml:CannotWriteHotspotManifest","Cannot write %s",path); end
cleanup=onCleanup(@() fclose(fid)); fprintf(fid,"%s\n",jsonencode(value,PrettyPrint=true));
end
