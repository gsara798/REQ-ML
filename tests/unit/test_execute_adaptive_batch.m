function tests = test_execute_adaptive_batch
%TEST_EXECUTE_ADAPTIVE_BATCH Test automated adaptive batch execution.

tests = functiontests(localfunctions);

end


function setupOnce(testCase)

repository_root = fileparts(fileparts(fileparts( ...
    mfilename("fullpath"))));

addpath(fullfile(repository_root, "src"));

testCase.TestData.repository_root = ...
    repository_root;

end


function testExecutesCampaignSetAndReturnsCsvFiles(testCase)

root = string(tempname);
batch_directory = fullfile(root, "batch");
framework_root = fullfile(root, "framework");
framework_src = fullfile(framework_root, "src");

mkdir(batch_directory);
mkdir(framework_src);
mkdir(fullfile(framework_src, "+simcampaigns"));

cleanup = onCleanup(@() cleanup_root(root));

write_text( ...
    fullfile( ...
        batch_directory, ...
        "simulation_campaign_bilayer.json"), ...
    "{}");

write_text( ...
    fullfile( ...
        batch_directory, ...
        "simulation_campaign_inclusion.json"), ...
    "{}");

write_fake_runner(framework_src);

result = ...
    reqml.campaigns.executeAdaptiveBatch( ...
        batch_directory, ...
        framework_root);

verifyTrue(testCase, result.success);

verifyEqual(testCase, ...
    result.campaign_count, ...
    2);

verifyEqual(testCase, ...
    result.run_count, ...
    4);

verifyEqual(testCase, ...
    result.completed_count, ...
    4);

verifyEqual(testCase, ...
    result.skipped_count, ...
    0);

verifyEqual(testCase, ...
    result.failed_count, ...
    0);

verifyEqual(testCase, ...
    numel(result.campaign_csv_files), ...
    2);

verifyTrue(testCase, ...
    all(isfile(result.campaign_csv_files)));

clear cleanup

end


function testRejectsMissingBatchDirectory(testCase)

verifyError(testCase, ...
    @() reqml.campaigns.executeAdaptiveBatch( ...
        string(tempname), ...
        string(tempname)), ...
    "reqml:AdaptiveBatchDirectoryNotFound");

end


function testRejectsBatchWithoutCampaigns(testCase)

root = string(tempname);
batch_directory = fullfile(root, "batch");
framework_root = fullfile(root, "framework");

mkdir(batch_directory);
mkdir(fullfile(framework_root, "src"));

cleanup = onCleanup(@() cleanup_root(root));

verifyError(testCase, ...
    @() reqml.campaigns.executeAdaptiveBatch( ...
        batch_directory, ...
        framework_root), ...
    "reqml:NoAdaptiveSimulationCampaigns");

clear cleanup

end


function write_fake_runner(framework_src)

content = [
"function result = runCampaignSet(files, options)"
"arguments"
"    files (:,1) string"
"    options.Resume (1,1) logical = true"
"    options.ContinueOnError (1,1) logical = false"
"end"
"campaigns = repmat(struct( ..."
"    ""campaign_file"", """", ..."
"    ""campaign_runs_csv"", """"), ..."
"    numel(files), 1);"
"for index = 1:numel(files)"
"    csv_file = files(index) + "".csv"";"
"    table_value = table( ..."
"        [1; 2], ..."
"        VariableNames=""ordinal"");"
"    writetable(table_value, csv_file);"
"    campaigns(index).campaign_file = files(index);"
"    campaigns(index).campaign_runs_csv = csv_file;"
"end"
"result = struct();"
"result.campaign_count = numel(files);"
"result.run_count = 2*numel(files);"
"result.completed_count = result.run_count;"
"result.skipped_count = 0;"
"result.failed_count = 0;"
"result.success = true;"
"result.campaigns = campaigns;"
"end"
];

write_text( ...
    fullfile( ...
        framework_src, ...
        "+simcampaigns", ...
        "runCampaignSet.m"), ...
    strjoin(content, newline));

end


function write_text(path_value, content)

file_id = fopen(path_value, "w");
assert(file_id >= 0);

cleanup = onCleanup(@() fclose(file_id));

fprintf(file_id, "%s", content);

clear cleanup

end


function cleanup_root(root)

if isfolder(root)
    rmdir(root, "s");
end

end
