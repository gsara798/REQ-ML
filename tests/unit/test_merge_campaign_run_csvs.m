function tests = test_merge_campaign_run_csvs
%TEST_MERGE_CAMPAIGN_RUN_CSVS Test accumulated run-table merging.

tests = functiontests(localfunctions);

end


function setupOnce(~)

root = fileparts(fileparts(fileparts( ...
    mfilename("fullpath"))));

addpath(fullfile(root, "src"));

end


function testMergesAndDeduplicatesIdenticalRuns(testCase)

root = string(tempname);
mkdir(root);

cleanup = onCleanup(@() cleanup_directory(root));

a = make_csv(root, "a.csv", ...
    ["run_1"; "run_2"], ...
    ["condition_1"; "condition_1"]);

b = make_csv(root, "b.csv", ...
    ["run_2"; "run_3"], ...
    ["condition_1"; "condition_2"]);

% Make the duplicate run_2 row identical across both files.
table_a = readtable(a, TextType="string");
table_b = readtable(b, TextType="string");

table_b(1, :) = table_a(2, :);
writetable(table_b, b);

output = fullfile(root, "merged.csv");

result = reqml.campaigns.mergeCampaignRunCsvs( ...
    [a; b], ...
    OutputFile=output);

verifyEqual(testCase, result.input_row_count, 4);
verifyEqual(testCase, result.output_row_count, 3);
verifyEqual(testCase, result.duplicate_row_count, 1);
verifyEqual(testCase, result.run_count, 3);
verifyEqual(testCase, result.condition_count, 2);

verifyTrue(testCase, isfile(output));

clear cleanup

end


function testRejectsConflictingDuplicateRun(testCase)

root = string(tempname);
mkdir(root);

cleanup = onCleanup(@() cleanup_directory(root));

a = make_csv(root, "a.csv", ...
    "run_1", ...
    "condition_1");

b = make_csv(root, "b.csv", ...
    "run_1", ...
    "different_condition");

verifyError(testCase, ...
    @() reqml.campaigns.mergeCampaignRunCsvs( ...
        [a; b]), ...
    "reqml:ConflictingCampaignRunDuplicate");

clear cleanup

end


function path_value = make_csv( ...
        root, filename, run_ids, condition_ids)

run_ids = string(run_ids(:));
condition_ids = string(condition_ids(:));

n = numel(run_ids);

campaign_runs = table();

campaign_runs.run_id = run_ids;
campaign_runs.condition_id = condition_ids;
campaign_runs.design_id = "design_" + string((1:n)');
campaign_runs.valid = ones(n, 1);

path_value = fullfile(root, filename);

writetable( ...
    campaign_runs, ...
    path_value, ...
    FileType="text", ...
    Delimiter=",");

end


function cleanup_directory(directory)

if isfolder(directory)
    rmdir(directory, "s");
end

end
