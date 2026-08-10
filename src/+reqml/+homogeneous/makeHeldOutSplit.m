function split = makeHeldOutSplit( ...
        examples, conditions, dimension_name, held_out_value, options)
%MAKEHELDOUTSPLIT Hold out complete Cartesian physical conditions.

arguments
    examples table
    conditions table
    dimension_name (1,1) string
    held_out_value (1,1) double
    options.Seed (1,1) double = 1
    options.ValidationFraction (1,1) double = 0.15
end

if ~ismember(dimension_name,string(conditions.Properties.VariableNames))
    error("reqml:UnknownHomogeneousHeldOutDimension", ...
        "Unknown held-out dimension '%s'.",dimension_name);
end
condition_ids=string(conditions.condition_id);
held=double(conditions.(dimension_name))==held_out_value;
if ~any(held) || all(held)
    error("reqml:InvalidHomogeneousHeldOutValue", ...
        "Held-out value must select a nonempty strict subset of conditions.");
end

remaining=find(~held);
stream=RandStream("Threefry","Seed",double(options.Seed));
order=remaining(randperm(stream,numel(remaining)));
validation_count=max(1,round(options.ValidationFraction*numel(remaining)));
condition_partition=repmat("train",height(conditions),1);
condition_partition(held)="test";
condition_partition(order(1:validation_count))="validation";

[present,location]=ismember(string(examples.campaign_condition_id),condition_ids);
if ~all(present)
    error("reqml:UnknownHomogeneousSplitCondition", ...
        "Examples contain conditions absent from the Cartesian design.");
end
partition=condition_partition(location);
split=struct();
split.schema_name="reqml_homogeneous_held_out_split";
split.schema_version="1.0";
split.seed=double(options.Seed);
split.group_columns="campaign_condition_id";
split.run_column="campaign_run_id";
split.condition_id=string(examples.campaign_condition_id);
split.partition=partition;
split.train_mask=partition=="train";
split.validation_mask=partition=="validation";
split.test_mask=partition=="test";
split.held_out_dimension=dimension_name;
split.held_out_value=held_out_value;
split.train_fraction_requested=mean(condition_partition=="train");
split.validation_fraction_requested=mean(condition_partition=="validation");
split.test_fraction_requested=mean(condition_partition=="test");
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
