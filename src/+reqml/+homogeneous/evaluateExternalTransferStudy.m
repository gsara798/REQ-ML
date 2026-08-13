function result = evaluateExternalTransferStudy(config_file)
%EVALUATEEXTERNALTRANSFERSTUDY Evaluate frozen Q0 across external OOD cases.
% Dense StepX=StepZ=1 predictions are used for maps. Aggregate metrics are
% reported both densely (spatially correlated) and on the training-matched
% stride max(4,ceil(W/2)); the latter is a deterministic subset of the same
% extracted centres, so features are never recomputed.

arguments
    config_file {mustBeTextScalar}
end
config_file=string(config_file); config=jsondecode(fileread(config_file));
repository_root=string(fileparts(fileparts(fileparts(fileparts(mfilename("fullpath"))))));
model_file=reqml.config.resolveWorkspacePath(string(config.model_bundle),RepositoryRoot=repository_root);
output_root=reqml.config.resolveWorkspacePath(string(config.output_root),RepositoryRoot=repository_root);
for i=1:numel(config.cases)
    config.cases(i).sample_file=reqml.config.resolveWorkspacePath( ...
        string(config.cases(i).sample_file),RepositoryRoot=repository_root);
end
validate_config(config,model_file,output_root);
loaded=load(model_file,"model","model_metadata","predictor_names");
predictor_names=string(loaded.predictor_names(:));
if isfield(config.feature_config,"M_values")
    M_values=double(config.feature_config.M_values(:));
else
    M_values=double(config.feature_config.M);
end
if ~isfolder(output_root), mkdir(output_root); end
table_root=fullfile(output_root,"tables"); figure_root=fullfile(output_root,"figures");
if ~isfolder(table_root), mkdir(table_root); end
if ~isfolder(figure_root), mkdir(figure_root); end

prediction_parts=cell(numel(config.cases)*numel(M_values),1); part_index=0;
if isfield(config.feature_config,"map_step_px"), map_step=double(config.feature_config.map_step_px); else, map_step=1; end
resume_cases=isfield(config.feature_config,"resume_case_predictions") && logical(config.feature_config.resume_case_predictions);
resumed_part_count=0;
for i=1:numel(config.cases)
    c=config.cases(i); label=string(c.label); sample_file=string(c.sample_file);
    data=reqml.io.load_wavefield_sample(sample_file);
    for M=M_values.'
    stem=label+"_M"+M; case_table=fullfile(table_root,stem+"_dense_predictions.csv");
    if resume_cases && isfile(case_table)
        predictions=readtable(case_table,TextType="string");
        required=["case_label","REQ_M","sampling_mode","sws_valid"];
        if all(ismember(required,string(predictions.Properties.VariableNames))) && ...
                all(predictions.case_label==label) && all(predictions.REQ_M==M) && ...
                any(predictions.sampling_mode=="stride_matched") && ...
                any(ismember(predictions.sampling_mode,["dense_map","spatial_map"]))
            part_index=part_index+1; prediction_parts{part_index}=predictions;
            figure_base=fullfile(figure_root,stem);
            if ~isfile(figure_base+".png") || ~isfile(figure_base+".pdf")
                make_case_figure(predictions,figure_base,string(c.geometry));
            end
            resumed_part_count=resumed_part_count+1;
            fprintf("%s M=%d: resumed validated case predictions\n",label,M);
            continue
        end
    end
    geometry=reqml.homogeneous.computePatchGeometry(double(data.frequency_hz), ...
        double(data.dx_m),double(data.dz_m),M=M, ...
        CsGuessMPerS=double(config.feature_config.cs_guess_m_s));
    map_mode="dense_map"; if map_step>1, map_mode="spatial_map"; end
    map_predictions=predict_at_step(data,config,c,label,sample_file,M,map_step,map_mode, ...
        predictor_names,loaded.model,geometry);
    if map_step==1
        stride=geometry.stride_x_px;
        matched=mod(map_predictions.cx-min(map_predictions.cx),stride)==0 & ...
            mod(map_predictions.cz-min(map_predictions.cz),stride)==0;
        metric_predictions=map_predictions(matched,:); metric_predictions.sampling_mode(:)="stride_matched";
    else
        metric_predictions=predict_at_step(data,config,c,label,sample_file,M,geometry.stride_x_px, ...
            "stride_matched",predictor_names,loaded.model,geometry);
    end
    predictions=[map_predictions;metric_predictions];
    predictions.roi=reqml.homogeneous.classifyExternalRoi(predictions.geometry, ...
        predictions.material_id_center,predictions.truth_material_purity, ...
        predictions.cx,predictions.cz,double(data.dx_m),double(data.dz_m));
    part_index=part_index+1; prediction_parts{part_index}=predictions;
    writetable(predictions,case_table);
    make_case_figure(predictions,fullfile(figure_root,stem),string(c.geometry));
    fprintf("%s M=%d: %d dense, %d stride-matched patches\n",label,M, ...
        nnz(ismember(predictions.sampling_mode,["dense_map","spatial_map"])), ...
        nnz(predictions.sampling_mode=="stride_matched"));
    end
