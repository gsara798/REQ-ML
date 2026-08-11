function coverage = summarizeCoverage( ...
        design, campaign_runs_csv, sample_summaries, options)
%SUMMARIZECOVERAGE Build simple run and physical-condition quota coverage.

arguments
    design (1,1) struct
    campaign_runs_csv {mustBeTextScalar}
    sample_summaries table
    options.TargetPatchesPerRun (1,1) double ...
        {mustBeInteger,mustBePositive} = 100
    options.MValues (:,1) double = 2
end

campaign=readtable(campaign_runs_csv,Delimiter=",",TextType="string", ...
    VariableNamingRule="preserve");
planned=design.runs;
conditions=design.conditions;
n=height(planned)*numel(options.MValues);
rows=cell(n,1);
row_index=0;
for planned_index=1:height(planned)
  for M=double(options.MValues(:))'
    row_index=row_index+1; p=planned(planned_index,:);
    c=conditions(conditions.condition_id==p.condition_id,:);
    actual=find(string(campaign.design_id)==p.design_id,1);
    if isempty(actual)
        rows{row_index}=missing_run_row(p,c,options.TargetPatchesPerRun,M);
        continue
    end
    run_id=string(campaign.run_id(actual));
    summary_mask=string(sample_summaries.run_id)==run_id;
    if ismember("REQ_M",string(sample_summaries.Properties.VariableNames))
        summary_mask=summary_mask & double(sample_summaries.REQ_M)==M;
    end
    summary=find(summary_mask,1);
    [planned_w,planned_stride]=planned_geometry(c,M);
    available=0; selected=0; patch_w=planned_w;
    patch_h=planned_w; stride_x=planned_stride; stride_z=planned_stride;
    if ~isempty(summary)
        available=double(sample_summaries.available_patch_count(summary));
        selected=double(sample_summaries.selected_patch_count(summary));
        patch_w=double(sample_summaries.patch_width_px(summary));
        patch_h=double(sample_summaries.patch_height_px(summary));
        stride_x=double(sample_summaries.stride_x_px(summary));
        stride_z=double(sample_summaries.stride_z_px(summary));
    end
    deficit=max(0,double(options.TargetPatchesPerRun)-selected);
    status=string(campaign.status(actual));
    if status=="completed" || status=="skipped_completed"
        if deficit==0, status="complete"; else, status="patch_deficit"; end
    end
    rows{row_index}=table(p.condition_id,c.cs_m_s,c.frequency_hz,c.dx_m,c.dz_m, ...
        c.field_regime,p.realization_index,p.seed,c.domain_x_m,c.domain_z_m, ...
        M,planned_w,planned_w,planned_stride,planned_stride, ...
        patch_w,patch_h,stride_x,stride_z, ...
        patch_w==planned_w && patch_h==planned_w && ...
        stride_x==planned_stride && stride_z==planned_stride, ...
        available,selected, ...
        double(options.TargetPatchesPerRun),deficit,status,p.supplementary_run, ...
        string(campaign.wavefield_sample_path(actual)),run_id,p.design_id, ...
        VariableNames=run_variable_names());
  end
end

run_coverage=vertcat(rows{:});
condition_rows=cell(height(conditions),1);
for i=1:height(conditions)
    c=conditions(i,:);
    mask=run_coverage.condition_id==c.condition_id;
    selected=sum(run_coverage.selected_patch_count(mask));
    intended=double(options.TargetPatchesPerRun)*double(c.base_realization_count)*numel(options.MValues);
    successful=run_coverage(mask & run_coverage.selected_patch_count>0,:);
    independent_runs=numel(unique(successful.run_id));
    complete=selected>=intended && ...
        independent_runs>=c.base_realization_count && ...
        all(groupsummary(run_coverage(mask,:),"REQ_M","sum","selected_patch_count").sum_selected_patch_count>= ...
        double(options.TargetPatchesPerRun)*double(c.base_realization_count));
    condition_rows{i}=table(c.condition_id,c.cs_m_s,c.frequency_hz,c.dx_m, ...
        c.field_regime,independent_runs,selected,intended,selected/intended, ...
        complete,VariableNames=["condition_id","cs_m_s","frequency_hz", ...
        "dx_m","field_regime","independent_run_count", ...
        "selected_patch_count","intended_patch_count", ...
        "coverage_fraction","complete"]);
end

coverage=struct();
coverage.schema_name="reqml_homogeneous_cartesian_coverage";
coverage.schema_version="1.0";
coverage.runs=run_coverage;
coverage.conditions=vertcat(condition_rows{:});
coverage.complete=all(coverage.conditions.complete);
coverage.completed_condition_count=sum(coverage.conditions.complete);
coverage.condition_count=height(coverage.conditions);
coverage.base_run_count=sum(~coverage.runs.supplementary_run);
coverage.supplementary_run_count=sum(coverage.runs.supplementary_run);
coverage.selected_patch_count=sum(coverage.runs.selected_patch_count);
coverage.geometry_audit=coverage.runs(:,["condition_id","run_id","design_id", ...
    "planned_patch_width_px","planned_patch_height_px", ...
    "planned_stride_x_px","planned_stride_z_px","patch_width_px", ...
    "patch_height_px","stride_x_px","stride_z_px","geometry_match"]);
coverage.geometry_mismatch_count=sum(~coverage.geometry_audit.geometry_match);
coverage.geometry_match=coverage.geometry_mismatch_count==0;
end


function row=missing_run_row(p,c,target,M)
[planned_w,planned_stride]=planned_geometry(c,M);
row=table(p.condition_id,c.cs_m_s,c.frequency_hz,c.dx_m,c.dz_m, ...
    c.field_regime,p.realization_index,p.seed,c.domain_x_m,c.domain_z_m, ...
    M,planned_w,planned_w,planned_stride,planned_stride, ...
    planned_w,planned_w,planned_stride,planned_stride, ...
    false,0,0,double(target),double(target),"missing",p.supplementary_run,"","", ...
    p.design_id,VariableNames=run_variable_names());
end
function names=run_variable_names()
names=["condition_id","cs_m_s","frequency_hz","dx_m","dz_m", ...
    "field_regime","realization_index","seed","domain_x_m","domain_z_m", ...
    "REQ_M", ...
    "planned_patch_width_px","planned_patch_height_px", ...
    "planned_stride_x_px","planned_stride_z_px", ...
    "patch_width_px","patch_height_px","stride_x_px","stride_z_px", ...
    "geometry_match","available_patch_count","selected_patch_count","target_patch_count", ...
    "deficit_patch_count","run_status","supplementary_run","sample_file", ...
    "run_id","design_id"];
end

function [width,stride]=planned_geometry(c,M)
width=c.patch_width_px; stride=c.stride_x_px;
width_name="m"+string(M)+"_patch_width_px";
stride_name="m"+string(M)+"_stride_px";
if ismember(width_name,string(c.Properties.VariableNames)) && isfinite(c.(width_name))
    width=c.(width_name); stride=c.(stride_name);
end
end
