function patches = markCommonSupport(patches)
%MARKCOMMONSUPPORT Mark centers shared by every estimator per condition.
arguments
    patches table
end
estimators=unique(patches.estimator);
[group,~]=findgroups(patches.condition,patches.cx,patches.cz);
count=splitapply(@count_valid_estimators,patches.estimator,patches.valid,group);
patches.common_support=patches.valid & count(group)==numel(estimators);
end

function count=count_valid_estimators(estimator,valid)
count=numel(unique(estimator(valid)));
end
