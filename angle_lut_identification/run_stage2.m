function result = run_stage2(options)
%RUN_STAGE2 Train Scheme 4 and execute the frozen Stage-2 acceptance matrix.
%   R2 = RUN_STAGE2() is the formal clean-session entry point.  Bounded
%   options are supported for diagnostics and always return BLOCKED.

if nargin < 1, options = struct(); end
options = local_options(options);
base = setup_project();
cfg = stage2_config();
cfg.project_root = base.project_root;
cfg.source_model = cfg.project.baseline_model;
cfg.harness_model = cfg.project.harness_model;
matrix = stage2_case_matrix(cfg);

runId = "stage2_" + string(datetime('now','Format','yyyyMMdd_HHmmss_SSS'));
outDir = fullfile(cfg.project_root,'results',char(runId),'stage2');
local_mkdir(outDir);
local_mkdir(fullfile(outDir,'failures'));
startedAt = local_iso_time();
result = local_result(runId,outDir);
profiles64 = repmat(local_profile_template(),0,1);
profiles128 = repmat(local_profile_template(),0,1);
frozenPairs = repmat(local_pair_template(),0,1);
drift = repmat(local_drift_template(),0,1);
testSummary = struct('passed',false,'count',0,'failed',0,'incomplete',0);
errors = strings(0,1);
stage1Info = struct();
sourceHashBefore = file_sha256(cfg.source_model);
stage1HashBefore = file_sha256(cfg.harness_model);
stage2HashBefore = "";
criticalStop = struct('triggered',false,'phase','','case_id','', ...
    'reason','');

configuration = struct('schema_version','angle-lut-stage2-run-config-v1', ...
    'run_id',char(runId),'config',cfg,'case_matrix',matrix, ...
    'options',options,'random_seed',cfg.stage2.random_seed);
write_json_file(fullfile(outDir,'configuration.json'),configuration);

