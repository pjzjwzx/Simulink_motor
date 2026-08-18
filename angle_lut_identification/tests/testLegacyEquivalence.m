classdef testLegacyEquivalence < matlab.unittest.TestCase
    % Integration gate: source model and LEGACY_ELECTRICAL harness match.

    methods (Test)
        function dualModelRuntimeEquivalence(testCase)
            cfg = setup_project();
            sourceHash = file_sha256(cfg.source_model);

            result = check_legacy_equivalence(cfg);

            testCase.verifyEqual(result.evidence_level, ...
                'A_NUMERICAL_DUAL_MODEL_RUNTIME_PORT_LOGGING');
            testCase.verifyEqual(result.stop_time_s, 0.02, ...
                'Baseline equivalence duration contract changed.');
            testCase.verifyTrue(result.source_unchanged, ...
                'The source-model hash changed during the gate.');
            testCase.verifyEqual(result.source_sha256_after, sourceHash);
            testCase.verifyEmpty(result.failure, result.failure);
            testCase.verifyTrue(result.all_observables_pass, ...
                local_failure_message(result));
            testCase.verifyEqual(result.status, 'PASS', ...
                local_failure_message(result));
        end
    end
end

function message = local_failure_message(result)
if ~isempty(result.failure)
    message = result.failure;
    return;
end
failed = result.signals(~[result.signals.passed]);
if isempty(failed)
    message = 'Legacy-equivalence status failed without a failed signal.';
    return;
end
parts = strings(numel(failed), 1);
for k = 1:numel(failed)
    parts(k) = sprintf('%s: max=%g tol=%g time=%g', ...
        failed(k).signal, failed(k).max_abs_error, ...
        failed(k).tolerance, failed(k).max_time_error_s);
end
message = char(strjoin(parts, '; '));
end
