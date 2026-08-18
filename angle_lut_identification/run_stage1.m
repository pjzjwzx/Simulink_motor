function result = run_stage1(options)
%RUN_STAGE1 Execute the Stage-1 encoder-error residual verification.
%   R1 = RUN_STAGE1() executes the complete, explicit 36-case matrix after
%   checking the latest Stage-0 PASS artifact.  R1 = RUN_STAGE1(OPTIONS)
%   supports bounded engineering smoke runs without changing the saved
%   model.  All model overrides use Simulink.SimulationInput.

if nargin < 1 || isempty(options)
    options = struct();
end
options = local_options(options);
cfg = setup_project();

runId = ['stage1_' char(datetime('now','Format','yyyyMMdd_HHmmss_SSS'))];
outDir = fullfile(cfg.project_root, 'results', runId, 'stage1');
figureDir = fullfile(outDir, 'figures');
failureDir = fullfile(outDir, 'failures');
caseRoot = fullfile(outDir, 'cases');
local_mkdir(outDir);
local_mkdir(figureDir);
local_mkdir(failureDir);
local_mkdir(caseRoot);

result = struct('run_id',runId, 'final_status','BLOCKED', ...
    'cases',repmat(local_case_result_template(),0,1), ...
    'result_path',outDir, 'message','Stage 1 did not start.');
gate = struct('status','BLOCKED', 'scope','', 'checks',struct(), ...
    'thresholds',cfg.gates.stage1, 'aggregate',struct(), 'errors',{{}});
manifest = local_manifest(cfg, runId, outDir, options);
sourceHashBefore = '';
modelName = '';
metrics = repmat(local_metrics_template(),0,1);
implementations = cell(0,1);
caseResults = repmat(local_case_result_template(),0,1);
selectedCases = repmat(struct(),0,1);
completeMatrix = false;
criticalEarlyStop = false;
gate.critical_early_stop = local_critical_early_stop_template();

% Create the durable result contract before any gate can return early.
% The selected-case payload is filled after Stage 0 and case validation.
write_json_file(fullfile(outDir,'configuration.json'), struct( ...
    'schema_version',cfg.schema_version, 'random_seed',cfg.random_seed, ...
    'options',options, 'default_config',cfg, ...
    'selected_cases',repmat(struct(),0,1)));

