function result = analyze_bilayer_interface_profiles()

repo_root = string(fileparts(fileparts(fileparts(mfilename("fullpath")))));
eval_root = fullfile(repo_root,"outputs","validation","eikonal_validation_v1","evaluation");
runs_root = fullfile(eval_root,"runs");

cfg = jsondecode(fileread(fullfile( ...
    repo_root,"configs","validation","eikonal_validation_v1.json")));

theta = double(cfg.design.bilayer_geometry.normal_angle_rad);
offset = double(cfg.design.bilayer_geometry.offset_m);

S = readtable(fullfile(eval_root,"run_summary.csv"));
S = S(string(S.geometry)=="bilayer",:);

C = jsondecode(fileread(fullfile( ...
    repo_root,"outputs","validation","eikonal_validation_v1", ...
    "simulations","bilayer","eikonal_validation_v1_bilayer", ...
    "campaign_summary.json")));

run_id_lookup = strings(numel(C.runs),1);
design_id_lookup = strings(numel(C.runs),1);

for j=1:numel(C.runs)
    run_id_lookup(j)=string(C.runs(j).run_id);
    design_id_lookup(j)=string(C.runs(j).design_id);
end

rows = cell(0,1);
profile_rows = cell(0,1);

bin_width_mm = 1.0;
edges_mm = -35:bin_width_mm:35;

for i=1:height(S)

    run_id=string(S.design_id(i));
    m=find(run_id_lookup==run_id,1);
    design_id=design_id_lookup(m);

    target_cs=infer_target_cs(design_id);
    regime=infer_field_regime(design_id);
    f=double(S.frequency_hz(i));

    d=load(fullfile(runs_root,run_id,"patch_metrics.mat"),"T");
    T=d.T;
    T=T(logical(T.sws_valid),:);

    x=double(T.x_center_m);
    z=double(T.z_center_m);

    signed_distance_m = x*cos(theta) + z*sin(theta) - offset;
    signed_distance_mm = 1e3*signed_distance_m;

    bins=discretize(signed_distance_mm,edges_mm);

    for b=1:numel(edges_mm)-1
        mask=bins==b;
        if nnz(mask)<5, continue; end

        Tb=T(mask,:);

        profile_rows{end+1,1}=struct( ...
            "design_id",string(design_id), ...
            "target_sws_m_s",target_cs, ...
            "frequency_hz",f, ...
            "field_regime",string(regime), ...
            "distance_mm",mean(edges_mm(b:b+1)), ...
            "patch_count",height(Tb), ...
            "cs_pred_median_m_s",median(Tb.cs_pred_m_s,"omitnan"), ...
            "cs_pred_q25_m_s",prctile(Tb.cs_pred_m_s,25), ...
            "cs_pred_q75_m_s",prctile(Tb.cs_pred_m_s,75), ...
            "mape_percent",mean(Tb.cs_absolute_error_percent,"omitnan"), ...
            "median_ape_percent",median(Tb.cs_absolute_error_percent,"omitnan"), ...
            "bias_percent",mean(Tb.cs_error_percent,"omitnan"), ...
            "purity_median",median(Tb.truth_material_purity,"omitnan"));
    end

    transition_width_mm = estimate_transition_width( ...
        signed_distance_mm,double(T.cs_pred_m_s),target_cs);

    rows{end+1,1}=struct( ...
        "design_id",string(design_id), ...
        "target_sws_m_s",target_cs, ...
        "frequency_hz",f, ...
        "field_regime",string(regime), ...
        "transition_width_10_90_mm",transition_width_mm);
end

P=struct2table(vertcat(profile_rows{:}));
W=struct2table(vertcat(rows{:}));

out_root=fullfile(eval_root,"bilayer_interface_analysis");
fig_root=fullfile(out_root,"figures");
if ~isfolder(fig_root), mkdir(fig_root); end

writetable(P,fullfile(out_root,"interface_profiles.csv"));
writetable(W,fullfile(out_root,"transition_width_summary.csv"));

xlsx=fullfile(out_root,"bilayer_interface_metrics.xlsx");
if isfile(xlsx), delete(xlsx); end
writetable(P,xlsx,"Sheet","Profiles");
writetable(W,xlsx,"Sheet","TransitionWidth");

make_profile_figures(P,fig_root);

result=struct("profiles",P,"transition_width",W,"output_root",out_root);

end

function w=estimate_transition_width(distance_mm,cs_pred,target_cs)

[d,ord]=sort(distance_mm);
y=cs_pred(ord);

% Bin lightly for robustness.
edges=-35:0.5:35;
b=discretize(d,edges);
centers=(edges(1:end-1)+edges(2:end))/2;

med=nan(size(centers));
for i=1:numel(centers)
    if nnz(b==i)>=5
        med(i)=median(y(b==i),"omitnan");
    end
end

valid=isfinite(med);
centers=centers(valid);
med=med(valid);

if numel(med)<5
    w=NaN;
    return;
end

low=2 + 0.1*(target_cs-2);
high=2 + 0.9*(target_cs-2);

d10=interp_crossing(centers,med,low);
d90=interp_crossing(centers,med,high);

w=abs(d90-d10);

end

function d=interp_crossing(x,y,target)

d=NaN;
for i=1:numel(x)-1
    if (y(i)-target)*(y(i+1)-target)<=0 && y(i)~=y(i+1)
        t=(target-y(i))/(y(i+1)-y(i));
        d=x(i)+t*(x(i+1)-x(i));
        return;
    end
end

end

function make_profile_figures(P,fig_root)

targets=[3 4];
regimes=["directional","intermediate","diffuse_like"];
freqs=[300 400 500 600];

for t=targets
    for r=regimes

        fig=figure("Visible","off","Color","w","Position",[100 100 1400 900]);
        tiledlayout(2,2,"TileSpacing","compact","Padding","compact");

        for k=1:numel(freqs)
            f=freqs(k);
            nexttile; hold on;

            d=P(P.target_sws_m_s==t & ...
                string(P.field_regime)==r & ...
                P.frequency_hz==f,:);

            d=sortrows(d,"distance_mm");

            yyaxis left
            plot(d.distance_mm,d.cs_pred_median_m_s,"-o","LineWidth",1.4);
            ylabel("Predicted c_s (m/s)");
            yline(2,"--");
            yline(t,"--");

            yyaxis right
            plot(d.distance_mm,d.mape_percent,"-","LineWidth",1.2);
            ylabel("MAPE (%)");

            xline(0,":","LineWidth",1.2);

            xlabel("Signed distance to interface (mm)");
            title(sprintf("%d Hz",f));
            grid on;
        end

        sgtitle(sprintf("Bilayer 2 -> %d m/s | %s",t,r), ...
            "Interpreter","none");

        exportgraphics(fig,fullfile(fig_root, ...
            sprintf("profile_t%d_%s.png",t,r)), ...
            "Resolution",250);

        close(fig);
    end
end

end

function regime=infer_field_regime(id)
d=lower(string(id));
if contains(d,"directional"), regime="directional";
elseif contains(d,"intermediate"), regime="intermediate";
elseif contains(d,"diffuse_like"), regime="diffuse_like";
else, error("Cannot infer regime");
end
end

function cs=infer_target_cs(id)
d=lower(string(id));
if contains(d,"_t3_"), cs=3;
elseif contains(d,"_t4_"), cs=4;
else, error("Cannot infer target cs");
end
end
