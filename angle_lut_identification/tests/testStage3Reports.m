function tests = testStage3Reports
%TESTSTAGE3REPORTS Stage-3 complete/partial report artifact contract.
tests=functiontests(localfunctions);
end

function testPartialProducesPlaceholdersWithoutChangingGate(testCase)
root=tempname; mkdir(root); cleanup=onCleanup(@()local_remove(root));
write_json_file(fullfile(root,'gate.json'),struct('status','BLOCKED'));
rows=table("M64_NOMINAL","periodic_combined","nominal_model",64,1,19, ...
    0.2,0.3,0.9,0.1,0.1,NaN,"",NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN, ...
    'VariableNames',{'phase','case_id','amplitude_mode','nodes', ...
    'coverage_fraction','fusion_count','shadow_rmse_e_deg','active_rmse_e_deg', ...
    'active_improvement_fraction','scheme4_shadow_difference_e_deg', ...
    'scheme4_active_difference_e_deg','control_angle_improvement', ...
    'control_angle_gate_basis','id_rms_improvement', ...
    'prediction_residual_improvement','torque_ripple_improvement', ...
    'iq_tracking_change','mean_torque_change','lut_drift_e_deg','tangent_rms', ...
    'radial_rms','valid_fraction'});
writetable(rows,fullfile(root,'metrics.csv'));
manifest=generate_stage3_reports(root);
verifyNumElements(testCase,manifest.reports,10);
for k=1:numel(manifest.reports)
    verifyTrue(testCase,isfile(manifest.reports(k).png));
    verifyTrue(testCase,isfile(manifest.reports(k).pdf));
end
verifyTrue(testCase,isfile(fullfile(root,'reports','lut_learning_evolution.gif')));
verifyTrue(testCase,manifest.gate_unchanged);
verifyFalse(testCase,manifest.truth_feedback_used);
clear cleanup;
end

function local_remove(path)
if isfolder(path), rmdir(path,'s'); end
end
