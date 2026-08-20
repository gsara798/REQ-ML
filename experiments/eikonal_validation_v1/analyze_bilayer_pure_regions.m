function result = analyze_bilayer_pure_regions()

repo_root = string(fileparts(fileparts(fileparts(mfilename("fullpath")))));
eval_root = fullfile(repo_root,"outputs","validation","eikonal_validation_v1","evaluation");
runs_root = fullfile(eval_root,"runs");

S = readtable(fullfile(eval_root,"run_summary.csv"));
S = S(string(S.geometry)=="bilayer",:);
assert(height(S)==24,"Expected 24 bilayer runs, found %d.",height(S));

campaign_summary_file = fullfile( ...
    repo_root,"outputs","validation","eikonal_validation_v1", ...
    "simulations","bilayer","eikonal_validation_v1_bilayer", ...
    "campaign_summary.json");

C = jsondecode(fileread(campaign_summary_file));
run_id_lookup = strings(numel(C.runs),1);
design_id_lookup = strings(numel(C.runs),1);

for j=1:numel(C.runs)
    run_id_lookup(j)=string(C.runs(j).run_id);
    design_id_lookup(j)=string(C.runs(j).design_id);
end

rows = cell(0,1);

for i=1:height(S)

    run_id = string(S.design_id(i));
    m = find(run_id_lookup==run_id,1);
    assert(~isempty(m),"Could not map %s.",run_id);

    design_id = design_id_lookup(m);
    target_cs = infer_target_cs(design_id);
    regime = infer_field_regime(design_id);
    f = double(S.frequency_hz(i));

    d = load(fullfile(runs_root,run_id,"patch_metrics.mat"),"T");
    T = d.T;

    keep = logical(T.sws_valid) & ...
        abs(double(T.truth_material_purity)-1)<=1e-12;

    T = T(keep,:);

    bg = T(abs(T.cs_true_m_s-2)<1e-12,:);
    stiff = T(abs(T.cs_true_m_s-target_cs)<1e-12,:);

    assert(~isempty(bg),"No pure background for %s.",design_id);
    assert(~isempty(stiff),"No pure stiff region for %s.",design_id);

    rows{end+1,1}=summarize_region( ...
        design_id,run_id,"background",2,target_cs,f,regime,bg);

    rows{end+1,1}=summarize_region( ...
        design_id,run_id,"stiff_layer",target_cs,target_cs,f,regime,stiff);
end

A=struct2table(vertcat(rows{:}));

out_root=fullfile(eval_root,"bilayer_pure_analysis");
fig_root=fullfile(out_root,"figures");
if ~isfolder(fig_root), mkdir(fig_root); end

writetable(A,fullfile(out_root,"bilayer_pure_summary.csv"));

xlsx=fullfile(out_root,"bilayer_pure_regions_metrics.xlsx");
if isfile(xlsx), delete(xlsx); end
writetable(A,xlsx,"Sheet","Summary");
writetable(A(A.region=="background",:),xlsx,"Sheet","Background");
writetable(A(A.region=="stiff_layer",:),xlsx,"Sheet","StiffLayer");

make_cs_figure(A(A.region=="background",:), ...
    fullfile(fig_root,"background_cs_vs_frequency.png"),"background");
make_mape_figure(A(A.region=="background",:), ...
    fullfile(fig_root,"background_mape_vs_frequency.png"),"background");

make_cs_figure(A(A.region=="stiff_layer",:), ...
    fullfile(fig_root,"stiff_layer_cs_vs_frequency.png"),"stiff_layer");
make_mape_figure(A(A.region=="stiff_layer",:), ...
    fullfile(fig_root,"stiff_layer_mape_vs_frequency.png"),"stiff_layer");

result=struct("summary",A,"output_root",out_root);
disp(A);

end

function row=summarize_region(design_id,run_id,region,true_cs,target_cs,f,regime,T)