try
    [stage1Info,stage1Ok,stage1Message] = local_stage1_prerequisite(cfg);
    if ~stage1Ok
        result.final_status = 'BLOCKED';
        errors(end+1) = string(stage1Message);
        criticalStop = local_stop(criticalStop,'prerequisite','',stage1Message);
        error('anglelut:Stage2Prerequisite','%s',stage1Message);
    end

    if options.rebuild_harness
        build_stage2_harness();
    end
    assert(isfile(cfg.project.stage2_harness_model), ...
        'anglelut:MissingStage2Harness','Stage-2 harness is missing.');
    stage2HashBefore = string(file_sha256(cfg.project.stage2_harness_model));
    assert(strcmpi(sourceHashBefore,file_sha256(cfg.source_model)), ...
        'anglelut:SourceHashChanged','Stage-2 builder changed the source model.');
    assert(strcmpi(stage1HashBefore,file_sha256(cfg.harness_model)), ...
        'anglelut:Stage1HarnessHashChanged', ...
        'Stage-2 builder changed the Stage-1 harness.');

    environment = collect_environment_manifest( ...
        cfg.project.stage2_harness_model,cfg.timing);
    write_json_file(fullfile(outDir,'environment_manifest.json'),environment);
    inventory = collect_file_inventory(cfg.project_root);
    writetable(inventory,fullfile(outDir,'file_inventory.csv'));
    write_json_file(fullfile(outDir,'file_inventory.json'), ...
        table2struct(inventory));

    [testsOk,testSummary] = local_run_tests(cfg,outDir,options.run_tests);
    if ~testsOk
        criticalStop = local_stop(criticalStop,'tests','', ...
            'One or more Stage-2 unit or structure tests failed.');
        error('anglelut:Stage2TestsFailed','Stage-2 tests failed.');
    end

    training = local_select_cases(matrix.training, ...
        options.training_case_ids,options.max_training_profiles);
    profileFreeze = local_select_cases(matrix.profile_freeze, ...
        string({training.case_id}),numel(training));
    validation = local_select_cases(matrix.validation, ...
        options.validation_case_ids,options.max_validation_cases);
    tracePaths = strings(numel(training),1);
    states64 = cell(numel(training),1);

    % Default M64 acquisition and streaming learning.
    for k = 1:numel(training)
        c = local_override_stop(training(k),options.stop_time_override_s);
        caseDir = fullfile(outDir,'training',char(c.case_id),'M64');
        local_mkdir(caseDir);
        write_json_file(fullfile(caseDir,'case_config.json'),c);
        try
            zero = zeros(cfg.stage2.runtime_nodes,1);
            [simOut,elapsed] = simulate_stage2_case(c,cfg,false,zero, ...
                options.simulation_mode);
            [~,trace,implementation] = analyze_stage1_case(simOut,c,cfg);
            [state,m,history,reference] = stream_scheme4_trace(trace,64,cfg);
            m = local_profile(m,c,elapsed,'M64');
            local_save_learning(caseDir,state,m,history,reference,trace, ...
                implementation,c,cfg);
            profiles64(end+1,1) = m; %#ok<AGROW>
            states64{k} = state;
            tracePaths(k) = fullfile(caseDir,'training_trace.mat');
            if options.stop_on_gate_failure
                [pass,reason] = local_profile_gate(m,c,cfg,true);
                if ~pass
                    criticalStop = local_stop(criticalStop,'M64_training', ...
                        char(c.case_id),reason);
                    break;
                end
            end
        catch exception
            local_write_exception(caseDir,exception);
            errors(end+1) = string(getReport(exception, ...
                'extended','hyperlinks','off')); %#ok<AGROW>
            criticalStop = local_stop(criticalStop,'M64_training', ...
                char(c.case_id),exception.message);
            break;
        end
    end

    % Every learned M64 waveform receives an independent frozen pair.
    if ~criticalStop.triggered
        for k = 1:numel(profileFreeze)
            c = local_override_stop(profileFreeze(k), ...
                options.stop_time_override_s);
            runtime = anglelut.resample_periodic_lut( ...
                states64{k}.active_lut_e_rad,cfg.stage2.runtime_nodes);
            pairDir = fullfile(outDir,'profile_freeze',char(c.case_id));
            pair = local_run_pair(c,cfg,runtime,pairDir,options);
            pair.profile_source_id = char(c.case_id);
            write_json_file(fullfile(pairDir,'pair_metrics.json'),pair);
            frozenPairs(end+1,1) = local_normalize_pair(pair); %#ok<AGROW>
            if options.stop_on_gate_failure
                [pass,reason] = local_pair_critical_gate(pair,c,cfg);
                if ~pass
                    criticalStop = local_stop(criticalStop, ...
                        'profile_freeze',char(c.case_id),reason);
                    break;
                end
            end
        end
    end

    % Pre-registered M128 scan replays the exact saved training streams.
    if ~criticalStop.triggered && numel(profiles64) == numel(training)
        for k = 1:numel(training)
            c = training(k);
            loaded = load(tracePaths(k),'trace');
            [state,m,history,reference] = stream_scheme4_trace( ...
                loaded.trace,128,cfg);
            m = local_profile(m,c,0,'M128_REPLAY');
            caseDir = fullfile(outDir,'training',char(c.case_id),'M128');
            local_mkdir(caseDir);
            local_save_learning(caseDir,state,m,history,reference, ...
                [],struct(),c,cfg);
            profiles128(end+1,1) = m; %#ok<AGROW>
            if options.stop_on_gate_failure
                [pass,reason] = local_profile_gate(m,c,cfg,false);
                if ~pass
                    criticalStop = local_stop(criticalStop,'M128_scan', ...
                        char(c.case_id),reason);
                    break;
                end
            end
        end
    end

    if ~criticalStop.triggered && numel(profiles128) == numel(training)
        primary64Index = find(string({profiles64.case_id}) == ...
            cfg.stage2.primary_profile_id,1);
        primary128Index = find(string({profiles128.case_id}) == ...
            cfg.stage2.primary_profile_id,1);
        if ~isempty(primary64Index) && ~isempty(primary128Index) && ...
                profiles128(primary128Index).active_rmse_e_rad > ...
                profiles64(primary64Index).active_rmse_e_rad + ...
                cfg.gates.stage2.m128_rmse_regression_max_e_rad
            criticalStop = local_stop(criticalStop,'M128_scan', ...
                char(cfg.stage2.primary_profile_id), ...
                'M128 primary LUT RMSE exceeds the M64 result by >0.25 deg_e.');
        end
    end

    primaryIndex = find(string({profiles64.case_id}) == ...
        cfg.stage2.primary_profile_id,1);
    if ~criticalStop.triggered && ~isempty(primaryIndex)
        primaryState = states64{primaryIndex};
        primaryRuntime = anglelut.resample_periodic_lut( ...
            primaryState.active_lut_e_rad,cfg.stage2.runtime_nodes);
        local_save_primary_luts(outDir,primaryState,primaryRuntime,cfg);

        drift = local_run_drift(stage1Info.path,primaryState,cfg,outDir);
        if options.stop_on_gate_failure && (~isempty(drift) && any( ...
                [drift.lut_drift_e_rad] >= ...
                cfg.gates.stage2.cross_condition_lut_drift_max_e_rad))
            criticalStop = local_stop(criticalStop,'condition_drift','', ...
                'At least one independent condition LUT drift is >= 0.5 deg_e.');
        end

        if ~criticalStop.triggered
            for k = 1:numel(validation)
                c = local_override_stop(validation(k), ...
                    options.stop_time_override_s);
                pairDir = fullfile(outDir,'frozen_validation',char(c.case_id));
                pair = local_run_pair(c,cfg,primaryRuntime,pairDir,options);
                pair.profile_source_id = char(cfg.stage2.primary_profile_id);
                write_json_file(fullfile(pairDir,'pair_metrics.json'),pair);
                frozenPairs(end+1,1) = local_normalize_pair(pair); %#ok<AGROW>
                if options.stop_on_gate_failure
                    [pass,reason] = local_pair_critical_gate(pair,c,cfg);
                    if ~pass
                        criticalStop = local_stop(criticalStop, ...
                            'frozen_validation',char(c.case_id),reason);
                        break;
                    end
                end
            end
        end
    elseif ~criticalStop.triggered && strcmp(options.mode,'full')
        criticalStop = local_stop(criticalStop,'primary_lut','', ...
            'The primary periodic_combined M64 LUT was not completed.');
    end

    complete = local_is_full_scope(options,matrix,profiles64,profiles128, ...
        frozenPairs,drift,criticalStop);
    [numericChecks,aggregate] = evaluate_stage2_acceptance( ...
        profiles64,profiles128,frozenPairs,drift,cfg,complete);
    checks = struct('stage1_prerequisite',stage1Ok, ...
        'unit_and_structure_tests',testSummary.passed, ...
        'source_hash_unchanged',strcmpi(sourceHashBefore, ...
        file_sha256(cfg.source_model)), ...
        'stage1_harness_hash_unchanged',strcmpi(stage1HashBefore, ...
        file_sha256(cfg.harness_model)), ...
        'learning_interface_truth_free',true, ...
        'stage3_stage4_disabled',~cfg.stage2.enable_stage3, ...
        'numeric',numericChecks);
    allChecks = stage1Ok && testSummary.passed && checks.source_hash_unchanged && ...
        checks.stage1_harness_hash_unchanged && numericChecks.all_mandatory;
    if complete && allChecks
        finalStatus = 'PASS';
    elseif complete || criticalStop.triggered
        finalStatus = 'FAIL';
    else
        finalStatus = 'BLOCKED';
    end
    result.final_status = finalStatus;
    result.training_results = profiles64;
    result.node_scan = profiles128;
    result.frozen_cases = frozenPairs;
    result.condition_drift = drift;
    gate = local_gate(finalStatus,complete,checks,aggregate,cfg, ...
        criticalStop,errors);
    local_write_outputs(outDir,result,gate,profiles64,profiles128, ...
        frozenPairs,drift);