try
    [stage0OK, stage0Path, stage0Message] = local_check_stage0(cfg);
    manifest.stage0_result_path = stage0Path;
    gate.checks.stage0_pass = stage0OK;
    if ~stage0OK
        gate.status = 'BLOCKED';
        result.message = stage0Message;
        local_finish();
        return;
    end

    sourceHashBefore = file_sha256(cfg.source_model);
    manifest.source_model_sha256_before = sourceHashBefore;

    builder = fullfile(cfg.project_root,'models','build_angle_lut_harness.m');
    gate.checks.harness_builder_present = isfile(builder);
    if options.rebuild_harness || ~isfile(cfg.harness_model)
        addpath(fileparts(builder));
        buildInfo = build_angle_lut_harness();
        manifest.harness_build = buildInfo;
    end
    gate.checks.harness_present = isfile(cfg.harness_model);
    if ~gate.checks.harness_builder_present || ~gate.checks.harness_present
        error('anglelut:HarnessUnavailable', ...
            'Stage-1 harness or its reproducible builder is missing.');
    end

    % This workspace is intentionally not a Git repository. Preserve an
    % immutable inventory of the implementation inputs instead of a
    % commit/diff identifier. Generated results and Simulink caches are
    % excluded by the collector.
    inventory = collect_file_inventory(cfg.project_root);
    inventoryCsv = fullfile(outDir,'file_inventory.csv');
    inventoryJson = fullfile(outDir,'file_inventory.json');
    writetable(inventory,inventoryCsv);
    write_json_file(inventoryJson,table2struct(inventory));
    manifest.file_inventory = struct( ...
        'csv_path',inventoryCsv, ...
        'json_path',inventoryJson, ...
        'entry_count',height(inventory), ...
        'csv_sha256',file_sha256(inventoryCsv));
    manifest.environment = collect_environment_manifest( ...
        cfg.source_model,cfg.timing);
    gate.checks.file_inventory_written = isfile(inventoryCsv) && ...
        isfile(inventoryJson) && height(inventory) > 0;
    gate.checks.environment_manifest_recorded = ...
        ~isempty(manifest.environment.products) && ...
        isfield(manifest.environment,'model') && ...
        isfield(manifest.environment,'powergui');

    allCases = case_matrix(cfg);
    selectedCases = local_select_cases(allCases, options);
    selectedIdentityComplete = numel(selectedCases) == numel(allCases) && ...
        isequal(string({selectedCases.case_id}), string({allCases.case_id}));
    contractualStopTimes = isempty(options.stop_time_override_s);
    completeMatrix = selectedIdentityComplete && contractualStopTimes;
    if ~contractualStopTimes
        for caseIndex = 1:numel(selectedCases)
            selectedCases(caseIndex).stop_time_s = ...
                double(options.stop_time_override_s);
        end
    end
    gate.scope = ternary(completeMatrix, 'FULL_STAGE1', 'BOUNDED_SMOKE');
    gate.critical_early_stop.eligible = completeMatrix;
    gate.checks.complete_case_matrix = completeMatrix;
    gate.checks.case_matrix_identity_selected = selectedIdentityComplete;
    gate.checks.contractual_stop_times = contractualStopTimes;
    manifest.case_count_defined = numel(allCases);
    manifest.case_count_selected = numel(selectedCases);
    manifest.case_ids = string({selectedCases.case_id});
    manifest.contractual_stop_times = contractualStopTimes;
    write_json_file(fullfile(outDir,'configuration.json'), ...
        struct('schema_version',cfg.schema_version, 'random_seed',cfg.random_seed, ...
        'options',options, 'default_config',cfg, 'selected_cases',selectedCases));

    [testsPassed, testSummary] = local_run_tests(cfg, outDir, options.run_tests);
    gate.checks.unit_and_structure_tests = testsPassed && testSummary.enabled;
    manifest.tests = testSummary;
    if testSummary.enabled && ~testsPassed
        gate.status = 'FAIL';
        result.message = 'A mandatory unit or structure test failed.';
        local_finish();
        return;
    end

    [~, modelName] = fileparts(cfg.harness_model);
    load_system(cfg.harness_model);
    set_param(modelName,'SimulationCommand','update');
    gate.checks.harness_load_and_update = true;
    gate.checks.saved_default_periodic_error = local_check_saved_defaults(modelName);

    for k = 1:numel(selectedCases)
        c = selectedCases(k);
        caseDir = fullfile(caseRoot, char(c.case_id));
        local_mkdir(caseDir);
        write_json_file(fullfile(caseDir,'case_config.json'),c);
        fprintf('[Stage1 %d/%d] %s, StopTime %.6g s\n', ...
            k, numel(selectedCases), c.case_id, c.stop_time_s);
        started = tic;
        one = local_case_result_template();
        one.case_id = char(c.case_id);
        one.status = 'FAIL';
        one.elapsed_s = NaN;
        one.result_path = caseDir;
        try
            simIn = local_simulation_input(modelName, c, cfg, options);
            simOut = sim(simIn);
            [m, trace, implementation] = analyze_stage1_case(simOut,c,cfg);
            m.case_status = ternary(isfinite(m.rmse_e_rad) && ...
                m.valid_sample_count > 0, 'PASS', 'FAIL');
            m.simulation_elapsed_s = toc(started);
            one.status = m.case_status;
            one.elapsed_s = m.simulation_elapsed_s;
            one.voltage_ab_selected_source = m.voltage_ab_selected_source;
            one.voltage_ab_selected_branch_rmse_e_deg = ...
                m.voltage_ab_selected_branch_rmse_e_deg;
            one.message = ternary(strcmp(one.status,'PASS'), ...
                'Simulation and analysis completed.', ...
                'No finite accepted residual estimate was produced.');
            metrics(end+1,1) = local_normalize_metrics(m); %#ok<AGROW>
            implementations{end+1,1} = local_tag_implementation( ...
                implementation,c.case_id); %#ok<AGROW>
            write_json_file(fullfile(caseDir,'metrics.json'),m);
            write_json_file(fullfile(caseDir,'implementation.json'),implementation);
            save(fullfile(caseDir,'trace.mat'),'trace','-v7.3');
            accepted = trace.valid & trace.evaluation_mask;
            save_stage1_case_plot(fullfile(figureDir, ...
                [char(c.case_id) '.png']), trace.time_s, ...
                trace.estimate_e_rad,trace.truth_error_e_rad,accepted,c.case_id);
        catch caseError
            one.elapsed_s = toc(started);
            one.message = caseError.message;
            local_write_text(fullfile(failureDir,[char(c.case_id) '.txt']), ...
                getReport(caseError,'extended','hyperlinks','off'));
            caseResults(end+1,1) = one; %#ok<AGROW>
            result.cases = caseResults;
            if options.stop_on_case_error
                rethrow(caseError);
            end
            if local_evaluate_critical_prefix(k)
                break;
            end
            continue;
        end
        caseResults(end+1,1) = one; %#ok<AGROW>
        result.cases = caseResults;
        if local_evaluate_critical_prefix(k)
            break;
        end
    end

    if bdIsLoaded(modelName)
        close_system(modelName,0);
        modelName = '';
    end
    gate.checks.all_selected_cases_executed = ...
        numel(caseResults) == numel(selectedCases);
    gate.checks.all_selected_cases_analyzed = ...
        numel(metrics) == numel(selectedCases) && ...
        all(strcmp({caseResults.status},'PASS'));

    [metrics,predictorFloorReference] = ...
        apply_predictor_floor_reference(metrics);
    manifest.predictor_floor_reference = predictorFloorReference;
    local_write_case_metric_json(caseRoot,metrics);
    local_write_case_artifacts(outDir,metrics,implementations);

    acceptanceComplete = completeMatrix && ...
        gate.checks.all_selected_cases_analyzed;
    [acceptanceChecks, aggregate] = local_acceptance( ...
        metrics,selectedCases,cfg,acceptanceComplete);
    gate.aggregate = aggregate;
    acceptanceFields = fieldnames(acceptanceChecks);
    for k = 1:numel(acceptanceFields)
        gate.checks.(acceptanceFields{k}) = acceptanceChecks.(acceptanceFields{k});
    end

    sourceHashAfter = file_sha256(cfg.source_model);
    manifest.source_model_sha256_after = sourceHashAfter;
    gate.checks.source_hash_unchanged = strcmp(sourceHashBefore,sourceHashAfter);
    manifest.harness_model_sha256 = file_sha256(cfg.harness_model);
    manifest.case_count_completed = numel(metrics);
    manifest.case_implementations = implementations;

    if criticalEarlyStop
        gate.status = 'FAIL';
        result.message = sprintf([ ...
            'Critical early stop after %s: fixed-prefix acceptance failed; ' ...
            '%d remaining cases were not executed.'], ...
            gate.critical_early_stop.after_case_id, ...
            gate.critical_early_stop.unexecuted_case_count);
    elseif ~completeMatrix
        smokeIgnored = {'complete_case_matrix','full_acceptance_evaluated', ...
            'case_matrix_identity_selected','contractual_stop_times', ...
            'unit_and_structure_tests', ...
            'fixed_5deg_mean_error','fixed_fit','ideal_rmse', ...
            'nonideal_rmse','forward_reverse_bias', ...
            'ideal_voltage_reconstruction','periodic_minimum_cycles', ...
            'case_matrix_identity'};
        gate.status = ternary(local_all_checks_except(gate.checks, ...
            smokeIgnored), ...
            'BLOCKED','FAIL');
        result.message = ['Bounded smoke completed; the full Stage-1 ' ...
            'acceptance matrix was intentionally not executed.'];
    elseif local_all_checks_except(gate.checks,{})
        gate.status = 'PASS';
        result.message = 'Full Stage-1 matrix and all acceptance gates passed.';
    else
        gate.status = 'FAIL';
        result.message = 'Stage 1 completed, but one or more mandatory gates failed.';
    end