pred=double(T.cs_pred_m_s);
ape=double(T.cs_absolute_error_percent);
err=double(T.cs_error_percent);

row=struct( ...
    "design_id",string(design_id), ...
    "run_id",string(run_id), ...
    "region",string(region), ...
    "target_sws_m_s",target_cs, ...
    "frequency_hz",f, ...
    "field_regime",string(regime), ...
    "cs_true_m_s",true_cs, ...
    "patch_count",height(T), ...
    "cs_pred_mean_m_s",mean(pred,"omitnan"), ...
    "cs_pred_median_m_s",median(pred,"omitnan"), ...
    "cs_pred_std_m_s",std(pred,0,"omitnan"), ...
    "cs_pred_q25_m_s",prctile(pred,25), ...
    "cs_pred_q75_m_s",prctile(pred,75), ...
    "mape_percent",mean(ape,"omitnan"), ...
    "bias_percent",mean(err,"omitnan"), ...
    "median_ape_percent",median(ape,"omitnan"));
end

function regime=infer_field_regime(id)
d=lower(string(id));
if contains(d,"directional")
    regime="directional";
elseif contains(d,"intermediate")
    regime="intermediate";
elseif contains(d,"diffuse_like")
    regime="diffuse_like";
else
    error("Cannot infer regime from %s",id);
end
end

function cs=infer_target_cs(id)
d=lower(string(id));
if contains(d,"_t3_"), cs=3;
elseif contains(d,"_t4_"), cs=4;
else, error("Cannot infer target cs from %s",id);
end
end

function make_cs_figure(A,path,region)

targets=[3 4];
regimes=["directional","intermediate","diffuse_like"];

fig=figure("Visible","off","Color","w","Position",[100 100 1050 430]);
tiledlayout(1,2,"TileSpacing","compact","Padding","compact");

for k=1:2
    target=targets(k);
    nexttile; hold on;

    d0=A(A.target_sws_m_s==target,:);
    truth=unique(d0.cs_true_m_s);
    yline(truth,"--","LineWidth",1.2,"DisplayName","truth = "+string(truth));

    for r=1:numel(regimes)
        d=d0(string(d0.field_regime)==regimes(r),:);
        d=sortrows(d,"frequency_hz");

        y=d.cs_pred_median_m_s;
        lo=y-d.cs_pred_q25_m_s;
        hi=d.cs_pred_q75_m_s-y;

        errorbar(d.frequency_hz,y,lo,hi,"-o","LineWidth",1.5, ...
            "DisplayName",regimes(r));
    end

    xlabel("Frequency (Hz)");
    ylabel("Predicted c_s (m/s)");

    if region=="background"
        title(sprintf("Bilayer background, 2 -> %d m/s",target));
    else
        title(sprintf("Stiff layer, true c_s = %d m/s",target));
    end
    grid on; legend("Location","best");
end

exportgraphics(fig,path,"Resolution",250);
close(fig);
end

function make_mape_figure(A,path,region)

targets=[3 4];
regimes=["directional","intermediate","diffuse_like"];

fig=figure("Visible","off","Color","w","Position",[100 100 1050 430]);
tiledlayout(1,2,"TileSpacing","compact","Padding","compact");

for k=1:2
    target=targets(k);
    nexttile; hold on;

    for r=1:numel(regimes)
        d=A(A.target_sws_m_s==target & string(A.field_regime)==regimes(r),:);
        d=sortrows(d,"frequency_hz");
        plot(d.frequency_hz,d.mape_percent,"-o","LineWidth",1.5, ...
            "DisplayName",regimes(r));
    end

    xlabel("Frequency (Hz)");
    ylabel("MAPE (%)");

    if region=="background"
        title(sprintf("Bilayer background, 2 -> %d m/s",target));
    else
        title(sprintf("Stiff layer, true c_s = %d m/s",target));
    end
    grid on; legend("Location","best");
end

exportgraphics(fig,path,"Resolution",250);
close(fig);
end