end
predictions=vertcat(prediction_parts{:});
metrics=reqml.homogeneous.summarizeExternalPredictions(predictions, ...
    ["backend","geometry","field_regime","REQ_M","case_label","sampling_mode"]);
roi_metrics=reqml.homogeneous.summarizeExternalPredictions( ...
    predictions(predictions.geometry~="homogeneous",:), ...
    ["backend","geometry","field_regime","REQ_M","case_label","sampling_mode","roi"]);
purity_metrics=reqml.homogeneous.summarizeExternalPredictions( ...
    predictions(predictions.geometry~="homogeneous",:), ...
    ["backend","geometry","field_regime","REQ_M","case_label","sampling_mode","purity_bin"]);
field_metrics=reqml.homogeneous.summarizeExternalPredictions(predictions, ...
    ["backend","geometry","field_regime","REQ_M","sampling_mode"]);
validity_metrics=summarize_validity(predictions, ...
    ["backend","geometry","field_regime","REQ_M","case_label","sampling_mode"]);
writetable(metrics,fullfile(table_root,"external_global_metrics.csv"));
writetable(roi_metrics,fullfile(table_root,"external_roi_metrics.csv"));
writetable(purity_metrics,fullfile(table_root,"external_purity_metrics.csv"));
writetable(field_metrics,fullfile(table_root,"external_field_metrics.csv"));
writetable(validity_metrics,fullfile(table_root,"external_validity_metrics.csv"));
save(fullfile(output_root,"external_predictions.mat"),"predictions","-v7.3");
make_field_figure(field_metrics,fullfile(figure_root,"external_mape_by_field"));
make_summary_figure(field_metrics,roi_metrics,fullfile(figure_root,"external_analysis_summary"));
make_validity_figure(validity_metrics,fullfile(figure_root,"external_invalid_patch_fraction"));
manifest=struct("schema_name","reqml_external_q0_transfer_study","schema_version","1.0", ...
    "evaluation_id",string(config.evaluation_id),"source_config",config_file, ...
    "model_bundle",model_file,"model_metadata",loaded.model_metadata, ...
    "REQ_M_values",M_values, ...
    "case_count",numel(config.cases), ...
    "evaluation_scope",optional_string(config,"evaluation_scope","unspecified"), ...
    "partial_result",optional_logical(config,"partial_result",false), ...
    "expected_case_count",optional_double(config,"expected_case_count",numel(config.cases)), ...
    "dense_patch_count",nnz(predictions.sampling_mode=="dense_map"), ...
    "spatial_map_patch_count",nnz(predictions.sampling_mode=="spatial_map"), ...
    "map_step_px",map_step, ...
    "stride_patch_count",nnz(predictions.sampling_mode=="stride_matched"), ...
    "invalid_prediction_count",nnz(~predictions.sws_valid), ...
    "resumed_case_M_part_count",resumed_part_count, ...
    "dense_patch_independence_note","Dense rows overlap and are not independent samples.", ...
    "git_head",git_head(repository_root),"created_utc",string(datetime("now","TimeZone","UTC")));
write_json(fullfile(output_root,"external_manifest.json"),manifest);
result=struct("metrics",metrics,"roi_metrics",roi_metrics, ...
    "purity_metrics",purity_metrics,"field_metrics",field_metrics, ...
    "validity_metrics",validity_metrics, ...
    "output_root",output_root);
end

function p=predict_at_step(data,config,c,label,sample_file,M,step,mode,predictor_names,model,g)
feat_cfg=reqml.config.default_feature_config("M",M, ...
    "cs_guess",double(config.feature_config.cs_guess_m_s));
extracted=reqml.datasets.extract_examples_from_sample(data,feat_cfg, ...
    DatasetId=string(config.evaluation_id),SampleId=label+"_M"+M+"_"+mode, ...
    StepX=step,StepZ=step,StoreReqCurves=false, ...
    UseWindowParfor=logical(config.feature_config.use_window_parfor));
examples=extracted.examples;
examples.campaign_frequency_hz=repmat(double(data.frequency_hz),height(examples),1);
prediction=reqml.deployment.predictQ0Examples(examples,model,predictor_names);
p=make_predictions(examples,prediction.q_pred,prediction.sws, ...
    c,sample_file,g,M,mode);
end

