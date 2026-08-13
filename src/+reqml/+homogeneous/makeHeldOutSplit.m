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
held=double(conditions.(dimension_name))==held_out_value;
if ~any(held) || all(held)
    error("reqml:InvalidHomogeneousHeldOutValue", ...
        "Held-out value must select a nonempty strict subset of conditions.");
end

split=reqml.homogeneous.makeConditionHoldoutSplit( ...
    examples,conditions,held,Seed=options.Seed, ...
    ValidationFraction=options.ValidationFraction, ...
    HoldoutId=dimension_name+"_"+string(held_out_value));
split.schema_name="reqml_homogeneous_held_out_split";
split.held_out_dimension=dimension_name;
split.held_out_value=held_out_value;
end
