function report = validate_split_integrity(examples, split)
%VALIDATE_SPLIT_INTEGRITY Verify grouped split isolation and completeness.

arguments
    examples table
    split (1,1) struct
end

required_fields = [
    "condition_id"
    "partition"
    "train_mask"
    "validation_mask"
    "test_mask"
    ];

for field_name = required_fields.'
    if ~isfield(split, field_name)
        error("reqml:InvalidSplit", ...
            "Split is missing field '%s'.", ...
            field_name);
    end
end

n = height(examples);

split_lengths = [
    numel(split.condition_id)
    numel(split.partition)
    numel(split.train_mask)
    numel(split.validation_mask)
    numel(split.test_mask)
    ];

if any(split_lengths ~= n)
    error("reqml:SplitSizeMismatch", ...
        "Split row count does not match example count.");
end

mask_partition_consistent = ...
    isequal(logical(split.train_mask), ...
        split.partition == "train") && ...
    isequal(logical(split.validation_mask), ...
        split.partition == "validation") && ...
    isequal(logical(split.test_mask), ...
        split.partition == "test");

mask_sum = ...
    double(split.train_mask) + ...
    double(split.validation_mask) + ...
    double(split.test_mask);

complete_assignment = all(mask_sum == 1);

run_overlap = has_group_overlap( ...
    examples.campaign_run_id, ...
    split.partition);

condition_overlap = has_group_overlap( ...
    split.condition_id, ...
    split.partition);

valid_partitions = all(ismember( ...
    unique(split.partition), ...
    ["train", "validation", "test"]));

nonempty_partitions = all([
    any(split.train_mask)
    any(split.validation_mask)
    any(split.test_mask)
    ]);

report = struct();
report.schema_name = "reqml_split_integrity_report";
report.schema_version = "1.0";
report.complete_assignment = complete_assignment;
report.mask_partition_consistent = ...
    mask_partition_consistent;
report.run_overlap = run_overlap;
report.condition_overlap = condition_overlap;
report.valid_partitions = valid_partitions;
report.nonempty_partitions = nonempty_partitions;

report.valid = ...
    complete_assignment && ...
    mask_partition_consistent && ...
    ~run_overlap && ...
    ~condition_overlap && ...
    valid_partitions && ...
    nonempty_partitions;

if report.valid
    report.summary = ...
        "Split integrity valid.";
else
    report.summary = compose( ...
        "Split invalid: complete=%d, masks_consistent=%d, run_overlap=%d, condition_overlap=%d, valid_partitions=%d, nonempty=%d.", ...
        complete_assignment, ...
        mask_partition_consistent, ...
        run_overlap, ...
        condition_overlap, ...
        valid_partitions, ...
        nonempty_partitions);
end

end

function tf = has_group_overlap(group_id, partition)

[group_number, ~] = findgroups(group_id);
group_count = max(group_number);

tf = false;

for index = 1:group_count
    partitions = unique( ...
        partition(group_number == index));

    if numel(partitions) > 1
        tf = true;
        return
    end
end

end
