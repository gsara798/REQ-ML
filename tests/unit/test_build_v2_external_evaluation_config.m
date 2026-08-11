function tests=test_build_v2_external_evaluation_config
tests=functiontests(localfunctions);
end

function testAssemblesCompletedCampaigns(testCase)
[master,framework,cleanup]=fixture(); %#ok<ASGLU>
result=reqml.homogeneous.buildV2ExternalEvaluationConfig(master, ...
    OutputFile=fullfile(framework,"evaluation.json"));
verifyEqual(testCase,height(result.cases),6);
verifyEqual(testCase,sort(unique(result.cases.field_regime)),["low";"mid"]);
verifyTrue(testCase,all(startsWith(result.cases.sample_file,"${SWSIM_ROOT}")));
verifyFalse(testCase,any(contains(result.cases.sample_file,"_v1")));
verifyEqual(testCase,double(result.config.feature_config.M_values(:)),[2;3]);
end

function testMissingLedgerFailsClearly(testCase)
[master,~,cleanup]=fixture(); %#ok<ASGLU>
c=jsondecode(fileread(master)); c.campaigns(1).campaign_name="missing_campaign";
write_json(master,c);
verifyError(testCase,@() reqml.homogeneous.buildV2ExternalEvaluationConfig(master), ...
    "reqml:MissingV2ExternalCampaign");
end

function testAvailableModeIncludesOnlyValidCompletedRuns(testCase)
[master,framework,cleanup]=fixture(); %#ok<ASGLU>
c=jsondecode(fileread(master));
missing=fullfile(framework,"outputs","campaigns","scientific","reqml_q0_v2", ...
    string(c.campaigns(6).campaign_name),"campaign_runs.csv");
delete(missing);
ledger=fullfile(framework,"outputs","campaigns","scientific","reqml_q0_v2", ...
    string(c.campaigns(5).campaign_name),"campaign_runs.csv");
r=readtable(ledger,TextType="string"); r.status(:)="running"; r.valid(:)=false; writetable(r,ledger);
result=reqml.homogeneous.buildV2ExternalEvaluationConfig(master, ...
    CompletionMode="available",EvaluationId="partial_available", ...
    OutputRoot="${REPOSITORY_ROOT}/partial",MapStepPixels=4,ResumeCasePredictions=true, ...
    OutputFile=fullfile(framework,"partial.json"));
verifyEqual(testCase,height(result.cases),4);
verifyTrue(testCase,result.config.partial_result);
verifyEqual(testCase,string(result.config.evaluation_scope),"available");
verifyEqual(testCase,double(result.config.expected_case_count),6);
verifyEqual(testCase,double(result.config.omitted_expected_case_count),2);
verifyEqual(testCase,string(result.config.evaluation_id),"partial_available");
verifyEqual(testCase,string(result.config.output_root),"${REPOSITORY_ROOT}/partial");
verifyEqual(testCase,double(result.config.feature_config.map_step_px),4);
verifyTrue(testCase,result.config.feature_config.resume_case_predictions);
states=string({result.config.campaign_audit.state});
verifyTrue(testCase,any(states=="missing_ledger"));
verifyTrue(testCase,any(states=="no_valid_completed_runs"));
end

function [master,framework,cleanup]=fixture()
root=string(tempname); mkdir(root); framework=fullfile(root,"framework"); mkdir(framework);
old=getenv("SWSIM_ROOT"); setenv("SWSIM_ROOT",framework);
cleanup=onCleanup(@() cleanup_all(root,old));
specs=struct("backend",{"eikonal","eikonal","eikonal","kwave","kwave","kwave"}, ...
    "geometry",{"homogeneous","inclusion","bilayer","homogeneous","inclusion","bilayer"}, ...
    "campaign_name",{"e_h","e_i","e_b","k_h","k_i","k_b"}, ...
    "expected_runs",{1,1,1,1,1,1});
for i=1:numel(specs)
    folder=fullfile(framework,"outputs","campaigns","scientific","reqml_q0_v2",specs(i).campaign_name);
    mkdir(folder); sample=fullfile(folder,"sample.mat"); fid=fopen(sample,"w"); fclose(fid);
    if mod(i,2)==0, anchor="mid"; N=16; P=4; omega=pi; else, anchor="low"; N=1; P=1; omega=.01; end
    design_id=string(specs(i).campaign_name)+"_"+anchor; status="completed"; valid=true;
    wavefield_sample_path=sample; seed=990000+i; direction_count=N;
    requested_in_plane_count=P; solid_angle_sr=omega; retained_direction_count=N;
    retained_in_plane_count=P; angular_entropy=.5;
    writetable(table(design_id,status,valid,wavefield_sample_path,seed,direction_count, ...
        requested_in_plane_count,solid_angle_sr,retained_direction_count, ...
        retained_in_plane_count,angular_entropy),fullfile(folder,"campaign_runs.csv"));
end
config=struct("evaluation_id","synthetic_v2","model_bundle","${REPOSITORY_ROOT}/model.mat", ...
    "output_root","${REPOSITORY_ROOT}/external","simulation_framework_root","${SWSIM_ROOT}", ...
    "feature_config",struct("M_values",[2 3],"cs_guess_m_s",3,"use_window_parfor",false), ...
    "campaigns",specs);
master=fullfile(root,"master.json"); write_json(master,config);
end

function cleanup_all(root,old)
setenv("SWSIM_ROOT",old); if isfolder(root), rmdir(root,"s"); end
end

function write_json(path,value)
fid=fopen(path,"w"); cleanup=onCleanup(@() fclose(fid));
fprintf(fid,"%s",jsonencode(value));
end
