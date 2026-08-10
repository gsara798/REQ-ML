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
feat_cfg=reqml.config.default_feature_config("M",double(config.feature_config.M), ...
    "cs_guess",double(config.feature_config.cs_guess_m_s));
if ~isfolder(output_root), mkdir(output_root); end
table_root=fullfile(output_root,"tables"); figure_root=fullfile(output_root,"figures");
if ~isfolder(table_root), mkdir(table_root); end
if ~isfolder(figure_root), mkdir(figure_root); end

prediction_parts=cell(numel(config.cases),1);
for i=1:numel(config.cases)
    c=config.cases(i); label=string(c.label); sample_file=string(c.sample_file);
    data=reqml.io.load_wavefield_sample(sample_file);
    extracted=reqml.datasets.extract_examples_from_sample(data,feat_cfg, ...
        DatasetId=string(config.evaluation_id),SampleId=label,StepX=1,StepZ=1, ...
        StoreReqCurves=false,UseWindowParfor=logical(config.feature_config.use_window_parfor));
    examples=extracted.examples;
    examples.campaign_frequency_hz=repmat(double(data.frequency_hz),height(examples),1);
    contract=reqml.training.validate_predictor_contract(examples,predictor_names, ...
        reqml.training.q0_predictor_registry());
    if ~contract.valid, error("reqml:InvalidExternalQ0PredictorContract","%s",contract.summary); end
    X=reqml.training.build_numeric_predictor_matrix(examples,predictor_names);
    q_pred=reqml.training.predict_regression_model(loaded.model,X,ClipRange=[.001 .999]);
    sws=reqml.evaluation.convert_q_predictions_to_sws(examples,q_pred);
    geometry=reqml.homogeneous.computePatchGeometry(double(data.frequency_hz), ...
        double(data.dx_m),double(data.dz_m),M=double(config.feature_config.M), ...
        CsGuessMPerS=double(config.feature_config.cs_guess_m_s));
    predictions=make_predictions(examples,q_pred,sws,c,sample_file,geometry);
    predictions.roi=reqml.homogeneous.classifyExternalRoi(predictions.geometry, ...
        predictions.material_id_center,predictions.truth_material_purity, ...
        predictions.cx,predictions.cz,double(data.dx_m),double(data.dz_m));
    prediction_parts{i}=predictions;
    writetable(predictions,fullfile(table_root,label+"_dense_predictions.csv"));
    make_case_figure(predictions,fullfile(figure_root,label),string(c.geometry));
    fprintf("%s: %d dense, %d stride-matched patches\n",label, ...
        nnz(predictions.sampling_mode=="dense_map"), ...
        nnz(predictions.sampling_mode=="stride_matched"));
end
predictions=vertcat(prediction_parts{:});
metrics=reqml.homogeneous.summarizeExternalPredictions(predictions, ...
    ["backend","geometry","field_regime","case_label","sampling_mode"]);
roi_metrics=reqml.homogeneous.summarizeExternalPredictions( ...
    predictions(predictions.geometry~="homogeneous",:), ...
    ["backend","geometry","field_regime","case_label","sampling_mode","roi"]);
purity_metrics=reqml.homogeneous.summarizeExternalPredictions( ...
    predictions(predictions.geometry~="homogeneous",:), ...
    ["backend","geometry","field_regime","case_label","sampling_mode","purity_bin"]);
field_metrics=reqml.homogeneous.summarizeExternalPredictions(predictions, ...
    ["backend","geometry","field_regime","sampling_mode"]);
writetable(metrics,fullfile(table_root,"external_global_metrics.csv"));
writetable(roi_metrics,fullfile(table_root,"external_roi_metrics.csv"));
writetable(purity_metrics,fullfile(table_root,"external_purity_metrics.csv"));
writetable(field_metrics,fullfile(table_root,"external_field_metrics.csv"));
save(fullfile(output_root,"external_predictions.mat"),"predictions","-v7.3");
make_field_figure(field_metrics,fullfile(figure_root,"external_mape_by_field"));
manifest=struct("schema_name","reqml_external_q0_transfer_study","schema_version","1.0", ...
    "evaluation_id",string(config.evaluation_id),"source_config",config_file, ...
    "model_bundle",model_file,"model_metadata",loaded.model_metadata, ...
    "case_count",numel(config.cases), ...
    "dense_patch_count",nnz(predictions.sampling_mode=="dense_map"), ...
    "stride_patch_count",nnz(predictions.sampling_mode=="stride_matched"), ...
    "dense_patch_independence_note","Dense rows overlap and are not independent samples.", ...
    "git_head",git_head(repository_root),"created_utc",string(datetime("now","TimeZone","UTC")));
write_json(fullfile(output_root,"external_manifest.json"),manifest);
result=struct("metrics",metrics,"roi_metrics",roi_metrics, ...
    "purity_metrics",purity_metrics,"field_metrics",field_metrics, ...
    "output_root",output_root);
end

function p=make_predictions(e,q_pred,sws,c,sample_file,g)
n=height(e); q_true=double(e.q_target_from_center_truth);
stride=max(g.stride_x_px,g.stride_z_px);
matched=mod(double(e.cx)-min(double(e.cx)),stride)==0 & ...
    mod(double(e.cz)-min(double(e.cz)),stride)==0;
sampling=repmat("dense_map",n,1); sampling(matched)="stride_matched";
purity=double(e.truth_material_purity);
purity_bin=repmat("<0.7",n,1); purity_bin(purity>=.7)="0.7-0.9";
purity_bin(purity>=.9)="0.9-0.98"; purity_bin(purity>=.98)="0.98-1";
purity_bin(abs(purity-1)<=1e-12)="1";
p=table(repmat(string(c.label),n,1),repmat(string(c.backend),n,1), ...
    repmat(string(c.geometry),n,1),repmat(string(c.field_regime),n,1), ...
    repmat(sample_file,n,1),sampling,string(e.example_id),double(e.map_iz), ...
    double(e.map_ix),double(e.cx),double(e.cz),double(e.x_center_m),double(e.z_center_m), ...
    double(e.truth_material_id_center),purity,purity_bin,q_true,double(q_pred), ...
    double(q_pred)-q_true,double(e.truth_cs_center_m_s),sws.cs_pred_m_s, ...
    sws.cs_error_m_s,sws.cs_error_percent,sws.cs_absolute_error_percent,sws.sws_valid, ...
    repmat(g.patch_width_px,n,1),repmat(stride,n,1), ...
    VariableNames=["case_label","backend","geometry","field_regime","sample_file", ...
    "sampling_mode","example_id","map_iz","map_ix","cx","cz","x_center_m","z_center_m", ...
    "material_id_center","truth_material_purity","purity_bin","q_true","q_pred","q_error", ...
    "cs_true_m_s","cs_pred_m_s","cs_error_m_s","cs_error_percent", ...
    "cs_absolute_error_percent","sws_valid","patch_width_px","stride_px"]);
% Duplicate only matched rows, retaining dense rows for maps and explicitly
% labelling the statistically less-correlated metric subset.
q=p(matched,:); q.sampling_mode(:)="stride_matched"; p.sampling_mode(:)="dense_map"; p=[p;q];
end

function make_case_figure(p,path_base,geometry)
d=p(p.sampling_mode=="dense_map",:); iz=unique(d.map_iz); ix=unique(d.map_ix);
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