catch exception
    if ~startsWith(string(exception.identifier),'anglelut:Stage2Prerequisite')
        errors(end+1) = string(getReport(exception,'extended','hyperlinks','off'));
    end
    local_write_text(fullfile(outDir,'failures','run_error.txt'), ...
        getReport(exception,'extended','hyperlinks','off'));
    if isempty(result.final_status) || strcmp(result.final_status,'BLOCKED') == false
        result.final_status = 'FAIL';
    end
    checks = struct('stage1_prerequisite',~isempty(fieldnames(stage1Info)), ...
        'unit_and_structure_tests',testSummary.passed, ...
        'source_hash_unchanged',strcmpi(sourceHashBefore, ...
        file_sha256(cfg.source_model)), ...
        'stage1_harness_hash_unchanged',strcmpi(stage1HashBefore, ...
        file_sha256(cfg.harness_model)));
    gate = local_gate(result.final_status,false,checks,struct(),cfg, ...
        criticalStop,errors);
    result.training_results = profiles64;
    result.node_scan = profiles128;
    result.frozen_cases = frozenPairs;
    result.condition_drift = drift;
    local_write_outputs(outDir,result,gate,profiles64,profiles128, ...
        frozenPairs,drift);
end

stage2HashAfter = string(file_sha256(cfg.project.stage2_harness_model));
manifest = struct('schema_version','angle-lut-stage2-manifest-v1', ...
    'run_id',char(runId),'started_at_utc',startedAt, ...
    'completed_at_utc',local_iso_time(),'final_status',result.final_status, ...
    'scope',local_scope(options),'random_seed',cfg.stage2.random_seed, ...
    'stage1_source',stage1Info,'source_model_sha256_before',sourceHashBefore, ...
    'source_model_sha256_after',file_sha256(cfg.source_model), ...
    'stage1_harness_sha256_before',stage1HashBefore, ...
    'stage1_harness_sha256_after',file_sha256(cfg.harness_model), ...
    'stage2_harness_sha256_before',char(stage2HashBefore), ...
    'stage2_harness_sha256_after',char(stage2HashAfter), ...
    'tests',testSummary,'critical_early_stop',criticalStop, ...
    'lut_learning_enabled',true,'control_compensation_frozen_during_validation',true, ...
    'stage3_executed',false,'stage4_executed',false, ...
    'result_path',outDir);
write_json_file(fullfile(outDir,'run_manifest.json'),manifest);
write_json_file(fullfile(outDir,'result.json'),result);

reportOk = true;
try
    generate_stage2_reports(outDir);
