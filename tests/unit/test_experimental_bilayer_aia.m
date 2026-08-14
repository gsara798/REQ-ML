function tests = test_experimental_bilayer_aia
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
root=string(fileparts(fileparts(fileparts(mfilename('fullpath')))));
addpath(fullfile(root,'analysis','benchmarks', ...
    'experimental_bilayer_400hz','aia'));
testCase.TestData.root=root;
end

function testSyntheticHarmonicFieldContract(testCase)
[U,dx,f0]=field_fixture();
[cs,k,x,z,d]=aia_estimator_RSWE(U,dx,dx,f0, ...
    WindowSize=[15 15],StepX=10,StepZ=10,NumAngles=12,UseParfor=false);
verifySize(testCase,cs,[4 4]); verifySize(testCase,k,[4 4]);
verifySize(testCase,x,[1 4]); verifySize(testCase,z,[1 4]);
verifyEqual(testCase,d.win_x,15); verifyEqual(testCase,d.win_z,15);
verifyFalse(testCase,d.decimation.applied);
verifyEqual(testCase,d.implementation_label, ...
    "source_faithful_contract_cleaned");
verifyTrue(testCase,any(isfinite(cs),'all'));
end

function testReproducible(testCase)
[U,dx,f0]=field_fixture();
args={'WindowSize',[15 15],'StepX',15,'StepZ',15, ...
    'NumAngles',8,'UseParfor',false};
a=aia_estimator_RSWE(U,dx,dx,f0,args{:});
b=aia_estimator_RSWE(U,dx,dx,f0,args{:});
verifyEqual(testCase,a,b,AbsTol=0);
end

function testRequiredInputsFailClearly(testCase)
[U,dx,f0]=field_fixture();
verifyError(testCase,@() aia_estimator_RSWE(U,dx,dx,0), ...
    'reqml:aia:InvalidFrequency');
verifyError(testCase,@() aia_estimator_RSWE(U,dx,2*dx,f0), ...
    'reqml:aia:AnisotropicSpacing');
end

function [U,dx,f0]=field_fixture()
dx=0.5e-3; f0=400; cs=2; [X,Z]=meshgrid((0:44)*dx);
U=exp(1i*2*pi*f0/cs*(0.8*X+0.6*Z)) + ...
    0.4*exp(1i*2*pi*f0/cs*(-0.6*X+0.8*Z)+0.3);
end
