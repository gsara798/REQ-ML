function tests=test_homogeneous_v2_split_figures
tests=functiontests(localfunctions);
end

function testCreatesSplitAuditFigures(testCase)
root=string(tempname); mkdir(root); cleanup=onCleanup(@() rmdir(root,"s")); %#ok<NASGU>
schemes=["in_domain","alternating_sws","alternating_angular"];
for scheme=schemes
    folder=fullfile(root,"splits",scheme); mkdir(folder);
    partition=["train";"validation";"test"]; condition_count=[2;1;1]; run_count=3*condition_count;
    example_count=10*run_count; writetable(table(partition,condition_count,run_count,example_count), ...
        fullfile(folder,"partition_summary.csv"));
    condition_id=("c"+(1:8)') ; cs_m_s=repmat([2;3],4,1); frequency_hz=repmat([200;400],4,1);
    angular_level=repmat((1:4)',2,1); partition=repmat(["train";"validation";"test";"train"],2,1);
    writetable(table(condition_id,cs_m_s,frequency_hz,angular_level,partition), ...
        fullfile(folder,"condition_partitions.csv"));
end
config=struct("paths",struct("output_root",root)); file=fullfile(root,"config.json"); write_json(file,config);
result=reqml.homogeneous.generateV2SplitFigures(file);
names=string(fieldnames(result.paths)); verifyEqual(testCase,numel(names),3);
for name=names.'
    verifyTrue(testCase,isfile(result.paths.(name)+".png"));
    verifyTrue(testCase,isfile(result.paths.(name)+".pdf"));
end
end

function write_json(path,value)
fid=fopen(path,"w"); cleanup=onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid,"%s",jsonencode(value));
end