catch reportException
    reportOk = false;
    local_write_text(fullfile(outDir,'failures','report_error.txt'), ...
        getReport(reportException,'extended','hyperlinks','off'));
    if strcmp(result.final_status,'PASS')
        result.final_status = 'FAIL';
        write_json_file(fullfile(outDir,'result.json'),result);
        gate.status = 'FAIL';
    end
end
gate.checks.report_bundle_generated = reportOk;
gate.status = result.final_status;
manifest.final_status = result.final_status;
manifest.report_bundle_generated = reportOk;
write_json_file(fullfile(outDir,'gate.json'),gate);
write_json_file(fullfile(outDir,'result.json'),result);
write_json_file(fullfile(outDir,'run_manifest.json'),manifest);

pointer = fullfile(cfg.project_root,'results','latest_stage2.txt');
local_write_text(pointer,char(runId));
if bdIsLoaded('angle_lut_stage2_harness')
    close_system('angle_lut_stage2_harness',0);
end
end

function [pass,reason] = local_pair_critical_gate(pair,c,cfg)
g = cfg.gates.stage2;
className = string(pair.expected_class);
if className == "saturation_diagnostic"
    pass = isfinite(pair.active.compensation_max_abs_e_rad) && ...
        pair.active.compensation_max_abs_e_rad <= ...
        cfg.stage2.max_abs_lut_e_rad+100*eps;
elseif className == "ideal"
    [anglePass,basis,details] = control_angle_gate(pair,c,cfg);
    pair.control_angle_gate_basis = basis;
    pair.control_angle_gate_details = details;
    physical = [pair.id_rms_improvement, ...
        pair.prediction_residual_improvement,pair.torque_ripple_improvement];
    pass = anglePass && all(physical >= -g.ideal_per_case_regression_max) && ...
        pair.iq_tracking_change <= g.iq_tracking_regression_max && ...
        pair.mean_torque_change <= g.mean_torque_change_max;
else
    physical = [pair.id_rms_improvement, ...
        pair.prediction_residual_improvement,pair.torque_ripple_improvement];
    pass = pair.control_angle_improvement >= ...
        g.nonideal_control_angle_improvement_min && ...
        all(physical >= -g.nonideal_per_case_regression_max) && ...
        pair.iq_tracking_change <= g.iq_tracking_regression_max && ...
        pair.mean_torque_change <= g.mean_torque_change_max;
end
if pass, reason = ''; else
    reason = sprintf('A frozen critical per-case gate failed for %s.', ...
        pair.case_id);
end
end

function options = local_options(input)
defaults = struct('mode','full','rebuild_harness',true,'run_tests',true, ...
    'simulation_mode','rapid-accelerator','max_training_profiles',8, ...
    'max_validation_cases',24,'stop_time_override_s',[], ...
    'stop_on_gate_failure',true,'training_case_ids',strings(0,1), ...
    'validation_case_ids',strings(0,1));
options = defaults;
names = fieldnames(input);
for k = 1:numel(names)
    assert(isfield(defaults,names{k}),'anglelut:Stage2UnknownOption', ...
        'Unknown Stage-2 option %s.',names{k});
    options.(names{k}) = input.(names{k});
end
options.mode = char(validatestring(options.mode,{'full','bounded'}));
options.simulation_mode = char(validatestring(options.simulation_mode, ...
    {'normal','accelerator','rapid-accelerator'}));
validateattributes(options.max_training_profiles,{'numeric'}, ...
    {'scalar','integer','>=',1,'<=',8,'finite'});
validateattributes(options.max_validation_cases,{'numeric'}, ...
    {'scalar','integer','>=',0,'<=',24,'finite'});
if ~isempty(options.stop_time_override_s)
    validateattributes(options.stop_time_override_s,{'numeric'}, ...
        {'scalar','positive','finite'});
end
if strcmp(options.mode,'full')
    assert(options.max_training_profiles == 8 && ...
        options.max_validation_cases == 24 && ...
        isempty(options.stop_time_override_s) && options.run_tests, ...
        'anglelut:Stage2FullScopeOptions', ...
        'Full Stage 2 requires 8 training profiles, 24 validation cases, contractual stop times, and tests.');
end
options.training_case_ids = string(options.training_case_ids);
options.validation_case_ids = string(options.validation_case_ids);
end

function selected = local_select_cases(values,requested,maximum)
requested = string(requested);
if isempty(requested)
    selected = values(1:min(numel(values),maximum));
    return;
end
selected = values([]);
ids = string({values.case_id});
for k = 1:numel(requested)
    index = find(ids == requested(k),1);
    assert(~isempty(index),'anglelut:Stage2UnknownCase', ...
        'Unknown Stage-2 case %s.',requested(k));
    selected(end+1) = values(index); %#ok<AGROW>
end
assert(numel(selected) <= maximum,'anglelut:Stage2CaseLimit', ...
    'Requested cases exceed the configured maximum.');
end