catch ME
    if ~isempty(modelName) && bdIsLoaded(modelName)
        close_system(modelName,0);
    end
    gate.errors = {getReport(ME,'extended','hyperlinks','off')};
    if strcmp(ME.identifier,'anglelut:HarnessUnavailable')
        gate.status = 'BLOCKED';
    else
        gate.status = 'FAIL';
    end
    result.message = ME.message;
    local_write_text(fullfile(failureDir,'run_error.txt'),gate.errors{1});
    try
        if ~isempty(sourceHashBefore)
            manifest.source_model_sha256_after = file_sha256(cfg.source_model);
            gate.checks.source_hash_unchanged = strcmp(sourceHashBefore, ...
                manifest.source_model_sha256_after);
        end
    catch
    end
end

local_finish();

    function local_finish()
        % Persist partial progress as well as successful completion. This
        % makes an early Stage-0/test/case failure auditable instead of
        % leaving a run directory without the promised result artifacts.
        result.cases = caseResults;
        [metrics,predictorFloorReference] = ...
            apply_predictor_floor_reference(metrics);
        manifest.predictor_floor_reference = predictorFloorReference;
        local_write_case_metric_json(caseRoot,metrics);
        local_write_case_artifacts(outDir,metrics,implementations);
        local_ensure_tests_csv(outDir);
        if ~isempty(sourceHashBefore)
            try
                sourceHashAfter = file_sha256(cfg.source_model);
                manifest.source_model_sha256_after = sourceHashAfter;
                gate.checks.source_hash_unchanged = ...
                    strcmp(sourceHashBefore,sourceHashAfter);
                if strcmp(gate.status,'PASS') && ...
                        ~gate.checks.source_hash_unchanged
                    gate.status = 'FAIL';
                    result.message = 'The preserved source-model hash changed.';
                end
            catch hashError
                gate.errors{end+1} = getReport(hashError, ...
                    'extended','hyperlinks','off');
            end
        end
        if isfile(cfg.harness_model)
            try
                manifest.harness_model_sha256 = file_sha256(cfg.harness_model);
            catch hashError
                gate.errors{end+1} = getReport(hashError, ...
                    'extended','hyperlinks','off');
            end
        end
        manifest.case_count_completed = numel(metrics);
        manifest.case_count_executed = numel(caseResults);
        manifest.case_implementations = implementations;
        manifest.voltage_ab_cases = local_voltage_ab_manifest(metrics);
        result.critical_early_stop = gate.critical_early_stop;
        manifest.critical_early_stop = gate.critical_early_stop;
        manifest.completed_at = local_iso_time();
        manifest.case_count_returned = numel(result.cases);

        % The report builder is strictly offline/evaluation-only. Write a
        % provisional gate so its failure summary can transcribe the same
        % result, then verify the durable report bundle without changing
        % any mathematical metric or threshold.
        write_json_file(fullfile(outDir,'gate.json'),gate);
        reportOK = false;
        try
            reportBundle = generate_stage1_reports(outDir,cfg);
            reportOK = strcmp(reportBundle.generation_status,'COMPLETE') && ...
                isfile(fullfile(reportBundle.report_dir,'report_manifest.json'));
            manifest.reports = reportBundle;
        catch reportError
            manifest.reports = struct('generation_status','FAILED', ...
                'message',reportError.message);
            gate.errors{end+1} = getReport(reportError, ...
                'extended','hyperlinks','off');
            local_write_text(fullfile(failureDir,'report_error.txt'), ...
                gate.errors{end});
        end
        gate.checks.report_bundle_generated = reportOK;
        if completeMatrix && ~reportOK
            gate.status = 'FAIL';
            result.message = ['Stage 1 numerical execution completed, but ' ...
                'the mandatory report bundle was not generated.'];
        end

        result.final_status = gate.status;
        manifest.final_status = gate.status;
        write_json_file(fullfile(outDir,'gate.json'),gate);
        write_json_file(fullfile(outDir,'run_manifest.json'),manifest);
        write_json_file(fullfile(outDir,'result.json'),result);
        pointer = fullfile(cfg.project_root,'results','latest_stage1.txt');
        local_write_text(pointer,[outDir newline]);
    end

    function triggered = local_evaluate_critical_prefix(caseIndex)
        triggered = false;
        if ~completeMatrix || caseIndex ~= 5 || ...
                gate.critical_early_stop.evaluated
            return;
        end

        [metrics,predictorFloorReference] = ...
            apply_predictor_floor_reference(metrics);
        manifest.predictor_floor_reference = predictorFloorReference;
        local_write_case_metric_json(caseRoot,metrics);
        [prefixPassed,prefixChecks,prefixAggregate] = ...
            evaluate_fixed_prefix_acceptance(metrics,cfg);
        gate.checks.critical_fixed_prefix_complete = ...
            prefixChecks.prefix_complete;
        gate.checks.critical_fixed_5deg_mean_error = ...
            prefixChecks.fixed_5deg_mean_error;
        gate.checks.critical_fixed_fit = prefixChecks.fixed_fit;
        gate.checks.critical_fixed_ideal_rmse = prefixChecks.ideal_rmse;
        gate.checks.critical_fixed_prefix_pass = prefixPassed;

        gate.critical_early_stop.evaluated = true;
        gate.critical_early_stop.triggered = ~prefixPassed;
        gate.critical_early_stop.after_case_id = char(selectedCases(caseIndex).case_id);
        gate.critical_early_stop.completed_case_count = numel(caseResults);
        gate.critical_early_stop.completed_metric_count = numel(metrics);
        remainingAtEvaluation = numel(selectedCases) - numel(caseResults);
        gate.critical_early_stop.remaining_case_count_at_evaluation = ...
            remainingAtEvaluation;
        gate.critical_early_stop.unexecuted_case_count = ...
            double(~prefixPassed) * remainingAtEvaluation;
        if ~prefixPassed
            gate.critical_early_stop.unexecuted_case_ids = string( ...
                {selectedCases(caseIndex+1:end).case_id});
        end
        gate.critical_early_stop.checks = prefixChecks;
        gate.critical_early_stop.aggregate = prefixAggregate;

        failedNames = fieldnames(prefixChecks);
        failedNames = failedNames(~structfun(@logical,prefixChecks));
        if prefixPassed
            gate.critical_early_stop.reason = ...
                'Critical fixed-prefix acceptance passed; execution continued.';
        else
            gate.critical_early_stop.reason = sprintf( ...
                'Failed critical checks: %s.',strjoin(failedNames,', '));
            criticalEarlyStop = true;
            triggered = true;
            fprintf('[Stage1] CRITICAL EARLY STOP after %s: %s\n', ...
                gate.critical_early_stop.after_case_id, ...
                gate.critical_early_stop.reason);
        end
    end
