function split = makeConditionHoldoutSplit( ...
        examples, conditions, held_condition_mask, options)
%MAKECONDITIONHOLDOUTSPLIT Hold out complete Cartesian conditions by mask.

arguments
    examples table
    conditions table
    held_condition_mask (:,1) logical
    options.Seed (1,1) double = 1
    options.ValidationFraction (1,1) double = 0.15
    options.HoldoutId (1,1) string = "held_out"
end

held_condition_mask=logical(held_condition_mask(:));
if numel(held_condition_mask)~=height(conditions) || ...
        ~any(held_condition_mask) || all(held_condition_mask)
    error("reqml:InvalidHomogeneousConditionHoldout", ...
        "Holdout mask must select a nonempty strict subset of conditions.");
end
remaining=find(~held_condition_mask);
stream=RandStream("Threefry","Seed",double(options.Seed));
order=remaining(randperm(stream,numel(remaining)));
validation_count=max(1,round(options.ValidationFraction*numel(remaining)));
condition_partition=repmat("train",height(conditions),1);
condition_partition(held_condition_mask)="test";
condition_partition(order(1:validation_count))="validation";
condition_ids=string(conditions.condition_id);
[present,location]=ismember(string(examples.campaign_condition_id),condition_ids);
if ~all(present)
    error("reqml:UnknownHomogeneousSplitCondition", ...
        "Examples contain conditions absent from the Cartesian design.");
end
partition=condition_partition(location);
split=struct("schema_name","reqml_homogeneous_condition_holdout_split", ...
    "schema_version","1.0","holdout_id",options.HoldoutId, ...
    "seed",double(options.Seed),"group_columns","campaign_condition_id", ...
    "run_column","campaign_run_id","condition_id", ...
    string(examples.campaign_condition_id),"partition",partition, ...
    "train_mask",partition=="train","validation_mask", ...
    partition=="validation","test_mask",partition=="test", ...
    "train_fraction_requested",mean(condition_partition=="train"), ...
    "validation_fraction_requested",mean(condition_partition=="validation"), ...
    "test_fraction_requested",mean(condition_partition=="test"));
split.conditions=conditions;
split.conditions.partition=condition_partition;
split.summary=partition_summary(examples,split);
end


function summary=partition_summary(examples,split)
names=["train";"validation";"test"];
condition_count=zeros(3,1); run_count=zeros(3,1); example_count=zeros(3,1);
for i=1:3
    mask=split.partition==names(i);
    condition_count(i)=numel(unique(split.condition_id(mask)));
    run_count(i)=numel(unique(string(examples.campaign_run_id(mask))));
    example_count(i)=sum(mask);
end
summary=table(names,condition_count,run_count,example_count, ...
    VariableNames=["partition","condition_count","run_count","example_count"]);
end