function [info,ok,message] = local_stage1_prerequisite(cfg)
runId = char(cfg.stage2.prerequisite_stage1_run_id);
path = fullfile(cfg.project_root,'results',runId,'stage1');
gatePath = fullfile(path,'gate.json');
resultPath = fullfile(path,'result.json');
ok = false;
message = '';
info = struct('run_id',runId,'path',path,'gate_sha256','', ...
    'result_sha256','','status','');
if ~isfile(gatePath) || ~isfile(resultPath)
    message = sprintf('Required Stage-1 result %s is missing.',runId);
    return;
end
gate = jsondecode(fileread(gatePath));
stage1Result = jsondecode(fileread(resultPath));
info.gate_sha256 = file_sha256(gatePath);
info.result_sha256 = file_sha256(resultPath);
info.status = char(stage1Result.final_status);
ok = strcmp(gate.status,'PASS') && strcmp(gate.scope,'FULL_STAGE1') && ...
    strcmp(stage1Result.final_status,'PASS');
if ~ok
    message = sprintf('Required Stage-1 result %s is not a full PASS.',runId);
end
end

function [passed,summary] = local_run_tests(cfg,outDir,enabled)
if ~enabled
    writetable(table(string.empty(0,1),false(0,1),false(0,1), ...
        false(0,1),zeros(0,1),'VariableNames', ...
        {'Name','Passed','Failed','Incomplete','Duration'}), ...
        fullfile(outDir,'tests.csv'));
    passed = true;
    summary = struct('passed',false,'skipped',true,'count',0, ...
        'failed',0,'incomplete',0);
    return;
end
values = runtests(fullfile(cfg.project_root,'tests'), ...
    'IncludeSubfolders',true);
testTable = table(string({values.Name}).',logical([values.Passed].'), ...
    logical([values.Failed].'),logical([values.Incomplete].'), ...
    double([values.Duration].'),'VariableNames', ...
    {'Name','Passed','Failed','Incomplete','Duration'});
writetable(testTable,fullfile(outDir,'tests.csv'));
passed = all(testTable.Passed & ~testTable.Failed & ~testTable.Incomplete);
summary = struct('passed',passed,'count',height(testTable), ...
    'failed',nnz(testTable.Failed),'incomplete',nnz(testTable.Incomplete), ...
    'skipped',false);
end

function c = local_override_stop(c,value)
if ~isempty(value), c.stop_time_s = value; end
end

function m = local_profile(input,c,elapsed,phase)
m = local_profile_template();
names = fieldnames(input);
for k = 1:numel(names), m.(names{k}) = input.(names{k}); end
m.case_id = char(c.case_id);
m.phase = phase;
m.status = 'PASS';
m.elapsed_s = elapsed;
end

function [pass,reason] = local_profile_gate(m,c,cfg,isDefault)
g = cfg.gates.stage2;
pass = m.coverage_fraction >= 1 && m.all_nodes_valid && ...
    m.solver_relative_difference <= g.solver_relative_difference_max && ...
    m.normal_equation_relative_residual <= ...
    g.normal_equation_relative_residual_max && m.rcond >= g.rcond_min && ...
    m.amplitude_constraint_satisfied && m.monotonic_constraint_satisfied;
if isDefault
    pass = pass && m.solve_count >= g.solve_count_min && ...
        m.last_active_update_rms_e_rad <= ...
        g.final_active_update_rms_max_e_rad && ...
        m.previous_active_update_rms_e_rad <= ...
        g.final_active_update_rms_max_e_rad && ...
        m.active_rmse_e_rad <= g.active_lut_rmse_max_e_rad && ...
        m.active_max_error_e_rad <= g.active_lut_max_error_e_rad;
    if string(c.case_id) == "fixed_00deg_e"
        pass = pass && m.active_rmse_e_rad <= ...
            g.fixed_zero_lut_rmse_max_e_rad;
    else
        pass = pass && m.active_improvement_fraction >= ...
            g.nonzero_lut_improvement_min;
    end
    if string(c.case_id) == cfg.stage2.primary_profile_id
        pass = pass && m.shadow_rmse_e_rad <= ...
            g.shadow_lut_rmse_max_e_rad;
    end
end
if pass, reason = ''; else
    reason = sprintf('Pre-registered %s profile gate failed for %s.', ...
        m.phase,m.case_id);
end
end

function local_save_learning(dirPath,state,m,history,reference,trace, ...
        implementation,c,cfg)
write_json_file(fullfile(dirPath,'metrics.json'),m);
write_json_file(fullfile(dirPath,'state_snapshot.json'),state);
write_json_file(fullfile(dirPath,'case_config.json'),c);
if ~isempty(fieldnames(implementation))
    write_json_file(fullfile(dirPath,'implementation.json'),implementation);
