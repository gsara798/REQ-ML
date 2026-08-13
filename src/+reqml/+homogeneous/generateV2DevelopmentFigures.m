function result=generateV2DevelopmentFigures(config_file,options)
%GENERATEV2DEVELOPMENTFIGURES Publication diagnostics for Q0 v2 closure.
arguments
    config_file {mustBeTextScalar}
    options.OutputDirectory {mustBeTextScalar} = ""
end
config=jsondecode(fileread(config_file));
repo=string(fileparts(fileparts(fileparts(fileparts(mfilename("fullpath"))))));
root=reqml.config.resolveWorkspacePath(string(config.paths.output_root),RepositoryRoot=repo);
output=string(options.OutputDirectory); if strlength(output)==0, output=fullfile(root,"figures","development_v2"); end
if ~isfolder(output), mkdir(output); end
in_domain=load_test(fullfile(root,"training",string(config.training.model_id),"tables","predictions.csv"));
sws=load_test(fullfile(root,"generalization","alternating_sws","tables","predictions.csv"));
angular=load_test(fullfile(root,"generalization","alternating_angular","tables","predictions.csv"));
paths=struct();

paths.in_domain_scatter=save_scatter(in_domain,output,"a_in_domain_true_vs_predicted");
paths.sws_distributions=save_sws_box(sws,output,"b_sws_interpolation_distributions");
paths.sws_interpolation=save_group_bars(sws,"cs_true_m_s", ...
    "Held-out SWS (m/s)",output,"c_sws_interpolation_error");
paths.angular_interpolation=save_group_bars(angular,"angular_support_fraction", ...
    "Angular support fraction",output,"d_angular_interpolation_error");
paths.by_M=save_group_bars(in_domain,"REQ_M","REQ M",output,"e_error_by_M");
paths.by_frequency=save_group_bars(in_domain,"frequency_hz", ...
    "Frequency (Hz)",output,"f_error_by_frequency");
paths.by_angular=save_group_bars(in_domain,"angular_support_fraction", ...
    "Angular support fraction",output,"g_error_by_angular_support");
paths.sws_angular=save_heatmap(in_domain,"angular_support_fraction","cs_true_m_s", ...
    "Angular support fraction","SWS (m/s)",output,"h_sws_by_angular_heatmap");
paths.M_sws=save_heatmap(in_domain,"cs_true_m_s","REQ_M", ...
    "SWS (m/s)","REQ M",output,"i_M_by_sws_heatmap");
paths.M_angular=save_heatmap(in_domain,"angular_support_fraction","REQ_M", ...
    "Angular support fraction","REQ M",output,"j_M_by_angular_heatmap");
paths.q_scatter=save_q_scatter(in_domain,output,"k_q_true_vs_predicted");
paths.residuals=save_residuals(in_domain,output,"l_residual_distributions");

manifest=struct("schema_name","reqml_homogeneous_q0_v2_development_figures", ...
    "schema_version","2.0","source_config",string(config_file),"paths",paths, ...
    "in_domain_test_count",height(in_domain),"sws_test_count",height(sws), ...
    "angular_test_count",height(angular), ...
    "created_utc",string(datetime("now","TimeZone","UTC")));
write_json(fullfile(output,"figure_manifest.json"),manifest);
result=struct("paths",paths,"manifest",manifest,"output_directory",output);
end

function p=load_test(path)
if ~isfile(path), error("reqml:MissingV2DevelopmentPredictions","Missing %s",path); end
p=readtable(path,TextType="string"); p=p(p.partition=="test" & p.sws_valid,:);
end

function path=save_scatter(p,output,name)
f=new_figure(); scatter(p.cs_true_m_s,p.cs_pred_m_s,8,p.REQ_M,"filled", ...
    "MarkerFaceAlpha",.2); hold on; limits=[min([p.cs_true_m_s;p.cs_pred_m_s]),max([p.cs_true_m_s;p.cs_pred_m_s])];