end

function options = local_options(options)
assert(isstruct(options) && isscalar(options), ...
    'anglelut:InvalidOption','options must be a scalar struct.');
defaults = struct('case_ids',strings(0,1), 'max_cases',Inf, ...
    'stop_time_override_s',[], 'simulation_mode','rapid-accelerator', ...
    'run_tests',true, 'rebuild_harness',false, ...
    'stop_on_case_error',true);
names = fieldnames(defaults);
for k = 1:numel(names)
    if ~isfield(options,names{k})
        options.(names{k}) = defaults.(names{k});
    end
end
options.case_ids = string(options.case_ids);
assert(isempty(options.stop_time_override_s) || ...
    (isnumeric(options.stop_time_override_s) && ...
    isscalar(options.stop_time_override_s) && ...
    isreal(options.stop_time_override_s) && ...
    isfinite(options.stop_time_override_s) && ...
    options.stop_time_override_s > 0), ...
    'anglelut:InvalidOption', ...
    'stop_time_override_s must be empty or a finite positive scalar.');
assert(isnumeric(options.max_cases) && isscalar(options.max_cases) && ...
    isreal(options.max_cases) && ~isnan(options.max_cases) && ...
    options.max_cases >= 1 && ...
    (isinf(options.max_cases) || fix(options.max_cases) == options.max_cases), ...
    'anglelut:InvalidOption', ...
    'max_cases must be a positive integer scalar or Inf.');
options.simulation_mode = string(options.simulation_mode);
assert(isscalar(options.simulation_mode) && any(options.simulation_mode == ...
    ["normal","accelerator","rapid-accelerator"]), ...
    'anglelut:InvalidOption', ...
    'simulation_mode must be normal, accelerator, or rapid-accelerator.');
logicalNames = {'run_tests','rebuild_harness','stop_on_case_error'};
for k = 1:numel(logicalNames)
    value = options.(logicalNames{k});
    assert((islogical(value) || isnumeric(value)) && isscalar(value) && ...
        isreal(value) && isfinite(value) && any(double(value) == [0 1]), ...
        'anglelut:InvalidOption','%s must be a logical scalar.', ...
        logicalNames{k});
    options.(logicalNames{k}) = logical(value);
end
end

function manifest = local_manifest(cfg,runId,outDir,options)
manifest = struct();
manifest.schema_version = 'angle-lut-stage1-run-v1';
manifest.run_id = runId;
manifest.stage = 1;
manifest.created_at = local_iso_time();
manifest.project_root = cfg.project_root;
manifest.result_path = outDir;
manifest.matlab_version = version;
manifest.release = version('-release');
installed = ver;
manifest.products = string({installed.Name});
manifest.random_seed = cfg.random_seed;
manifest.source_model = cfg.source_model;
manifest.harness_model = cfg.harness_model;
manifest.theory_pdf = cfg.theory_pdf;
manifest.implementation_spec = cfg.implementation_doc;
manifest.options = options;
manifest.formula_contract = 'Angle_LUT_Theory_Review_v1.1 E01-E09';
manifest.lut_learning_enabled = false;
manifest.control_compensation_e_rad = 0;
manifest.voltage_ab_contract = struct( ...
    'deployment_source','reconstructed_duty_vdc', ...
    'plant_source','plant_applied_evaluation_only', ...
    'case_selector_field','voltage_source', ...
    'gate_source','reconstructed_deployment_only', ...
    'truth_policy','branch scoring only; never estimator or gates');
end

function [ok,path,message] = local_check_stage0(cfg)
pointer = fullfile(cfg.project_root,'results','latest_stage0.txt');
ok = false;
path = '';
message = 'No Stage-0 result pointer exists.';
if ~isfile(pointer), return; end
path = strtrim(fileread(pointer));
gatePath = fullfile(path,'gate.json');
if ~isfile(gatePath)
    message = 'The latest Stage-0 gate artifact is missing.';
    return;
end
manifestPath = fullfile(path,'run_manifest.json');
if ~isfile(manifestPath)
    message = 'The latest Stage-0 manifest artifact is missing.';
    return;
end
try
    s0 = jsondecode(fileread(gatePath));
    m0 = jsondecode(fileread(manifestPath));
catch artifactError
    message = ['The latest Stage-0 artifacts are unreadable: ' ...
        artifactError.message];
    return;
