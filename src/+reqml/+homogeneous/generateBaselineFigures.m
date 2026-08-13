function result = generateBaselineFigures(config_file, options)
%GENERATEBASELINEFIGURES Publication diagnostics for frozen homogeneous Q0.

arguments
    config_file {mustBeTextScalar}
    options.PredictionsCsv {mustBeTextScalar} = ""
    options.OutputDirectory {mustBeTextScalar} = ""
end

config=jsondecode(fileread(config_file));
root=string(fileparts(fileparts(fileparts(fileparts(mfilename("fullpath"))))));
output_root=reqml.config.resolveWorkspacePath( ...
    string(config.paths.output_root),RepositoryRoot=root);
predictions_csv=string(options.PredictionsCsv);
if strlength(predictions_csv)==0
    predictions_csv=fullfile(output_root,"training","q0_bagged_v1", ...
        "tables","predictions.csv");
end
output=string(options.OutputDirectory);
if strlength(output)==0
    output=fullfile(output_root,"figures","baseline_v1");
end
if ~isfile(predictions_csv)
    error("reqml:MissingBaselinePredictions","Missing %s",predictions_csv);
end
if ~isfolder(output), mkdir(output); end
source_dir=fullfile(output,"source_metrics");
if ~isfolder(source_dir), mkdir(source_dir); end
predictions=readtable(predictions_csv,TextType="string");
test=predictions(predictions.partition=="test" & predictions.sws_valid,:);
critical=predictions(predictions.cs_m_s==3 & predictions.frequency_hz==400 & ...
    ismember(predictions.field_regime,["single","directional"]),:);
metrics=make_source_tables(test,critical,source_dir);

paths=struct(); colors=lines(4); fields=["single","directional", ...
    "intermediate","diffuse"];
paths.sws_scatter=figure_path(output,"a_sws_true_vs_predicted");
f=new_figure(); hold on;
for i=1:numel(fields)
    m=test.field_regime==fields(i); scatter(test.cs_true_m_s(m), ...
        test.cs_pred_m_s(m),10,colors(i,:),"filled", ...
        "MarkerFaceAlpha",.28,"DisplayName",fields(i));
end
limits=[min([test.cs_true_m_s;test.cs_pred_m_s]), ...
    max([test.cs_true_m_s;test.cs_pred_m_s])];
plot(limits,limits,"k--","LineWidth",1.2,"DisplayName","identity");
xlim(limits); ylim(limits); axis square; xlabel("True SWS (m/s)");
ylabel("Predicted SWS (m/s)"); title("Frozen Q0: test predictions");
legend("Location","best");
text(.03,.96,sprintf("R^2 = %.4f   MAPE = %.3f%%", ...
    metrics.overall.r_squared,metrics.overall.sws_mape), ...
    "Units","normalized","VerticalAlignment","top"); save_figure(f,paths.sws_scatter);

paths.sws_residual=figure_path(output,"b_sws_percent_error_vs_truth");
f=new_figure(); hold on;
for i=1:numel(fields)
    m=test.field_regime==fields(i); scatter(test.cs_true_m_s(m), ...
        test.cs_error_percent(m),9,colors(i,:),"filled", ...
        "MarkerFaceAlpha",.25,"DisplayName",fields(i));
end
yline(0,"k--"); xlabel("True SWS (m/s)"); ylabel("Signed error (%)");
title("SWS residuals by true speed"); legend("Location","best");
save_figure(f,paths.sws_residual);

paths.by_cs=bar_plot(metrics.by_cs,"cs_m_s","SWS (m/s)", ...
    "c_sws_mape_by_true_sws",output);
paths.by_frequency=bar_plot(metrics.by_frequency,"frequency_hz", ...
    "Frequency (Hz)","d_sws_mape_by_frequency",output);
dx=metrics.by_dx; dx.dx_mm=1e3*dx.dx_m;
paths.by_dx=bar_plot(dx,"dx_mm","Grid spacing (mm)", ...
    "e_sws_mape_by_dx",output);
paths.by_field=bar_plot(metrics.by_field,"field_regime","Field regime", ...
    "f_sws_mape_by_field",output);
paths.cs_frequency=heatmap_plot(metrics.cs_frequency,"frequency_hz", ...
    "cs_m_s","Frequency (Hz)","SWS (m/s)", ...
    "g_cs_frequency_test_mape",output);
paths.cs_field=heatmap_plot(metrics.cs_field,"field_regime","cs_m_s", ...
    "Field regime","SWS (m/s)","h_cs_field_test_mape",output);
paths.frequency_field=heatmap_plot(metrics.frequency_field,"field_regime", ...
    "frequency_hz","Field regime","Frequency (Hz)", ...
    "i_frequency_field_test_mape",output);

paths.q_scatter=figure_path(output,"j_q_true_vs_predicted");
f=new_figure(); scatter(test.q_true,test.q_pred,9,test.cs_true_m_s, ...
    "filled","MarkerFaceAlpha",.25); hold on;
q_lim=[min([test.q_true;test.q_pred]),max([test.q_true;test.q_pred])];
plot(q_lim,q_lim,"k--","LineWidth",1.2); xlim(q_lim); ylim(q_lim);
axis square; colorbar; xlabel("True q"); ylabel("Predicted q");
title("Frozen Q0: test quantiles"); save_figure(f,paths.q_scatter);

