function tests = testStage2Reports
%TESTSTAGE2REPORTS Partial-run report contract.
tests = functiontests(localfunctions);
end

function testPartialRunProducesAuditablePlaceholders(testCase)
root = tempname;
mkdir(root);
cleanup = onCleanup(@()local_remove(root));
write_json_file(fullfile(root,'gate.json'),struct('status','BLOCKED'));
rows = table("M64","periodic_combined",64,0,1,18,1e-12,1e-12, ...
    0.2,0.2,0.3,0.5,0.95,NaN,NaN,NaN,NaN,NaN,NaN,NaN, ...
    'VariableNames',{'phase','case_id','nodes','elapsed_s', ...
    'coverage_fraction','solve_count','solver_relative_difference', ...
    'normal_equation_relative_residual','rcond','shadow_rmse_e_deg', ...
    'active_rmse_e_deg','active_max_error_e_deg', ...
    'lut_improvement_fraction','control_angle_improvement', ...
    'id_rms_improvement','prediction_residual_improvement', ...
    'torque_ripple_improvement','iq_tracking_change', ...
    'mean_torque_change','lut_drift_e_deg'});
writetable(rows,fullfile(root,'metrics.csv'));
manifest = generate_stage2_reports(root);
verifyEqual(testCase,numel(manifest.reports),9);
for k = 1:numel(manifest.reports)
    verifyTrue(testCase,isfile(manifest.reports(k).png));
    verifyTrue(testCase,isfile(manifest.reports(k).pdf));
end
verifyTrue(testCase,isfile(fullfile(root,'reports', ...
    'compute_storage_cost.csv')));
verifyFalse(testCase,manifest.truth_feedback_used);
verifyEqual(testCase,manifest.gate_sha256_before, ...
    manifest.gate_sha256_after);
clear cleanup;
end

function local_remove(path)
if isfolder(path), rmdir(path,'s'); end
end