end
node = (0:double(state.M)-1).';
lutTable = table(node,node*2*pi/double(state.M), ...
    state.shadow_lut_e_rad,state.active_lut_e_rad,reference.lut_e_rad, ...
    state.valid_mask,state.node_weight,state.node_hits, ...
    'VariableNames',{'node','phi_m_rad','shadow_e_rad','active_e_rad', ...
    'reference_e_rad','valid','node_weight','node_hits'});
writetable(lutTable,fullfile(dirPath,'lut_nodes.csv'));
runtimeLut = anglelut.resample_periodic_lut(state.active_lut_e_rad, ...
    cfg.stage2.runtime_nodes);
writetable(table((0:cfg.stage2.runtime_nodes-1).',runtimeLut, ...
    'VariableNames',{'node','active_e_rad'}), ...
    fullfile(dirPath,'runtime_lut_512.csv'));
save(fullfile(dirPath,'scheme4_state.mat'),'state','history','reference', ...
    'runtimeLut','-v7.3');
if ~isempty(trace)
    save(fullfile(dirPath,'training_trace.mat'),'trace','-v7.3');
end
end

function pair = local_run_pair(c,cfg,runtime,pairDir,options)
local_mkdir(pairDir);
write_json_file(fullfile(pairDir,'case_config.json'),c);
zero = zeros(cfg.stage2.runtime_nodes,1);
[offOut,offElapsed] = simulate_stage2_case(c,cfg,false,zero, ...
    options.simulation_mode);
[~,offStage1] = analyze_stage1_case(offOut,c,cfg);
[offMetrics,offTrace] = evaluate_stage2_frozen( ...
    offOut,offStage1,c,cfg,false);
offMetrics.elapsed_s = offElapsed;
local_save_frozen(fullfile(pairDir,'active_off'),offMetrics,offTrace, ...
    offStage1);

[onOut,onElapsed] = simulate_stage2_case(c,cfg,true,runtime, ...
    options.simulation_mode);
[~,onStage1] = analyze_stage1_case(onOut,c,cfg);
[onMetrics,onTrace] = evaluate_stage2_frozen( ...
    onOut,onStage1,c,cfg,true);
onMetrics.elapsed_s = onElapsed;
local_save_frozen(fullfile(pairDir,'active_on'),onMetrics,onTrace,onStage1);
pair = pair_stage2_metrics(offMetrics,onMetrics);
pair.profile_source_id = '';
[~,pair.control_angle_gate_basis,pair.control_angle_gate_details] = ...
    control_angle_gate(pair,c,cfg);
write_json_file(fullfile(pairDir,'pair_metrics.json'),pair);
end

function local_save_frozen(path,metrics,trace,stage1Trace)
local_mkdir(path);
write_json_file(fullfile(path,'metrics.json'),metrics);
save(fullfile(path,'trace.mat'),'trace','stage1Trace','-v7.3');
end

function drift = local_run_drift(stage1Path,primaryState,cfg,outDir)
ids = ["speed_-20radps_m","speed_-10radps_m","speed_-05radps_m", ...
    "speed_+05radps_m","speed_+10radps_m","speed_+20radps_m", ...
    "load_0Nm","load_2Nm"];
drift = repmat(local_drift_template(),0,1);
root = fullfile(outDir,'condition_drift');
local_mkdir(root);
for k = 1:numel(ids)
    path = fullfile(stage1Path,'cases',char(ids(k)),'trace.mat');
    assert(isfile(path),'anglelut:Stage2DriftTraceMissing', ...
        'Stage-1 drift trace is missing: %s',ids(k));
    loaded = load(path,'trace');
    [state,m,history,reference] = stream_scheme4_trace(loaded.trace,64,cfg);
    delta = anglelut.wrap_to_pi( ...
        state.shadow_lut_e_rad-primaryState.shadow_lut_e_rad);
    value = local_drift_template();
    value.case_id = char(ids(k));
    value.lut_drift_e_rad = sqrt(mean(delta.^2));
    value.lut_drift_e_deg = rad2deg(value.lut_drift_e_rad);
    value.coverage_fraction = m.coverage_fraction;
    value.solve_count = m.solve_count;
    drift(end+1,1) = value; %#ok<AGROW>
    caseDir = fullfile(root,char(ids(k)));
    local_mkdir(caseDir);
    write_json_file(fullfile(caseDir,'metrics.json'),value);
    save(fullfile(caseDir,'state.mat'),'state','history','reference','-v7.3');
end
writetable(struct2table(drift),fullfile(root,'metrics.csv'));
end

function local_save_primary_luts(outDir,state,runtime,cfg)
path = fullfile(outDir,'luts');
local_mkdir(path);
node = (0:double(state.M)-1).';
writetable(table(node,state.shadow_lut_e_rad,state.active_lut_e_rad, ...
    'VariableNames',{'node','shadow_e_rad','active_e_rad'}), ...
    fullfile(path,'primary_m64_lut.csv'));
