function result = close_eikonal_validation()

repo_root = string(fileparts(fileparts(fileparts(mfilename("fullpath")))));

eval_root = fullfile( ...
    repo_root,"outputs","validation","eikonal_validation_v1","evaluation");

%% Load completed analyses

H = readtable(fullfile( ...
    eval_root,"homogeneous_analysis","homogeneous_summary.csv"));

B = readtable(fullfile( ...
    eval_root,"bilayer_pure_analysis","bilayer_pure_summary.csv"));

I = readtable(fullfile( ...
    eval_root,"inclusion_pure_analysis","inclusion_pure_summary.csv"));

BW = readtable(fullfile( ...
    eval_root,"bilayer_interface_analysis","transition_width_summary.csv"));

IW = readtable(fullfile( ...
    eval_root,"inclusion_interface_analysis","inclusion_transition_summary.csv"));

%% Matched transfer

BM = make_matched_table(B,H);
IM = make_matched_table(I,H);

%% Output directories

out_root = fullfile(eval_root,"eikonal_closure");
fig_root = fullfile(out_root,"provisional_figures");

if ~isfolder(fig_root)
    mkdir(fig_root);
end

%% CSVs

writetable(BM,fullfile(out_root,"bilayer_matched_transfer.csv"));
writetable(IM,fullfile(out_root,"inclusion_matched_transfer.csv"));

%% Excel summary

xlsx = fullfile(out_root,"eikonal_validation_summary.xlsx");
if isfile(xlsx), delete(xlsx); end

writetable(H, xlsx, "Sheet","Homogeneous");
writetable(B, xlsx, "Sheet","BilayerPure");
writetable(I, xlsx, "Sheet","InclusionPure");
writetable(BM,xlsx, "Sheet","BilayerMatched");
writetable(IM,xlsx, "Sheet","InclusionMatched");
writetable(BW,xlsx, "Sheet","BilayerTransition");
writetable(IW,xlsx, "Sheet","InclusionTransition");

%% Compact aggregate summary

summary = build_aggregate_summary(H,B,I,BM,IM);
writetable(summary,xlsx,"Sheet","AggregateSummary");
writetable(summary,fullfile(out_root,"aggregate_summary.csv"));

%% Provisional figures

copy_if_exists( ...
    fullfile(eval_root,"homogeneous_analysis","figures", ...
    "homogeneous_mape_vs_frequency.png"), ...
    fullfile(fig_root,"01_homogeneous_mape.png"));

copy_if_exists( ...
    fullfile(eval_root,"homogeneous_analysis","figures", ...
    "homogeneous_cs_vs_frequency.png"), ...
    fullfile(fig_root,"02_homogeneous_cs.png"));

copy_if_exists( ...
    fullfile(eval_root,"bilayer_interface_analysis","figures", ...
    "profile_t4_directional.png"), ...
    fullfile(fig_root,"03_bilayer_profile_provisional.png"));

copy_if_exists( ...
    fullfile(eval_root,"inclusion_interface_analysis","figures", ...
    "profile_t4_directional.png"), ...
    fullfile(fig_root,"04_inclusion_profile_provisional.png"));

copy_if_exists( ...
    fullfile(eval_root,"inclusion_interface_analysis","figures", ...
    "transition_width_vs_frequency.png"), ...
    fullfile(fig_root,"05_inclusion_transition_width_provisional.png"));

%% Closure README

readme_file = fullfile(out_root,"README.txt");

fid = fopen(readme_file,"w");
assert(fid>=0,"Could not write %s",readme_file);
cleanup = onCleanup(@() fclose(fid));

fprintf(fid,"REQ-ML Eikonal Validation Closure\n");
fprintf(fid,"=================================\n\n");

fprintf(fid,"Campaign: eikonal_validation_v1\n");
fprintf(fid,"Physical conditions: 84\n");
fprintf(fid,"Domain: 70 x 70 mm\n");
fprintf(fid,"Inclusion diameter: 35 mm\n");
fprintf(fid,"REQ M: 2\n");
fprintf(fid,"Evaluation StepPixels: 2\n\n");

fprintf(fid,"Scope\n");
fprintf(fid,"-----\n");
fprintf(fid,"Homogeneous, bilayer, and circular-inclusion Eikonal wavefields.\n");
fprintf(fid,"Frequencies: 300, 400, 500, 600 Hz.\n");
fprintf(fid,"Field regimes: directional, intermediate, diffuse-like.\n");
fprintf(fid,"Local SWS values: 2, 3, 4 m/s.\n\n");

fprintf(fid,"Scientific interpretation\n");
fprintf(fid,"-------------------------\n");
fprintf(fid,"%s\n\n", ...
    "The frozen Q0 model transfers successfully from homogeneous to " + ...
    "heterogeneous Eikonal wavefields. In material-pure regions, SWS " + ...
    "estimates remain close to matched homogeneous baselines across " + ...
    "bilayer and circular-inclusion geometries. Directional fields are " + ...
    "the most robust regime. Intermediate and diffuse-like fields show " + ...
    "larger condition-dependent variability, but the heterogeneous " + ...
    "materials remain quantitatively recoverable away from interfaces.");

fprintf(fid,"%s\n\n", ...
    "The largest errors are spatially localized around material " + ...
    "interfaces, where a single local SWS becomes intrinsically mixed " + ...
    "within the finite REQ support. Interface error increases with " + ...
    "contrast and is more pronounced for the circular inclusion than " + ...
    "for the bilayer. Transition widths generally decrease with " + ...
    "frequency. The inclusion 300-Hz intermediate condition is a clear " + ...
    "difficult case, but does not represent a systematic failure across " + ...
    "the validation matrix.");

