function specifications = buildHoldoutSpecifications(config)
%BUILDHOLDOUTSPECIFICATIONS Enumerate 16 level and one compositional holdout.

arguments
    config (1,1) struct
end

families=strings(0,1); dimensions=strings(0,1); labels=strings(0,1);
numeric_values=zeros(0,1); string_values=strings(0,1); ids=strings(0,1);
[families,dimensions,labels,numeric_values,string_values,ids]=append_numeric( ...
    families,dimensions,labels,numeric_values,string_values,ids,"cs", ...
    "cs_m_s",double(config.design.cs_m_s(:)),"cs");
[families,dimensions,labels,numeric_values,string_values,ids]=append_numeric( ...
    families,dimensions,labels,numeric_values,string_values,ids,"frequency", ...
    "frequency_hz",double(config.design.frequency_hz(:)),"f");
[families,dimensions,labels,numeric_values,string_values,ids]=append_numeric( ...
    families,dimensions,labels,numeric_values,string_values,ids,"dx", ...
    "dx_m",double(config.design.spacing_m(:)),"dx");
field_values=string({config.field_regimes.name})';
for i=1:numel(field_values)
    families(end+1,1)="field"; dimensions(end+1,1)="field_regime";
    labels(end+1,1)=field_values(i); numeric_values(end+1,1)=NaN;
    string_values(end+1,1)=field_values(i);
    ids(end+1,1)="field_"+field_values(i);
end
families(end+1,1)="compositional"; dimensions(end+1,1)="cs_frequency";
labels(end+1,1)="cs3_f400"; numeric_values(end+1,1)=NaN;
string_values(end+1,1)="cs3_f400"; ids(end+1,1)="compositional_cs3_f400";
ordinal=(1:numel(ids))';
specifications=table(ordinal,ids,families,dimensions,labels,numeric_values, ...
    string_values,VariableNames=["ordinal","experiment_id","family", ...
    "dimension","held_out_label","numeric_value","string_value"]);
end


function [families,dimensions,labels,numeric_values,string_values,ids]= ...
        append_numeric(families,dimensions,labels,numeric_values, ...
        string_values,ids,family,dimension,values,prefix)
for i=1:numel(values)
    value=values(i); families(end+1,1)=family; dimensions(end+1,1)=dimension;
    numeric_values(end+1,1)=value; string_values(end+1,1)="";
    if family=="dx"
        labels(end+1,1)=compose("%.2f mm",1e3*value);
        token=replace(compose("%.2f",1e3*value),".","p");
    else
        labels(end+1,1)=string(value); token=string(value);
    end
    ids(end+1,1)=prefix+"_"+token;
end
end