plot(limits,limits,"k--","LineWidth",1.2); axis square; xlim(limits); ylim(limits);
xlabel("True SWS (m/s)"); ylabel("Predicted SWS (m/s)"); title("In-domain grouped test");
cb=colorbar; cb.Label.String="REQ M"; path=save_figure(f,output,name);
end

function path=save_sws_box(p,output,name)
f=new_figure(); boxchart(categorical(p.cs_true_m_s),p.cs_pred_m_s, ...
    "GroupByColor",categorical(p.REQ_M)); hold on;
levels=sort(unique(p.cs_true_m_s)); plot(categorical(levels),levels,"k.","MarkerSize",16);
xlabel("Held-out SWS (m/s)"); ylabel("Predicted SWS (m/s)");
title("Alternating-grid SWS interpolation"); legend("Location","best");
path=save_figure(f,output,name);
end

function path=save_group_bars(p,group,xlabel_text,output,name)
t=reqml.homogeneous.summarizeQ0ByGroup(p,string(group));
x=t.(group); if isnumeric(x), labels=compose("%.4g",x); else, labels=string(x); end
f=new_figure(); bar(categorical(labels,labels),[t.sws_mape,t.sws_bias_percent]);
yline(0,"k:"); ylabel("Percent"); xlabel(xlabel_text); legend(["MAPE","Bias"],"Location","best");
title("SWS prediction error"); path=save_figure(f,output,name);
end

function path=save_heatmap(p,xname,yname,xlabel_text,ylabel_text,output,name)
t=reqml.homogeneous.summarizeQ0ByGroup(p,[string(yname),string(xname)]);
x=sort(unique(t.(xname))); y=sort(unique(t.(yname))); values=nan(numel(y),numel(x));
for i=1:height(t), values(y==t.(yname)(i),x==t.(xname)(i))=t.sws_mape(i); end
f=new_figure(); imagesc(values); axis xy; colorbar; colormap(parula);
xticks(1:numel(x)); xticklabels(compose("%.4g",x)); yticks(1:numel(y)); yticklabels(compose("%.4g",y));
xlabel(xlabel_text); ylabel(ylabel_text); title("SWS MAPE (%)");
for row=1:size(values,1)
    for col=1:size(values,2)
        text(col,row,compose("%.2f",values(row,col)), ...
            "HorizontalAlignment","center","Color","w");
    end
end
path=save_figure(f,output,name);
end

function path=save_q_scatter(p,output,name)
f=new_figure(); scatter(p.q_true,p.q_pred,8,p.cs_true_m_s,"filled","MarkerFaceAlpha",.2); hold on;
limits=[min([p.q_true;p.q_pred]),max([p.q_true;p.q_pred])]; plot(limits,limits,"k--");
axis square; xlim(limits); ylim(limits); xlabel("True q"); ylabel("Predicted q");
title("Q0 target prediction"); colorbar; path=save_figure(f,output,name);
end

function path=save_residuals(p,output,name)
f=figure("Visible","off","Color","w","Position",[100 100 1050 450]);
tiledlayout(1,2,"TileSpacing","compact","Padding","compact");
nexttile; histogram(p.q_error,60,"Normalization","probability"); xline(0,"k--");
xlabel("q residual"); ylabel("Probability"); title("Quantile residual");
nexttile; histogram(p.cs_error_percent,60,"Normalization","probability"); xline(0,"k--");
xlabel("Signed SWS error (%)"); ylabel("Probability"); title("SWS residual");
path=save_figure(f,output,name);
end

function f=new_figure()
f=figure("Visible","off","Color","w","Position",[100 100 900 620]);
set(f,"DefaultAxesFontName","Helvetica","DefaultAxesFontSize",11);
end

function path=save_figure(f,output,name)
path=fullfile(output,string(name)); exportgraphics(f,path+".png","Resolution",300);
exportgraphics(f,path+".pdf","ContentType","vector"); close(f);
end

function write_json(path,value)
fid=fopen(path,"w"); if fid<0, error("reqml:CannotWriteV2Figures","Cannot write %s",path); end
cleanup=onCleanup(@() fclose(fid)); fprintf(fid,"%s\n",jsonencode(value,PrettyPrint=true));
end