fprintf(fid,"Gate decision\n");
fprintf(fid,"-------------\n");
fprintf(fid,"PASS: frozen Q0 passes the Eikonal heterogeneous-transfer gate.\n");
fprintf(fid,"No Q1 heterogeneous retraining is justified at this stage.\n\n");

fprintf(fid,"Next steps\n");
fprintf(fid,"----------\n");
fprintf(fid,"1. Continuous angular-aperture q(Omega) diagnostic using the final Q0 pipeline.\n");
fprintf(fid,"2. Controlled final k-Wave validation.\n");
fprintf(fid,"3. Reconsider retraining only if full-wave validation shows systematic failure away from interfaces.\n\n");

fprintf(fid,"Figure status\n");
fprintf(fid,"-------------\n");
fprintf(fid,"Files under provisional_figures are working selections only.\n");
fprintf(fid,"Final IUS figures will be selected after full-wave validation.\n");

%% Console summary

fprintf("\nEIKONAL VALIDATION CLOSED\n");
fprintf("Gate decision: PASS\n");
fprintf("Frozen model retained: Q0\n");
fprintf("No Q1 retraining at this stage.\n");
fprintf("Summary workbook:\n  %s\n",xlsx);
fprintf("Closure README:\n  %s\n",readme_file);

disp(summary);

result = struct( ...
    "gate","PASS", ...
    "summary",summary, ...
    "bilayer_matched",BM, ...
    "inclusion_matched",IM, ...
    "output_root",out_root);

end


function M = make_matched_table(X,H)

rows = cell(height(X),1);

for i=1:height(X)

    local_cs = double(X.cs_true_m_s(i));
    f = double(X.frequency_hz(i));
    regime = string(X.field_regime(i));

    match = ...
        H.cs_true_m_s==local_cs & ...
        H.frequency_hz==f & ...
        string(H.field_regime)==regime;

    assert(nnz(match)==1, ...
        "Expected one homogeneous match: cs=%g, f=%g, regime=%s", ...
        local_cs,f,regime);

    h = H(match,:);

    rows{i}=struct( ...
        "design_id",string(X.design_id(i)), ...
        "region",string(X.region(i)), ...
        "target_sws_m_s",double(X.target_sws_m_s(i)), ...
        "local_true_sws_m_s",local_cs, ...
        "frequency_hz",f, ...
        "field_regime",regime, ...
        "heterogeneous_mape_percent",double(X.mape_percent(i)), ...
        "homogeneous_mape_percent",double(h.mape_percent), ...
        "delta_mape_percent",double(X.mape_percent(i))-double(h.mape_percent), ...
        "heterogeneous_bias_percent",double(X.bias_percent(i)), ...
        "homogeneous_bias_percent",double(h.bias_percent), ...
        "delta_bias_percent",double(X.bias_percent(i))-double(h.bias_percent), ...
        "heterogeneous_cs_median_m_s",double(X.cs_pred_median_m_s(i)), ...
        "homogeneous_cs_median_m_s",double(h.cs_pred_median_m_s), ...
        "delta_cs_median_m_s", ...
            double(X.cs_pred_median_m_s(i))-double(h.cs_pred_median_m_s));
end

M=struct2table(vertcat(rows{:}));

end


function S = build_aggregate_summary(H,B,I,BM,IM)

rows = cell(0,1);

rows{end+1}=aggregate("homogeneous","all",H.mape_percent,H.bias_percent);

for region=["background","stiff_layer"]
    d=B(string(B.region)==region,:);
    rows{end+1}=aggregate("bilayer",region,d.mape_percent,d.bias_percent);
end

for region=["background","inclusion"]
    d=I(string(I.region)==region,:);
    rows{end+1}=aggregate("inclusion",region,d.mape_percent,d.bias_percent);
end

for region=unique(string(BM.region)).'
    d=BM(string(BM.region)==region,:);
    rows{end+1}=aggregate_delta("bilayer_matched",region,d.delta_mape_percent,d.delta_bias_percent);
end

for region=unique(string(IM.region)).'
    d=IM(string(IM.region)==region,:);
    rows{end+1}=aggregate_delta("inclusion_matched",region,d.delta_mape_percent,d.delta_bias_percent);
end

S=struct2table(vertcat(rows{:}));

end


function r = aggregate(geometry,region,mape,bias)

r=struct( ...
    "analysis",string(geometry), ...
    "region",string(region), ...
    "condition_count",numel(mape), ...
    "mean_mape_percent",mean(mape,"omitnan"), ...
    "median_mape_percent",median(mape,"omitnan"), ...
    "mean_bias_percent",mean(bias,"omitnan"), ...
    "mean_delta_mape_percent",NaN, ...
    "mean_delta_bias_percent",NaN);

end


function r = aggregate_delta(geometry,region,dmape,dbias)

r=struct( ...
    "analysis",string(geometry), ...
    "region",string(region), ...
    "condition_count",numel(dmape), ...
    "mean_mape_percent",NaN, ...
    "median_mape_percent",NaN, ...
    "mean_bias_percent",NaN, ...
    "mean_delta_mape_percent",mean(dmape,"omitnan"), ...
    "mean_delta_bias_percent",mean(dbias,"omitnan"));

end


function copy_if_exists(source,destination)

if isfile(source)
    copyfile(source,destination);
end

end
