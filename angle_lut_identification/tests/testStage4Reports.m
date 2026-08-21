function tests = testStage4Reports
%TESTSTAGE4REPORTS Stage-4 complete and partial report contracts.
tests=functiontests(localfunctions);
end

function testCompleteDiagnosticProducesAllArtifacts(testCase)
root=tempname; mkdir(root); cleanup=onCleanup(@()local_remove(root));
[histories,sweeps,frozen,comparisons]=local_complete_inputs();
diagnostic=struct('run_id','stage4_report_test','final_status','PASS', ...
    'diagnostic_outcome','scheme2_diagnostic_complete');
diagnosticBefore=diagnostic;

manifest=generate_stage4_reports(diagnostic,histories,sweeps,frozen, ...
    comparisons,root);

verifyEqual(testCase,numel(manifest.reports),7);
verifyEqual(testCase,manifest.final_status,'PASS');
verifyFalse(testCase,manifest.truth_feedback_used);
verifyTrue(testCase,manifest.reporting_only);
verifyEqual(testCase,diagnostic,diagnosticBefore);
for k=1:numel(manifest.reports)
    entry=manifest.reports(k);
    verifyTrue(testCase,entry.available,entry.reason);
    local_verify_nonempty(testCase,entry.png);
    local_verify_nonempty(testCase,entry.pdf);
    local_verify_nonempty(testCase,entry.csv);
    local_verify_nonempty(testCase,entry.json);
end
local_verify_nonempty(testCase,fullfile(root,'learning_lut_evolution.gif'));
local_verify_nonempty(testCase,fullfile(root,'report_manifest.json'));

learning=readtable(fullfile(root,'learning_lut_evolution.csv'),'TextType','string');
verifyEqual(testCase,height(learning),2*12*16);
noiseFloor=readtable(fullfile(root,'per_node_noise_floor.csv'));
verifyEqual(testCase,height(noiseFloor),16);
frozenTable=readtable(fullfile(root,'frozen_2x2_matrix.csv'),'TextType','string');
verifyEqual(testCase,height(frozenTable),4);
clear cleanup;
end

function testBlockedDiagnosticProducesExplicitPlaceholders(testCase)
root=tempname; mkdir(root); cleanup=onCleanup(@()local_remove(root));
diagnostic=struct('run_id','stage4_blocked_test','final_status','BLOCKED', ...
    'diagnostic_outcome',struct('status','prerequisite_missing'));

manifest=generate_stage4_reports(diagnostic,struct([]),table(), ...
    struct([]),struct([]),root);

verifyEqual(testCase,manifest.final_status,'BLOCKED');
verifyTrue(testCase,manifest.partial_and_blocked_safe);
for k=1:numel(manifest.reports)
    entry=manifest.reports(k);
    verifyFalse(testCase,entry.available);
    verifyNotEmpty(testCase,entry.reason);
    local_verify_nonempty(testCase,entry.png);
    local_verify_nonempty(testCase,entry.pdf);
    local_verify_nonempty(testCase,entry.csv);
    local_verify_nonempty(testCase,entry.json);
    placeholder=readtable(entry.csv,'TextType','string');
    verifyTrue(testCase,ismember('available',placeholder.Properties.VariableNames));
    verifyEqual(testCase,placeholder.available(1),0);
end
local_verify_nonempty(testCase,fullfile(root,'learning_lut_evolution.gif'));
local_verify_nonempty(testCase,fullfile(root,'report_manifest.json'));
clear cleanup;
end

function [histories,sweeps,frozen,comparisons]=local_complete_inputs()
M=16; F=12; phi=(0:M-1).'*2*pi/M;
reference=deg2rad(8*sin(phi)+3*sin(2*phi+0.25));
gain=reshape(linspace(0.2,0.98,F),[],1);
shadow=gain*reference.';
active=(reshape(linspace(0.08,0.94,F),[],1))*reference.';

histories(1)=struct('condition','zero_noise','fusion_count',(1:F).', ...
    'time_s',linspace(1,12,F).','travel_m_rad',2*pi*linspace(1,12,F).', ...
    'shadow_lut_e_rad',shadow,'active_lut_e_rad',active, ...
    'reference_lut_e_rad',reference);
nodeNoise=deg2rad(0.18*sin(3*phi+0.4));
histories(2)=struct('condition','noise95_pm0p1A','fusion_count',(1:F).', ...
    'time_s',linspace(1,12,F).','travel_m_rad',2*pi*linspace(1,12,F).', ...
    'shadow_lut_e_rad',shadow+gain*nodeNoise.', ...
    'active_lut_e_rad',active+gain*nodeNoise.', ...
    'reference_lut_e_rad',reference);

family=[repmat("mu2",6,1);repmat("update_decimation",6,1)];
value=[0.05;0.10;0.20;0.05;0.10;0.20;1;2;4;1;2;4];
condition=repmat(["zero_noise";"zero_noise";"zero_noise"; ...
    "noise95_pm0p1A";"noise95_pm0p1A";"noise95_pm0p1A"],2,1);
activeRmse=[1.4;0.8;1.1;1.7;1.0;1.3;0.8;0.9;1.2;1.0;1.1;1.4];
shadowRmse=0.75*activeRmse; fusionCount=18*ones(12,1); finite=true(12,1);
sweeps=table(family,value,condition,activeRmse,shadowRmse,fusionCount,finite, ...
    'VariableNames',{'sweep_family','value','condition','active_rmse_e_deg', ...
    'shadow_rmse_e_deg','fusion_count','finite'});

train=["zero_noise","zero_noise","noise95_pm0p1A","noise95_pm0p1A"];
evaluation=["zero_noise","noise95_pm0p1A","zero_noise","noise95_pm0p1A"];
improvement=[0.78,0.66,0.71,0.63];
for k=1:4
    baseline=struct('control_angle_rmse_e_deg',4+0.2*k);
    activeMetric=struct('control_angle_rmse_e_deg',baseline.control_angle_rmse_e_deg* ...
        (1-improvement(k)));
    frozen(k)=struct('training_condition',train(k), ...
        'evaluation_condition',evaluation(k),'baseline',baseline, ...
        'active',activeMetric,'control_angle_improvement',improvement(k), ...
        'control_angle_gate_basis','percent_improvement', ...
        'id_rms_improvement',0.10,'prediction_residual_improvement',0.08, ...
        'torque_ripple_improvement',0.07,'iq_tracking_change',0.01, ...
        'mean_torque_change',0.005); %#ok<AGROW>
end

conditions=["zero_noise","noise95_pm0p1A"];
for k=1:2
    comparisons(k)=struct('condition',conditions(k), ...
        'scheme4_active_rmse_e_deg',0.30+0.05*k, ...
        'scheme5_active_rmse_e_deg',0.38+0.05*k, ...
        'scheme2_active_rmse_e_deg',0.46+0.05*k, ...
        'scheme4_storage_bytes',4200, ...
        'scheme5_storage_bytes',1800, ...
        'scheme2_storage_bytes',900, ...
        'scheme4_sample_ops_estimate',22, ...
        'scheme5_sample_ops_estimate',18, ...
        'scheme2_sample_ops_estimate',9); %#ok<AGROW>
end
end

function local_verify_nonempty(testCase,path)
verifyTrue(testCase,isfile(path),path);
info=dir(path); verifyGreaterThan(testCase,info.bytes,0,path);
end

function local_remove(path)
if isfolder(path), rmdir(path,'s'); end
end