function summary=summarize_validity(p,groups)
[g,values]=findgroups(p(:,groups)); summary=values;
summary.total_patch_count=splitapply(@numel,p.sws_valid,g);
summary.valid_patch_count=splitapply(@nnz,p.sws_valid,g);
summary.invalid_patch_count=summary.total_patch_count-summary.valid_patch_count;
summary.invalid_patch_fraction=summary.invalid_patch_count./summary.total_patch_count;
end

function make_summary_figure(field,roi,path_base)
d=field(field.sampling_mode=="stride_matched",:);
fig=figure("Visible","off","Color","w","Position",[100 100 1250 760]);
tiledlayout(2,2,"TileSpacing","compact","Padding","compact");
nexttile; grouped_bar(d,"backend","SWS MAPE (%)","Backend");
nexttile; grouped_bar(d,"geometry","SWS MAPE (%)","Geometry");
nexttile; grouped_bar(d,"field_regime","SWS MAPE (%)","Angular regime");
nexttile;
r=roi(roi.sampling_mode=="stride_matched",:);
if isempty(r)
    axis off; text(.5,.5,"No heterogeneous ROI cases","HorizontalAlignment","center");
else
    grouped_bar(r,"roi","SWS MAPE (%)","Heterogeneous ROI");
end
sgtitle("External frozen-Q0 analysis (stride matched)");
exportgraphics(fig,path_base+".png","Resolution",300);
exportgraphics(fig,path_base+".pdf","ContentType","vector"); close(fig);
end

function grouped_bar(t,name,ylabel_text,title_text)
groups=unique(string(t.(name)),"stable"); M=sort(unique(t.REQ_M)); values=nan(numel(groups),numel(M));
for i=1:numel(groups)
    for j=1:numel(M)
        q=t(string(t.(name))==groups(i) & t.REQ_M==M(j),:);
        if ~isempty(q), values(i,j)=sum(q.sws_mape.*q.patch_count)/sum(q.patch_count); end
    end
end
labels=replace(groups,"_"," ");
bar(categorical(labels,labels),values); ylabel(ylabel_text); title(title_text); grid on;
set(gca,"TickLabelInterpreter","none");
legend("M="+string(M),"Location","best");
end

function make_validity_figure(t,path_base)
d=t(ismember(t.sampling_mode,["dense_map","spatial_map"]),:);
labels=d.case_label+" M="+string(d.REQ_M); [labels,order]=sort(labels); d=d(order,:);
fig=figure("Visible","off","Color","w","Position",[100 100 1300 700]);
barh(categorical(replace(labels,"_"," "),replace(labels,"_"," ")),100*d.invalid_patch_fraction);
xlabel("Invalid patch fraction (%)"); ylabel("External case");
title("Non-evaluable external patches (spatial maps)"); grid on;
set(gca,"TickLabelInterpreter","none");
exportgraphics(fig,path_base+".png","Resolution",300);
exportgraphics(fig,path_base+".pdf","ContentType","vector"); close(fig);
end

function value=optional_string(s,name,fallback)
if isfield(s,name), value=string(s.(name)); else, value=string(fallback); end
end

function value=optional_logical(s,name,fallback)
if isfield(s,name), value=logical(s.(name)); else, value=logical(fallback); end
end

function value=optional_double(s,name,fallback)
if isfield(s,name), value=double(s.(name)); else, value=double(fallback); end
end

function p=make_predictions(e,q_pred,sws,c,sample_file,g,M,mode)
n=height(e); q_true=double(e.q_target_from_center_truth);
stride=max(g.stride_x_px,g.stride_z_px);
sampling=repmat(string(mode),n,1);
purity=double(e.truth_material_purity);
purity_bin=repmat("<0.7",n,1); purity_bin(purity>=.7)="0.7-0.9";
purity_bin(purity>=.9)="0.9-0.98"; purity_bin(purity>=.98)="0.98-1";
purity_bin(abs(purity-1)<=1e-12)="1";
p=table(repmat(string(c.label),n,1),repmat(string(c.backend),n,1), ...
    repmat(string(c.geometry),n,1),repmat(string(c.field_regime),n,1), ...
    repmat(M,n,1),repmat(sample_file,n,1),sampling,string(e.example_id),double(e.map_iz), ...
    double(e.map_ix),double(e.cx),double(e.cz),double(e.x_center_m),double(e.z_center_m), ...
    double(e.truth_material_id_center),purity,purity_bin,q_true,double(q_pred), ...
    double(q_pred)-q_true,double(e.truth_cs_center_m_s),sws.cs_pred_m_s, ...
    sws.cs_error_m_s,sws.cs_error_percent,sws.cs_absolute_error_percent,sws.sws_valid, ...
    repmat(g.patch_width_px,n,1),repmat(stride,n,1), ...
    VariableNames=["case_label","backend","geometry","field_regime","REQ_M","sample_file", ...
    "sampling_mode","example_id","map_iz","map_ix","cx","cz","x_center_m","z_center_m", ...
    "material_id_center","truth_material_purity","purity_bin","q_true","q_pred","q_error", ...
    "cs_true_m_s","cs_pred_m_s","cs_error_m_s","cs_error_percent", ...
    "cs_absolute_error_percent","sws_valid","patch_width_px","stride_px"]);