writetable(table((0:cfg.stage2.runtime_nodes-1).',runtime, ...
    'VariableNames',{'node','active_e_rad'}), ...
    fullfile(path,'primary_runtime_lut_512.csv'));
save(fullfile(path,'primary_luts.mat'),'state','runtime','-v7.3');
end

function complete = local_is_full_scope(options,matrix,p64,p128,pairs,drift,stop)
complete = strcmp(options.mode,'full') && ~stop.triggered && ...
    numel(p64) == numel(matrix.training) && ...
    numel(p128) == numel(matrix.training) && ...
    numel(pairs) == numel(matrix.profile_freeze)+numel(matrix.validation) && ...
    numel(drift) == 8;
end

function gate = local_gate(status,complete,checks,aggregate,cfg,stop,errors)
gate = struct('status',status,'scope',ternary(complete,'FULL_STAGE2', ...
    'BOUNDED_OR_PARTIAL_STAGE2'),'checks',checks, ...
    'thresholds',cfg.gates.stage2,'aggregate',aggregate, ...
    'critical_early_stop',stop,'errors',{cellstr(errors)});
end

function local_write_outputs(outDir,result,gate,p64,p128,pairs,drift)
write_json_file(fullfile(outDir,'gate.json'),gate);
write_json_file(fullfile(outDir,'result.json'),result);
rows = repmat(local_metric_row(),0,1);
for k = 1:numel(p64), rows(end+1,1) = local_profile_row(p64(k)); end %#ok<AGROW>
for k = 1:numel(p128), rows(end+1,1) = local_profile_row(p128(k)); end %#ok<AGROW>
for k = 1:numel(pairs), rows(end+1,1) = local_pair_row(pairs(k)); end %#ok<AGROW>
for k = 1:numel(drift), rows(end+1,1) = local_drift_row(drift(k)); end %#ok<AGROW>
if isempty(rows), rows = local_metric_row(); rows(1) = []; end
writetable(struct2table(rows),fullfile(outDir,'metrics.csv'));
if isfield(gate,'checks')
    failed = local_failed_checks(gate.checks,'');
else
    failed = strings(0,1);
end
local_write_text(fullfile(outDir,'failures','gate_failures.txt'), ...
    strjoin(failed,newline));
write_json_file(fullfile(outDir,'failures','gate_failures.json'), ...
    struct('failed_checks',{cellstr(failed)}));
end

function names = local_failed_checks(value,prefix)
names = strings(0,1);
if ~isstruct(value), return; end
fields = fieldnames(value);
for k = 1:numel(fields)
    name = string(fields{k});
    full = name;
    if strlength(prefix) > 0, full = prefix+"."+name; end
    item = value.(fields{k});
    if isstruct(item)
        names = [names; local_failed_checks(item,full)]; %#ok<AGROW>
    elseif islogical(item) && isscalar(item) && ~item
        names(end+1,1) = full; %#ok<AGROW>
    end
end
end

function out = local_profile_template()
out = struct('phase','','case_id','','status','','elapsed_s',NaN, ...
    'nodes',NaN,'sample_count',NaN,'accepted_count',NaN, ...
    'effective_weight',NaN,'coverage_fraction',NaN, ...
    'reference_coverage_fraction',NaN,'solve_count',NaN, ...
    'total_abs_travel_m_rad',NaN,'mechanical_revolutions',NaN, ...
    'shadow_rmse_e_rad',NaN,'shadow_rmse_e_deg',NaN, ...
    'active_rmse_e_rad',NaN,'active_rmse_e_deg',NaN, ...
    'baseline_rmse_e_rad',NaN,'baseline_rmse_e_deg',NaN, ...
    'active_max_error_e_rad',NaN,'active_max_error_e_deg',NaN, ...
    'active_improvement_fraction',NaN, ...
    'last_active_update_rms_e_rad',NaN, ...
    'previous_active_update_rms_e_rad',NaN, ...
    'solver_relative_difference',NaN, ...
    'normal_equation_relative_residual',NaN,'rcond',NaN, ...
    'active_max_abs_e_rad',NaN,'minimum_monotonic_margin',NaN, ...
    'all_nodes_valid',false,'amplitude_constraint_satisfied',false, ...
    'monotonic_constraint_satisfied',false);
end

function out = local_pair_template()
blank = struct('case_id','','active_enable',false,'expected_class','', ...
    'sample_count',NaN,'control_angle_rmse_e_rad',NaN, ...
    'control_angle_rmse_e_deg',NaN,'id_rms_A',NaN, ...
    'iq_tracking_rmse_A',NaN,'prediction_residual_rms_A',NaN, ...
    'mean_torque_Nm',NaN,'torque_ripple_rms_Nm',NaN, ...
    'compensation_rms_e_rad',NaN,'compensation_max_abs_e_rad',NaN, ...
    'elapsed_s',NaN);
