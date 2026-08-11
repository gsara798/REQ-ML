function tests=test_homogeneous_v2_development_figures
tests=functiontests(localfunctions);
end

function testCreatesCompleteFigureSet(testCase)
root=string(tempname); mkdir(root); cleanup=onCleanup(@() rmdir(root,"s")); %#ok<NASGU>
model_id="synthetic_q0_v2";
paths=[fullfile(root,"training",model_id,"tables"), ...
    fullfile(root,"generalization","alternating_sws","tables"), ...
    fullfile(root,"generalization","alternating_angular","tables")];
for path=paths, mkdir(path); writetable(predictions(),fullfile(path,"predictions.csv")); end
config=struct("paths",struct("output_root",root),"training",struct("model_id",model_id));
config_file=fullfile(root,"config.json"); fid=fopen(config_file,"w");
fprintf(fid,"%s",jsonencode(config)); fclose(fid);
result=reqml.homogeneous.generateV2DevelopmentFigures(config_file);
names=string(fieldnames(result.paths)); verifyEqual(testCase,numel(names),12);
for name=names.'
    verifyTrue(testCase,isfile(result.paths.(name)+".png"));
    verifyTrue(testCase,isfile(result.paths.(name)+".pdf"));
end
end

function p=predictions()
n=84; cs_levels=(1:.25:4)'; cs_true_m_s=repmat(cs_levels,ceil(n/numel(cs_levels)),1); cs_true_m_s=cs_true_m_s(1:n);
REQ_M=repmat([2;3],n/2,1); frequency_hz=repmat([200;300;400;500;600;400],ceil(n/6),1); frequency_hz=frequency_hz(1:n);
angular_support_fraction=repmat([.01/(4*pi);.01;.04;.125;.25;.5;1],n/7,1);
partition=repmat("test",n,1); sws_valid=true(n,1);
cs_pred_m_s=cs_true_m_s.*(1+.01*sin((1:n)')); cs_error_m_s=cs_pred_m_s-cs_true_m_s;
cs_error_percent=100*cs_error_m_s./cs_true_m_s; cs_absolute_error_percent=abs(cs_error_percent);
q_true=.2+.6*(cs_true_m_s-1)/3; q_pred=q_true+.005*cos((1:n)'); q_error=q_pred-q_true;
p=table(partition,sws_valid,REQ_M,frequency_hz,angular_support_fraction, ...
    cs_true_m_s,cs_pred_m_s,cs_error_m_s,cs_error_percent, ...
    cs_absolute_error_percent,q_true,q_pred,q_error);
end
