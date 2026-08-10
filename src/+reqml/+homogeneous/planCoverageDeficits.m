function plan = planCoverageDeficits(coverage, config)
%PLANCOVERAGEDEFICITS Plan larger-domain reruns or supplementary realizations.

arguments
    coverage (1,1) struct
    config (1,1) struct
end

target=double(config.patch_sampling.target_patches_per_run);
max_supplementary=double( ...
    config.execution.maximum_supplementary_realizations_per_condition);
rows=table();
incomplete=coverage.conditions(~coverage.conditions.complete,:);

for i=1:height(incomplete)
    condition_id=incomplete.condition_id(i);
    condition_runs=coverage.runs(coverage.runs.condition_id==condition_id,:);
    structural=condition_runs.available_patch_count<target;
    if any(structural)
        deficient=condition_runs(structural,:);
        for j=1:height(deficient)
            current_placements=round(sqrt(max(1, ...
                deficient.available_patch_count(j))));
            next_placements=max(12,current_placements+2);
            scale=(deficient.patch_width_px(j)+(next_placements-1)* ...
                deficient.stride_x_px(j)-1)*deficient.dx_m(j);
            row=make_plan_row(condition_id,"larger_domain", ...
                deficient.realization_index(j),deficient.seed(j), ...
                scale,scale,deficient.run_id(j), ...
                deficient.deficit_patch_count(j));
            rows=append_row(rows,row);
        end
    else
        deficit=max(0,incomplete.intended_patch_count(i)- ...
            incomplete.selected_patch_count(i));
        needed=min(max_supplementary,ceil(deficit/target));
        next_realization=max(condition_runs.realization_index)+1;
        base_seed=double(config.design.base_seed)+ ...
            (find(coverage.conditions.condition_id==condition_id,1)-1)* ...
            double(config.design.condition_seed_stride);
        for j=1:needed
            realization=next_realization+j-1;
            seed=base_seed+realization;
            row=make_plan_row(condition_id,"supplementary_realization", ...
                realization,seed,condition_runs.domain_x_m(1), ...
                condition_runs.domain_z_m(1),"",min(target,deficit));
            rows=append_row(rows,row);
            deficit=max(0,deficit-target);
        end
    end
end

plan=struct("schema_name","reqml_homogeneous_deficit_plan", ...
    "schema_version","1.0","actions",rows,"action_count",height(rows), ...
    "coverage_complete",coverage.complete);
end


function row=make_plan_row(condition,action,realization,seed,lx,lz,replaces,expected)
row=table(condition,string(action),realization,seed,lx,lz,string(replaces), ...
    expected,VariableNames=["condition_id","action","realization_index", ...
    "seed","domain_x_m","domain_z_m","replaces_run_id", ...
    "expected_patch_contribution"]);
end
function output=append_row(output,row)
if isempty(output), output=row; else, output=[output;row]; end
end
