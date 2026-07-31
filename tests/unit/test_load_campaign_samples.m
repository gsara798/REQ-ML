function tests = test_load_campaign_samples
%TEST_LOAD_CAMPAIGN_SAMPLES Test campaign sample inventory construction.

tests = functiontests(localfunctions);

end

function setupOnce(~)

root = fileparts(fileparts(fileparts(mfilename("fullpath"))));
addpath(fullfile(root, "src"));

end

function testLoadsCompletedValidRows(testCase)

fixture = create_campaign_fixture();
cleanup = onCleanup(@() cleanup_fixture(fixture));

inventory = reqml.datasets.load_campaign_samples(fixture.csv_file);

verifyEqual(testCase, inventory.schema_name, ...
    "reqml_campaign_sample_inventory");
verifyEqual(testCase, inventory.schema_version, "1.0");
verifyEqual(testCase, inventory.sample_count, 2);
verifyEqual(testCase, inventory.rejected_count, 2);
verifyEqual(testCase, inventory.samples.run_id, ...
    ["run_000001"; "run_000002"]);
verifyTrue(testCase, all(inventory.samples.wavefield_sample_exists));
verifyEqual(testCase, inventory.summary.frequencies_hz, [300; 400]);
verifyEqual(testCase, inventory.summary.direction_counts, [1; 8]);

clear cleanup

end

function testAppliesStableMaxSamplesLimit(testCase)

fixture = create_campaign_fixture();
cleanup = onCleanup(@() cleanup_fixture(fixture));

inventory = reqml.datasets.load_campaign_samples( ...
    fixture.csv_file, MaxSamples=1);

verifyEqual(testCase, inventory.sample_count, 1);
verifyEqual(testCase, inventory.samples.run_id, "run_000001");

clear cleanup

end

function testRejectsMissingSampleFile(testCase)

fixture = create_campaign_fixture();
cleanup = onCleanup(@() cleanup_fixture(fixture));
delete(fixture.sample_files(1));

verifyError(testCase, ...
    @() reqml.datasets.load_campaign_samples(fixture.csv_file), ...
    "reqml:CampaignSampleFileMissing");

clear cleanup

end

function testCanRetainMissingPathMetadata(testCase)

fixture = create_campaign_fixture();
cleanup = onCleanup(@() cleanup_fixture(fixture));
delete(fixture.sample_files(1));

inventory = reqml.datasets.load_campaign_samples( ...
    fixture.csv_file, RequireAllPaths=false);

verifyFalse(testCase, inventory.samples.wavefield_sample_exists(1));

clear cleanup

end

function testRejectsDuplicateRunIds(testCase)

fixture = create_campaign_fixture();
cleanup = onCleanup(@() cleanup_fixture(fixture));

opts = detectImportOptions( ...
    fixture.csv_file, Delimiter=",", TextType="string");
runs = readtable(fixture.csv_file, opts);
runs.run_id(2) = runs.run_id(1);
writetable(runs, fixture.csv_file, Delimiter=",");

verifyError(testCase, ...
    @() reqml.datasets.load_campaign_samples(fixture.csv_file), ...
    "reqml:DuplicateCampaignRunId");

clear cleanup

end

function fixture = create_campaign_fixture()

fixture.root = string(tempname);
mkdir(fixture.root);

sample_files = strings(2,1);
for index = 1:2
    sample_files(index) = fullfile( ...
        fixture.root, sprintf("sample_%d.mat", index));
    wavefield_sample = struct(); %#ok<NASGU>
    save(sample_files(index), "wavefield_sample");
end

missing_file = fullfile(fixture.root, "missing.mat");

ordinal = (1:4)';
run_id = ["run_000001";"run_000002";"run_000003";"run_000004"];
backend = repmat("swsynth",4,1);
hash_sha256 = ["hash_1";"hash_2";"hash_3";"hash_4"];
status = ["completed";"skipped_completed";"failed";"completed"];
outcome_status = ["completed_valid";"completed_valid";"";"completed_valid"];
scenario = repmat("homogeneous_projected3d_clean_v1",4,1);
seed = [3101;3102;3103;3104];
frequency_hz = [300;400;500;600];
background_cs_m_s = [2;2.5;3;3.5];
direction_count = [1;8;32;128];
valid = [1;1;0;0];
run_directory = repmat(fixture.root,4,1);
resolved_config_path = repmat("",4,1);
wavefield_sample_path = [sample_files;string(missing_file);string(missing_file)];
summary_path = repmat("",4,1);
validation_report_path = repmat("",4,1);

runs = table(ordinal,run_id,backend,hash_sha256,status, ...
    outcome_status,scenario,seed,frequency_hz,background_cs_m_s, ...
    direction_count,valid,run_directory,resolved_config_path, ...
    wavefield_sample_path,summary_path,validation_report_path);

fixture.csv_file = fullfile(fixture.root,"campaign_runs.csv");
writetable(runs,fixture.csv_file,Delimiter=",");
fixture.sample_files = sample_files;

end

function cleanup_fixture(fixture)

if isfolder(fixture.root)
    rmdir(fixture.root,"s");
end

end