paths.q_residual=figure_path(output,"k_q_residual_distribution");
f=new_figure(); histogram(test.q_error,[metrics.q_histogram.bin_lower; ...
    metrics.q_histogram.bin_upper(end)], ...
    "Normalization","probability","FaceColor",[.18 .45 .72]);
xline(0,"k--"); xlabel("q prediction residual"); ylabel("Probability");
title("Q residual distribution: test partition"); save_figure(f,paths.q_residual);

paths.critical=figure_path(output,"l_critical_cs3_f400_distributions");
f=figure("Visible","off","Color","w","Position",[100 100 1050 650]);
t=tiledlayout(2,2,"TileSpacing","compact","Padding","compact");
for i=1:2
    current=critical(critical.field_regime==fields(i),:);
    nexttile(i); histogram(current.q_error,35,"Normalization","probability", ...
        "FaceColor",colors(i,:)); xline(0,"k--");
    xlabel("q residual"); ylabel("Probability"); title(fields(i));
    nexttile(i+2); histogram(current.cs_error_percent,35, ...
        "Normalization","probability","FaceColor",colors(i,:));
    xline(0,"k--"); xlabel("Signed SWS error (%)"); ylabel("Probability");
end
title(t,"Critical condition: SWS=3 m/s, f=400 Hz (grouped OOF)");
save_figure(f,paths.critical);

result=struct("paths",paths,"metrics",metrics,"output_directory",output, ...
    "test_count",height(test),"critical_count",height(critical));
end


function metrics=make_source_tables(test,critical,source_dir)
writetable(test,fullfile(source_dir,"test_predictions.csv"));
writetable(critical,fullfile(source_dir,"critical_cs3_f400_predictions.csv"));
metrics=struct();
metrics.by_cs=reqml.homogeneous.summarizeQ0ByGroup(test,"cs_m_s");
metrics.by_frequency=reqml.homogeneous.summarizeQ0ByGroup(test,"frequency_hz");
metrics.by_dx=reqml.homogeneous.summarizeQ0ByGroup(test,"dx_m");
metrics.by_field=reqml.homogeneous.summarizeQ0ByGroup(test,"field_regime");
metrics.cs_frequency=reqml.homogeneous.summarizeQ0ByGroup( ...
    test,["cs_m_s","frequency_hz"]);
metrics.cs_field=reqml.homogeneous.summarizeQ0ByGroup( ...
    test,["cs_m_s","field_regime"]);
metrics.frequency_field=reqml.homogeneous.summarizeQ0ByGroup( ...
    test,["frequency_hz","field_regime"]);
overall=reqml.homogeneous.summarizeQ0ByGroup( ...
    addvars(test,repmat("test",height(test),1), ...
    NewVariableNames="all_rows"),"all_rows");
overall.r_squared=1-sum((test.cs_pred_m_s-test.cs_true_m_s).^2)/ ...
    sum((test.cs_true_m_s-mean(test.cs_true_m_s)).^2);
metrics.overall=overall;
[counts,edges]=histcounts(test.q_error,50);
metrics.q_histogram=table(edges(1:end-1)',edges(2:end)',counts', ...
    VariableNames=["bin_lower","bin_upper","count"]);
names=fieldnames(metrics);
for i=1:numel(names)
    table_value=metrics.(names{i});
    if istable(table_value)
        writetable(table_value,fullfile(source_dir,string(names{i})+".csv"));
    end
end
end


function path=bar_plot(data,x_name,x_label,name,output)
path=figure_path(output,name); f=new_figure();
x=data.(x_name); if isstring(x), x=categorical(x); end
bar(x,data.sws_mape,"FaceColor",[.18 .45 .72]); hold on;
plot(x,data.sws_bias_percent,"o-","LineWidth",1.2,"Color",[.75 .25 .2]);
yline(0,"k:"); ylabel("Percent"); xlabel(x_label);
legend(["MAPE","Bias"],"Location","best"); title("Test SWS error");
save_figure(f,path);
end
function path=heatmap_plot(data,x_name,y_name,x_label,y_label,name,output)
path=figure_path(output,name); xv=unique(data.(x_name),"stable");
yv=sort(unique(data.(y_name))); matrix=nan(numel(yv),numel(xv));
for i=1:height(data)
    xi=find(xv==data.(x_name)(i),1); yi=find(yv==data.(y_name)(i),1);
    matrix(yi,xi)=data.sws_mape(i);
end
f=new_figure(); imagesc(matrix); colorbar; colormap(parula);
xticks(1:numel(xv)); xticklabels(string(xv)); yticks(1:numel(yv));
yticklabels(string(yv)); xlabel(x_label); ylabel(y_label);
title("Test SWS MAPE (%)");
for row=1:size(matrix,1)
    for col=1:size(matrix,2)
        text(col,row,sprintf("%.2f",matrix(row,col)), ...
            "HorizontalAlignment","center","Color","w","FontWeight","bold");
    end
end
save_figure(f,path);
end
function f=new_figure()
f=figure("Visible","off","Color","w","Position",[100 100 800 600]);
set(f,"DefaultAxesFontName","Helvetica","DefaultAxesFontSize",11);
end
function path=figure_path(output,name)
path=fullfile(output,string(name));
end
function save_figure(f,path)
exportgraphics(f,path+".png","Resolution",300);
exportgraphics(f,path+".pdf","ContentType","vector"); close(f);
end