end
if ~isfield(s0,'status') || ~strcmp(s0.status,'PASS') || ...
        ~isfield(m0,'final_status') || ~strcmp(m0.final_status,'PASS')
    message = 'The latest Stage 0 is not PASS.';
    return;
end
if ~isfield(m0,'model_sha256_after') || ...
        ~strcmpi(char(m0.model_sha256_after),file_sha256(cfg.source_model))
    message = ['The source model no longer matches the model that ' ...
        'passed Stage 0.'];
    return;
end
ok = true;
message = 'Latest Stage 0 is PASS and its source-model hash still matches.';
end

function [passed,summary] = local_run_tests(cfg,outDir,enabled)
summary = struct('enabled',logical(enabled),'skipped',~logical(enabled), ...
    'count',0,'passed',0,'failed',0,'incomplete',0);
if ~enabled
    % Intended only for bounded developer smoke runs.  The default/full
    % Stage-1 entrypoint always executes the mandatory tests.
    passed = true;
    local_write_empty_tests_csv(outDir);
    return;
end
testResults = runtests(fullfile(cfg.project_root,'tests'), ...
    'IncludeSubfolders',true);
t = table(string({testResults.Name}).', [testResults.Passed].', ...
    [testResults.Failed].', [testResults.Incomplete].', ...
    seconds([testResults.Duration].'), ...
    'VariableNames',{'Name','Passed','Failed','Incomplete','Duration'});
writetable(t,fullfile(outDir,'tests.csv'));
summary.count = numel(testResults);
summary.passed = nnz([testResults.Passed]);
summary.failed = nnz([testResults.Failed]);
summary.incomplete = nnz([testResults.Incomplete]);
passed = summary.count > 0 && summary.passed == summary.count && ...
    summary.failed == 0 && summary.incomplete == 0;
end

function cases = local_select_cases(allCases,options)
cases = allCases;
if ~isempty(options.case_ids)
    ids = string({cases.case_id});
    requested = options.case_ids(:).';
    missing = setdiff(requested,ids);
    assert(isempty(missing),'anglelut:UnknownCase', ...
        'Unknown case IDs: %s',strjoin(missing,', '));
    keep = ismember(ids,requested);
    cases = cases(keep);
end
limit = min(numel(cases),floor(double(options.max_cases)));
cases = cases(1:limit);
assert(~isempty(cases),'anglelut:NoCases','No Stage-1 cases were selected.');
end

function pass = local_check_saved_defaults(modelName)
mw = get_param(modelName,'ModelWorkspace');
pass = isequal(mw.evalin('sensor_mode'),uint8(1)) && ...
    isequal(mw.evalin('encoder_error_mode'),uint8(2)) && ...
    mw.evalin('encoder_theta_offset_rad') == 0 && ...
    mw.evalin('theta0_e_rad') == 0 && ...
    abs(mw.evalin('encoder_error_amp1_m_rad')-deg2rad(0.60)) < 1e-15 && ...
    abs(mw.evalin('encoder_error_amp2_m_rad')-deg2rad(0.30)) < 1e-15;
end

function simIn = local_simulation_input(modelName,c,cfg,options)
simIn = Simulink.SimulationInput(modelName);
workspace = modelName;
fixedBias = double(c.periodic_bias_m_rad);
if c.error_mode == cfg.encoder.ERROR_FIXED
    fixedBias = double(c.fixed_error_e_rad) / cfg.motor.pole_pairs;
end
initial = local_equilibrium_initialization(c,cfg,fixedBias);
overrides = { ...
    'sensor_mode',uint8(c.sensor_mode); ...
    'encoder_error_mode',uint8(c.error_mode); ...
    'encoder_error_bias_m_rad',fixedBias; ...
    'encoder_error_amp1_m_rad',double(c.periodic_amp1_m_rad); ...
    'encoder_error_phase1_rad',double(c.periodic_phase1_rad); ...
    'encoder_error_amp2_m_rad',double(c.periodic_amp2_m_rad); ...
    'encoder_error_phase2_rad',double(c.periodic_phase2_rad); ...
    'theta0_e_rad',double(c.theta0_e_rad); ...
    'encoder_counts_per_rev',double(c.encoder_counts_per_rev); ...
    ... % Keep the control angle synchronous; the 1-kHz path is timestamped analysis.
    'angle_sample_period_s',1/cfg.timing.angle_sync_sample_Hz; ...
    'encoder_noise_std_m_rad',double(c.angle_noise_std_m_rad); ...
    'encoder_noise_seed',uint32(c.random_seed); ...
    'stage1_current_noise_std_A',double(c.current_noise_std_A); ...
    'stage1_current_noise_seed',uint32(c.random_seed); ...
    'pwm_deadtime_s',double(c.deadtime_s); ...
    'pwm_min_pulse_duty',double(c.min_pulse_duty); ...
    'inverter_voltage_drop_V',double(c.inverter_voltage_drop_V); ...
    ... % Despite the legacy block label "RPM", its downstream gain is 2*pi.
    ... % The Step value is therefore mechanical revolutions per second.
    'stage1_speed_target_rpm',double(c.omega_m_radps)/(2*pi); ...
    'stage1_speed_initial_revps',initial.omega_m_radps/(2*pi); ...
    'stage1_omega_m_initial_radps',initial.omega_m_radps; ...
    'stage1_speed_pi_initial_A',initial.speed_pi_output_A; ...
    'stage1_idq_initial_A',initial.plant_idq_A; ...
    'stage1_load_torque_Nm',double(c.load_torque_Nm); ...
    'stage1_ident_phase_s',cfg.timing.identification_event_offset_s; ...
    'T_ident',cfg.timing.T_ident_s; ...
    'stage1_overmod_epsilon',1e-12};
for k = 1:size(overrides,1)
    simIn = simIn.setVariable(overrides{k,1},overrides{k,2}, ...
        'Workspace',workspace);
end
simIn = simIn.setModelParameter( ...
    'StopTime',sprintf('%.17g',double(c.stop_time_s)), ...
    'SimulationMode',char(options.simulation_mode), ...
    'ReturnWorkspaceOutputs','on', ...
    'SaveTime','off','SaveOutput','off','SaveState','off');
end

function initial = local_equilibrium_initialization(c,cfg,fixedBias)
% Initialize the unchanged plant/controller at the requested operating
% point.  This replaces a long acquisition transient with a reproducible
% equilibrium; no feedback gain, limit, sample time, or solver is changed.
omega_m_radps = double(c.omega_m_radps);
load_torque_Nm = double(c.load_torque_Nm);
B = cfg.motor.viscous_friction_Nm_per_radps;
Kt = 1.5 * cfg.motor.pole_pairs * cfg.motor.psi_f_Wb;

if c.sensor_mode == cfg.sensor.MODE_MECHANICAL_STAGE1
    theta_grid_m_rad = (0:4095).' * (2*pi/4096);
    error_grid_m_rad = local_case_error_m(theta_grid_m_rad,c,fixedBias,cfg);
    step_m_rad = 2*pi/double(c.encoder_counts_per_rev);
    theta_sensor_grid_m_rad = step_m_rad * round( ...
        mod(theta_grid_m_rad + error_grid_m_rad,2*pi) / step_m_rad);
    delta_grid_e_rad = anglelut.wrap_to_pi( ...
        cfg.motor.pole_pairs * (theta_sensor_grid_m_rad-theta_grid_m_rad) + ...
        double(c.theta0_e_rad));
    torque_factor = mean(cos(delta_grid_e_rad));

    error_m_rad = local_case_error_m(0,c,fixedBias,cfg);
    theta_m_sensor_rad = step_m_rad * round(mod(error_m_rad,2*pi)/step_m_rad);
    delta_e_rad = anglelut.wrap_to_pi( ...
        cfg.motor.pole_pairs * theta_m_sensor_rad + double(c.theta0_e_rad));
else
    delta_e_rad = 0;
    torque_factor = 1;
end

torque_per_controller_iq = Kt * torque_factor;
assert(abs(torque_per_controller_iq) > 0.25*Kt, ...
    'anglelut:InvalidEquilibriumAngle', ...
    'Initial encoder angle leaves insufficient torque authority.');
iq_controller_A = (load_torque_Nm + B*omega_m_radps) / ...
    torque_per_controller_iq;

% Sum3 is PI_output - B*omega.  Plant idq0 is in the true rotor frame,
% whereas the current command is in the raw encoder frame.
speed_pi_output_A = iq_controller_A + B*omega_m_radps;
plant_idq_A = [-iq_controller_A*sin(delta_e_rad), ...
                iq_controller_A*cos(delta_e_rad)];

initial = struct( ...
    'omega_m_radps',omega_m_radps, ...
    'delta_e_rad',delta_e_rad, ...
    'iq_controller_A',iq_controller_A, ...
    'speed_pi_output_A',speed_pi_output_A, ...
    'plant_idq_A',plant_idq_A);
end

function error_m_rad = local_case_error_m(theta_m_rad,c,fixedBias,cfg)
if c.error_mode == cfg.encoder.ERROR_OFF
    error_m_rad = zeros(size(theta_m_rad));
elseif c.error_mode == cfg.encoder.ERROR_FIXED
    error_m_rad = fixedBias + zeros(size(theta_m_rad));
else
    error_m_rad = fixedBias + ...
        double(c.periodic_amp1_m_rad) .* sin(theta_m_rad + ...
            double(c.periodic_phase1_rad)) + ...
        double(c.periodic_amp2_m_rad) .* sin(2*theta_m_rad + ...
            double(c.periodic_phase2_rad));
end
end

function tagged = local_tag_implementation(implementation,caseId)
tagged = implementation;
tagged.case_id = char(caseId);
end

function summaries = local_voltage_ab_manifest(metrics)
template = struct('case_id','', 'selected_source','', ...
    'selected_branch_rmse_e_deg',NaN, ...
    'pseudo_angle_delta_rms_e_deg',NaN, ...
    'pseudo_angle_delta_mean_e_deg',NaN, ...
    'residual_delta_rms_A',NaN, 'voltage_delta_rms_V',NaN, ...
    'branches_numerically_distinct',false);
if isempty(metrics)
    summaries = repmat(template,0,1);
    return;
end
indices = find(string({metrics.group}) == "voltage_ab");
summaries = repmat(template,numel(indices),1);
for k = 1:numel(indices)
    m = metrics(indices(k));
    summaries(k).case_id = m.case_id;
    summaries(k).selected_source = m.voltage_ab_selected_source;
    summaries(k).selected_branch_rmse_e_deg = ...
        m.voltage_ab_selected_branch_rmse_e_deg;
    summaries(k).pseudo_angle_delta_rms_e_deg = ...
        m.voltage_ab_pseudo_angle_delta_rms_e_deg;
    summaries(k).pseudo_angle_delta_mean_e_deg = ...
        m.voltage_ab_pseudo_angle_delta_mean_e_deg;
    summaries(k).residual_delta_rms_A = ...
        m.voltage_ab_residual_delta_rms_A;
    summaries(k).voltage_delta_rms_V = ...
        m.voltage_ab_voltage_delta_rms_V;
    summaries(k).branches_numerically_distinct = ...
        m.voltage_ab_branches_numerically_distinct;
end
end

function [checks,aggregate] = local_acceptance(metrics,cases,cfg,complete)
checks = struct();
aggregate = struct();
checks.full_acceptance_evaluated = complete;
if isempty(metrics)
    checks.fixed_5deg_mean_error = false;
    checks.fixed_fit = false;
    checks.ideal_rmse = false;
    checks.nonideal_rmse = false;
    checks.forward_reverse_bias = false;
    checks.ideal_voltage_reconstruction = false;
    checks.periodic_minimum_cycles = false;
    checks.minimum_valid_samples = false;
    checks.case_matrix_identity = false;
    return;
end

ids = string({metrics.case_id});
fixed5 = find(ids == "fixed_05deg_e",1);
checks.fixed_5deg_mean_error = ~isempty(fixed5) && ...
    isfinite(metrics(fixed5).mean_estimation_error_e_rad) && ...
    abs(metrics(fixed5).mean_estimation_error_e_rad) <= ...
    cfg.gates.stage1.fixed_5deg_mean_error_max_e_rad;
aggregate.fixed_5deg_mean_error_e_deg = local_field_or_nan(metrics,fixed5, ...
    'mean_estimation_error_e_deg');

fixedIds = ["fixed_00deg_e","fixed_05deg_e","fixed_10deg_e","fixed_20deg_e"];
fixedIdx = arrayfun(@(id)find(ids==id,1),fixedIds,'UniformOutput',false);
if all(~cellfun(@isempty,fixedIdx))
    idx = cell2mat(fixedIdx);
    x = [metrics(idx).commanded_fixed_error_e_rad].';
    y = [metrics(idx).mean_estimate_e_rad].';
    if all(isfinite(x)) && all(isfinite(y))
        fit = polyfit(x,y,1);
    else
        fit = [NaN NaN];
    end
else
    fit = [NaN NaN];
end
aggregate.fixed_fit_slope = fit(1);
aggregate.fixed_fit_intercept_e_deg = rad2deg(fit(2));
checks.fixed_fit = isfinite(fit(1)) && ...
    fit(1) >= cfg.gates.stage1.fixed_fit_slope_range(1) && ...
    fit(1) <= cfg.gates.stage1.fixed_fit_slope_range(2) && ...
    abs(fit(2)) <= cfg.gates.stage1.fixed_fit_intercept_abs_max_e_rad;

    [metrics,predictorFloor] = apply_predictor_floor_reference(metrics);
    isIdeal = strcmp({metrics.expected_class},'ideal') & ...
        ids ~= predictorFloor.source_case_id;
idealThreshold = max(cfg.gates.stage1.ideal_rmse_floor_e_rad, ...
    cfg.gates.stage1.ideal_rmse_predictor_floor_multiplier .* ...
    [metrics.predictor_floor_e_rad]);
idealPass = isfinite([metrics.rmse_e_rad]) & ...
    [metrics.rmse_e_rad] < idealThreshold;
checks.ideal_rmse = any(isIdeal) && all(idealPass(isIdeal));
    aggregate.ideal_case_count = nnz(isIdeal);
    aggregate.ideal_failed_case_ids = ids(isIdeal & ~idealPass);
    aggregate.predictor_floor_reference = predictorFloor;

isNonideal = strcmp({metrics.expected_class},'nonideal');
nonidealPass = isfinite([metrics.rmse_e_rad]) & ...
    [metrics.rmse_e_rad] < cfg.gates.stage1.nonideal_rmse_max_e_rad;
checks.nonideal_rmse = any(isNonideal) && all(nonidealPass(isNonideal));
aggregate.nonideal_case_count = nnz(isNonideal);
aggregate.nonideal_failed_case_ids = ids(isNonideal & ~nonidealPass);

pairSpeeds = [5 10 20];
pairDiff = NaN(size(pairSpeeds));
for k = 1:numel(pairSpeeds)
    plusId = compose("speed_+%02dradps_m",pairSpeeds(k));
    minusId = compose("speed_-%02dradps_m",pairSpeeds(k));
    ip = find(ids==plusId,1);
    im = find(ids==minusId,1);
    if ~isempty(ip) && ~isempty(im)
        pairDiff(k) = abs(anglelut.wrap_to_pi( ...
            metrics(ip).mean_estimation_error_e_rad - ...
            metrics(im).mean_estimation_error_e_rad));
    end
end
aggregate.forward_reverse_difference_e_deg = rad2deg(pairDiff);
checks.forward_reverse_bias = all(isfinite(pairDiff)) && ...
    all(pairDiff < cfg.gates.stage1.forward_reverse_mean_difference_max_e_rad);

iv = find(ids=="voltage_ab_reconstructed",1);
checks.ideal_voltage_reconstruction = ~isempty(iv) && ...
    isfinite(metrics(iv).voltage_reconstruction_rms_V) && ...
    metrics(iv).voltage_reconstruction_rms_V < ...
    cfg.gates.stage1.ideal_voltage_reconstruction_rms_max_V;
aggregate.ideal_voltage_reconstruction_rms_V = ...
    local_field_or_nan(metrics,iv,'voltage_reconstruction_rms_V');

isPeriodic = strcmp({metrics.group},'periodic_error');
periodicCycles = [metrics.mechanical_cycles_evaluated];
periodicPass = isfinite(periodicCycles) & periodicCycles >= ...
    cfg.gates.stage1.periodic_minimum_mechanical_cycles;
checks.periodic_minimum_cycles = any(isPeriodic) && ...
    all(periodicPass(isPeriodic));
aggregate.periodic_case_count = nnz(isPeriodic);
aggregate.periodic_minimum_observed_mechanical_cycles = ...
    local_min_or_nan(periodicCycles(isPeriodic));
aggregate.periodic_failed_case_ids = ids(isPeriodic & ~periodicPass);

checks.minimum_valid_samples = all([metrics.valid_sample_count] > 0);
checks.case_matrix_identity = complete && ...
    isequal(ids,string({cases.case_id}));
end

function value = local_field_or_nan(s,index,field)
if isempty(index), value = NaN; else, value = s(index).(field); end
end

function value = local_min_or_nan(values)
values = double(values(:));
values = values(isfinite(values));
if isempty(values), value = NaN; else, value = min(values); end
end

function pass = local_all_checks_except(checks,ignored)
names = setdiff(fieldnames(checks),ignored,'stable');
pass = true;
for k = 1:numel(names)
    value = checks.(names{k});
    pass = pass && islogical(value) && isscalar(value) && value;
end
end

function out = local_metrics_template()
out = struct('case_id','', 'group','', 'expected_class','', ...
    'case_status','', 'stop_time_s',NaN, 'evaluation_start_s',NaN, ...
    'sample_count',0, 'evaluation_sample_count',0, ...
    'valid_sample_count',0, 'valid_fraction',NaN, ...
    'timestamp_valid_fraction',NaN, 'residual_ratio_valid_fraction',NaN, ...
    'rmse_e_rad',NaN, 'rmse_e_deg',NaN, 'rk2_rmse_e_rad',NaN, ...
    'heun_rmse_e_rad',NaN, 'predictor_disagreement_e_rad',NaN, ...
    'predictor_disagreement_e_deg',NaN, 'predictor_floor_e_rad',NaN, ...
    'predictor_floor_e_deg',NaN, 'mean_estimation_error_e_rad',NaN, ...
    'mean_estimation_error_e_deg',NaN, 'mean_estimate_e_rad',NaN, ...
    'mean_truth_error_e_rad',NaN, 'commanded_fixed_error_e_rad',NaN, ...
    'commanded_fixed_error_e_deg',NaN, 'residual_rms_A',NaN, ...
    'mean_residual_ratio',NaN, 'voltage_reconstruction_rms_V',NaN, ...
    'voltage_ab_independent_evaluation',false, ...
    'voltage_ab_selected_source','', 'voltage_ab_gate_source','', ...
    'voltage_ab_selected_branch_rmse_e_rad',NaN, ...
    'voltage_ab_selected_branch_rmse_e_deg',NaN, ...
    'voltage_ab_reconstructed_branch_rmse_e_rad',NaN, ...
    'voltage_ab_reconstructed_branch_rmse_e_deg',NaN, ...
    'voltage_ab_plant_evaluation_branch_rmse_e_rad',NaN, ...
    'voltage_ab_plant_evaluation_branch_rmse_e_deg',NaN, ...
    'voltage_ab_pseudo_angle_delta_rms_e_rad',NaN, ...
    'voltage_ab_pseudo_angle_delta_rms_e_deg',NaN, ...
    'voltage_ab_pseudo_angle_delta_mean_e_rad',NaN, ...
    'voltage_ab_pseudo_angle_delta_mean_e_deg',NaN, ...
    'voltage_ab_residual_delta_rms_A',NaN, ...
    'voltage_ab_voltage_delta_rms_V',NaN, ...
    'voltage_ab_branches_numerically_distinct',false, ...
    'mean_abs_speed_error_e_radps',NaN, 'mechanical_cycles_evaluated',NaN, ...
    'simulation_elapsed_s',NaN);
end

function out = local_normalize_metrics(in)
out = local_metrics_template();
names = fieldnames(out);
for k = 1:numel(names)
    if isfield(in,names{k}), out.(names{k}) = in.(names{k}); end
end
end

function out = local_case_result_template()
out = struct('case_id','', 'status','BLOCKED', 'elapsed_s',NaN, ...
    'result_path','', 'message','', 'voltage_ab_selected_source','', ...
    'voltage_ab_selected_branch_rmse_e_deg',NaN);
end

function info = local_critical_early_stop_template()
info = struct( ...
    'eligible',false, ...
    'evaluated',false, ...
    'triggered',false, ...
    'after_case_id','', ...
    'completed_case_count',0, ...
    'completed_metric_count',0, ...
    'remaining_case_count_at_evaluation',0, ...
    'unexecuted_case_count',0, ...
    'unexecuted_case_ids',strings(0,1), ...
    'checks',struct(), ...
    'aggregate',struct(), ...
    'reason','Not eligible or not yet evaluated.');
end

function local_write_case_artifacts(outDir,metrics,implementations)
metricsPath = fullfile(outDir,'metrics.csv');
if isempty(metrics)
    writetable(table(),metricsPath);
else
    metricsTable = struct2table(metrics,'AsArray',true);
    writetable(metricsTable,metricsPath);
end
write_json_file(fullfile(outDir,'case_implementation.json'),implementations);
end

function local_write_case_metric_json(caseRoot,metrics)
for k = 1:numel(metrics)
    caseDir = fullfile(caseRoot,char(metrics(k).case_id));
    if isfolder(caseDir)
        write_json_file(fullfile(caseDir,'metrics.json'),metrics(k));
    end
end
end

function local_ensure_tests_csv(outDir)
if ~isfile(fullfile(outDir,'tests.csv'))
    local_write_empty_tests_csv(outDir);
end
end

function local_write_empty_tests_csv(outDir)
t = table(strings(0,1), false(0,1), false(0,1), false(0,1), ...
    seconds(zeros(0,1)), ...
    'VariableNames',{'Name','Passed','Failed','Incomplete','Duration'});
writetable(t,fullfile(outDir,'tests.csv'));
end

function local_mkdir(path)
if ~isfolder(path), mkdir(path); end
end

function local_write_text(path,text)
fid = fopen(path,'w','n','UTF-8');
if fid < 0, error('anglelut:IO','Cannot write %s.',path); end
cleanup = onCleanup(@() fclose(fid));
fprintf(fid,'%s',text);
end

function text = local_iso_time()
value = datetime('now','TimeZone','local', ...
    'Format','yyyy-MM-dd''T''HH:mm:ss.SSSXXX');
text = char(value);
end

function out = ternary(condition,yesValue,noValue)
if condition, out = yesValue; else, out = noValue; end
end