out = struct('case_id','','expected_class','','baseline',blank, ...
    'active',blank,'control_angle_improvement',NaN, ...
    'id_rms_improvement',NaN,'prediction_residual_improvement',NaN, ...
    'torque_ripple_improvement',NaN,'iq_tracking_change',NaN, ...
    'mean_torque_change',NaN,'profile_source_id','', ...
    'control_angle_gate_basis','', ...
    'control_angle_gate_details',struct());
end

function out = local_normalize_pair(input)
out = local_pair_template();
names = fieldnames(input);
for k = 1:numel(names), out.(names{k}) = input.(names{k}); end
end

function out = local_drift_template()
out = struct('case_id','','lut_drift_e_rad',NaN,'lut_drift_e_deg',NaN, ...
    'coverage_fraction',NaN,'solve_count',NaN);
end

function out = local_metric_row()
out = struct('phase','','case_id','','expected_class','', ...
    'control_angle_gate_basis','', ...
    'nodes',NaN,'elapsed_s',NaN,'coverage_fraction',NaN, ...
    'solve_count',NaN,'solver_relative_difference',NaN, ...
    'normal_equation_relative_residual',NaN,'rcond',NaN, ...
    'shadow_rmse_e_deg',NaN,'active_rmse_e_deg',NaN, ...
    'active_max_error_e_deg',NaN,'lut_improvement_fraction',NaN, ...
    'control_angle_improvement',NaN,'id_rms_improvement',NaN, ...
    'prediction_residual_improvement',NaN, ...
    'torque_ripple_improvement',NaN,'iq_tracking_change',NaN, ...
    'mean_torque_change',NaN,'lut_drift_e_deg',NaN);
end

function row = local_profile_row(m)
row = local_metric_row();
row.phase = m.phase; row.case_id = m.case_id; row.nodes = m.nodes;
row.elapsed_s = m.elapsed_s; row.coverage_fraction = m.coverage_fraction;
row.solve_count = m.solve_count;
row.solver_relative_difference = m.solver_relative_difference;
row.normal_equation_relative_residual = ...
    m.normal_equation_relative_residual;
row.rcond = m.rcond; row.shadow_rmse_e_deg = m.shadow_rmse_e_deg;
row.active_rmse_e_deg = m.active_rmse_e_deg;
row.active_max_error_e_deg = m.active_max_error_e_deg;
row.lut_improvement_fraction = m.active_improvement_fraction;
end

function row = local_pair_row(p)
row = local_metric_row(); row.phase = 'FROZEN_PAIR';
row.case_id = p.case_id; row.expected_class = p.expected_class;
row.control_angle_gate_basis = p.control_angle_gate_basis;
row.elapsed_s = p.baseline.elapsed_s+p.active.elapsed_s;
row.control_angle_improvement = p.control_angle_improvement;
row.id_rms_improvement = p.id_rms_improvement;
row.prediction_residual_improvement = p.prediction_residual_improvement;
row.torque_ripple_improvement = p.torque_ripple_improvement;
row.iq_tracking_change = p.iq_tracking_change;
row.mean_torque_change = p.mean_torque_change;
end

function row = local_drift_row(d)
row = local_metric_row(); row.phase = 'CONDITION_DRIFT';
row.case_id = d.case_id; row.coverage_fraction = d.coverage_fraction;
row.solve_count = d.solve_count; row.lut_drift_e_deg = d.lut_drift_e_deg;
end

function out = local_result(runId,outDir)
out = struct('run_id',char(runId),'final_status','', ...
    'training_results',repmat(local_profile_template(),0,1), ...
    'frozen_cases',repmat(local_pair_template(),0,1), ...
    'node_scan',repmat(local_profile_template(),0,1), ...
    'condition_drift',repmat(local_drift_template(),0,1), ...
    'result_path',outDir);
end

function stop = local_stop(stop,phase,caseId,reason)
if ~stop.triggered
    stop.triggered = true; stop.phase = phase; stop.case_id = caseId;
    stop.reason = reason;
end
end

function local_write_exception(path,exception)
local_mkdir(path);
local_write_text(fullfile(path,'failure.txt'), ...
    getReport(exception,'extended','hyperlinks','off'));
end

function value = local_scope(options)
value = ternary(strcmp(options.mode,'full'),'FULL_STAGE2', ...
    'BOUNDED_OR_PARTIAL_STAGE2');
end

function local_mkdir(path)
if ~isfolder(path), mkdir(path); end
end

function local_write_text(path,value)
fid = fopen(path,'w','n','UTF-8');
assert(fid >= 0,'anglelut:IO','Cannot open %s.',path);
cleanup = onCleanup(@()fclose(fid));
fprintf(fid,'%s\n',value);
end

function value = local_iso_time()
time = datetime('now','TimeZone','UTC', ...
    'Format','yyyy-MM-dd''T''HH:mm:ss.SSS''Z''');
value = char(time);
end

function value = ternary(condition,yesValue,noValue)
if condition, value = yesValue; else, value = noValue; end
end
