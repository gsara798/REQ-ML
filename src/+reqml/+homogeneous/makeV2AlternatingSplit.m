function split=makeV2AlternatingSplit(examples,conditions,dimension,config,options)
%MAKEV2ALTERNATINGSPLIT Hold out alternating SWS or angular design levels.
arguments
    examples table
    conditions table
    dimension (1,1) string {mustBeMember(dimension,["sws","angular"])}
    config (1,1) struct
    options.Seed (1,1) double = 9601
    options.ValidationFraction (1,1) double = 0.15
end
switch dimension
    case "sws"
        train_values=double(config.splits.sws_train_m_s(:));
        test_values=double(config.splits.sws_interpolation_test_m_s(:));
        values=double(conditions.cs_m_s); id="alternating_sws";
    case "angular"
        train_values=double(config.splits.angular_train_levels(:));
        test_values=double(config.splits.angular_interpolation_test_levels(:));
        values=double(conditions.angular_level); id="alternating_angular";
end
all_values=sort(unique(values));
if ~isequal(sort([train_values;test_values]),all_values) || ...
        ~isempty(intersect(train_values,test_values))
    error("reqml:InvalidV2AlternatingSupport", ...
        "Configured train/test %s supports must be disjoint and complete.",dimension);
end
held=ismember(values,test_values);
split=reqml.homogeneous.makeConditionHoldoutSplit(examples,conditions,held, ...
    Seed=options.Seed,ValidationFraction=options.ValidationFraction,HoldoutId=id);
split.dimension=dimension; split.train_support=train_values; split.test_support=test_values;
if any(ismember(values(split.conditions.partition=="train"),test_values)) || ...
        any(ismember(values(split.conditions.partition=="validation"),test_values))
    error("reqml:V2AlternatingSplitLeakage","Test support leaked into development partitions.");
end
end