end

function make_case_figure(p,path_base,geometry)
d=p(ismember(p.sampling_mode,["dense_map","spatial_map"]),:); iz=unique(d.map_iz); ix=unique(d.map_ix);
vars=["cs_true_m_s","cs_pred_m_s","cs_error_percent","cs_absolute_error_percent","q_pred","truth_material_purity"];
titles=["Ground-truth SWS","Q0-predicted SWS","Signed error (%)","Absolute error (%)","Predicted q","Truth material purity"];
if geometry=="homogeneous", vars=vars([2 3]); titles=titles([2 3]); end
fig=figure("Visible","off","Color","w","Position",[100 100 1200 650]);
tiledlayout(2,ceil(numel(vars)/2),"TileSpacing","compact","Padding","compact");
[~,zi_all]=ismember(d.map_iz,iz); [~,xi_all]=ismember(d.map_ix,ix);
material=nan(numel(iz),numel(ix));
material(sub2ind(size(material),zi_all,xi_all))=d.material_id_center;
x_axis=unique(d.x_center_m)*1e3; z_axis=unique(d.z_center_m)*1e3;
for j=1:numel(vars)
    nexttile; m=nan(numel(iz),numel(ix));
    [~,zi]=ismember(d.map_iz,iz); [~,xi]=ismember(d.map_ix,ix);
    m(sub2ind(size(m),zi,xi))=d.(vars(j));
    imagesc(x_axis,z_axis,m); axis image xy; colorbar;
    xlabel("x (mm)"); ylabel("z (mm)"); title(titles(j));
    if contains(vars(j),"cs_") && ~contains(vars(j),"error"), clim([1.8 3.2]); end
    if vars(j)=="cs_error_percent", clim([-50 50]); end
    if vars(j)=="cs_absolute_error_percent", clim([0 50]); end
    if vars(j)=="q_pred", clim([0 1]); end
    if vars(j)=="truth_material_purity", clim([.5 1]); end
    if geometry~="homogeneous"
        material_ids=unique(material(isfinite(material)));
        boundary_level=mean(material_ids([1 end]));
        hold on; contour(x_axis,z_axis,material,[boundary_level boundary_level], ...
            "k-","LineWidth",1.2); hold off
    end
end
sgtitle(strrep(string(d.case_label(1)),"_"," "));
exportgraphics(fig,path_base+".png","Resolution",300); exportgraphics(fig,path_base+".pdf","ContentType","vector"); close(fig);
end

function make_field_figure(t,path_base)
d=t(t.sampling_mode=="stride_matched",:); fig=figure("Visible","off","Color","w");
cats=categorical(d.field_regime); scatter(cats,d.sws_mape,65,categorical(d.backend),"filled");
ylabel("SWS MAPE (%)"); xlabel("Field regime"); grid on; title("External frozen-Q0 transfer (stride matched)");
exportgraphics(fig,path_base+".png","Resolution",300); exportgraphics(fig,path_base+".pdf","ContentType","vector"); close(fig);
end

function validate_config(c,model_file,output_root)
required=["evaluation_id","model_bundle","output_root","feature_config","cases"];
missing=setdiff(required,string(fieldnames(c))); if ~isempty(missing), error("reqml:InvalidExternalTransferConfig","Missing: %s",strjoin(missing,", ")); end
if ~isfile(model_file), error("reqml:MissingExternalQ0Model","Missing model: %s",model_file); end
if contains(output_root,"training"), error("reqml:UnsafeExternalQ0OutputPath","External output must not be inside training outputs."); end
for i=1:numel(c.cases)
    if ~isfile(string(c.cases(i).sample_file)), error("reqml:MissingExternalQ0Sample","Missing sample: %s",c.cases(i).sample_file); end
end
end

function value=git_head(root)
[status,text]=system(sprintf('git -C "%s" rev-parse HEAD',root)); if status==0, value=strtrim(string(text)); else, value="unknown"; end
end

function write_json(path,value)
fid=fopen(path,"w"); if fid<0, error("reqml:CannotWriteExternalManifest","Cannot write %s",path); end
cleanup=onCleanup(@() fclose(fid)); fprintf(fid,"%s\n",jsonencode(value,PrettyPrint=true));
end
