function result = run_stage4(varargin)
%RUN_STAGE4 Execute the auditable Scheme-2 zero/high-noise diagnostic.
%   R4 = RUN_STAGE4('Scope','NOISE_DIAGNOSTIC') runs the pre-registered
%   2-by-2 learning/frozen comparison.  Because the immutable formal
%   Stage-3 result is FAIL, this entry always returns final_status BLOCKED.

options = local_options(varargin{:});
base = setup_project();
cfg = stage4_config();
cfg.project_root = base.project_root;
cfg.source_model = cfg.project.baseline_model;
cfg.harness_model = cfg.project.harness_model;
matrix = stage4_noise_case_matrix(cfg);

runId = "stage4_noise_" + string(datetime('now', ...
    'Format','yyyyMMdd_HHmmss_SSS'));
outDir = fullfile(cfg.project_root,'results','stage4_diagnostics', ...
    char(runId),'stage4');
local_mkdir(outDir); local_mkdir(fullfile(outDir,'failures'));
started = local_iso_time();
result = local_result(runId,outDir);
errors = strings(0,1);
stage3Info = local_stage3_prerequisite(cfg);
stage2Info = local_stage2_prerequisite(cfg);
testSummary = struct('passed',false,'count',0,'failed',0, ...
    'incomplete',0,'skipped',false);
trainingResults = repmat(local_training_template(),0,1);
nodeScanResults = repmat(local_training_template(),0,1);
sweepResults = repmat(local_sweep_template(),0,1);
frozenMatrix = repmat(local_pair_template(),0,1);
schemeComparisons = repmat(local_comparison_template(),0,1);
trainingHistories = repmat(local_history_template(),0,1);
noiseRealization = struct();
diagnosticChecks = struct('all_mandatory',false);
states = cell(2,1); runtimes = cell(2,1); traces = cell(2,1);
references = cell(2,1); histories = cell(2,1);

sourceHash = file_sha256(cfg.source_model);
stage1Hash = file_sha256(cfg.harness_model);
stage2Hash = file_sha256(cfg.project.stage2_harness_model);
stage3Hash = file_sha256(cfg.project.stage3_harness_model);
stage4Hash = "";
configuration = struct('schema_version','stage4-noise-diagnostic-config-v1', ...
    'run_id',char(runId),'scope',options.scope,'config',cfg, ...
    'case_matrix',matrix,'options',options, ...
    'formal_stage3_prerequisite_satisfied',stage3Info.satisfied, ...
    'random_seed',cfg.stage4.random_seed);
write_json_file(fullfile(outDir,'configuration.json'),configuration);

try
    assert(stage2Info.satisfied,'anglelut:Stage4Stage2Prerequisite', ...
        'A passed FULL_STAGE2 result is required for this diagnostic.');
    if options.rebuild_harness, build_stage4_harness(); end
    assert(isfile(cfg.project.stage4_harness_model), ...
        'anglelut:MissingStage4Harness','The Stage-4 harness is missing.');
    stage4Hash = string(file_sha256(cfg.project.stage4_harness_model));
    local_assert_passed_hashes(cfg,sourceHash,stage1Hash,stage2Hash,stage3Hash);

    environment = collect_environment_manifest( ...
        cfg.project.stage4_harness_model,cfg.timing);
    write_json_file(fullfile(outDir,'environment_manifest.json'),environment);
    inventory = collect_file_inventory(cfg.project_root);
    writetable(inventory,fullfile(outDir,'file_inventory.csv'));
    write_json_file(fullfile(outDir,'file_inventory.json'),table2struct(inventory));
    [testsOk,testSummary] = local_run_tests(cfg,outDir,options.run_tests);
    assert(testsOk,'anglelut:Stage4TestsFailed', ...
        'One or more Stage-4 unit or structure tests failed.');

    % Acquire two fresh, otherwise identical ten-cycle streams.
    for k = 1:2
        c = matrix.training(k); condition = matrix.training_condition(k);
        caseDir = fullfile(outDir,'training',char(condition));
        local_mkdir(caseDir); write_json_file( ...
            fullfile(caseDir,'case_config.json'),c);
        zeroLut = zeros(cfg.stage4.runtime_nodes,1);
        [simOut,elapsed] = simulate_stage2_case(c,cfg,false,zeroLut, ...
            options.simulation_mode,'angle_lut_stage4_harness');
        [~,trace,implementation] = analyze_stage1_case(simOut,c,cfg);
        [state,m,history,reference,runtime] = stream_scheme2_trace( ...
            trace,cfg.stage4.default_nodes,cfg,'atan2');
        m = local_complete_training(m,c,condition,'M64_ATAN2',elapsed);
        history = local_enrich_history(history,reference,condition);
        local_save_training(caseDir,state,m,history,reference,runtime, ...
            trace,implementation,c,cfg);
        states{k}=state; runtimes{k}=runtime; traces{k}=trace;
        references{k}=reference; histories{k}=history;
        trainingResults(end+1,1)=local_normalize_training(m); %#ok<AGROW>
        trainingHistories(end+1,1)=local_normalize_history(history); %#ok<AGROW>
    end

    noiseRealization = local_noise_realization(traces{1},traces{2},cfg);
    write_json_file(fullfile(outDir,'noise_realization.json'),noiseRealization);

    % M128 uses the exact same saved streams.
    for k = 1:2
        condition=matrix.training_condition(k);
        [state,m,history,reference,runtime]=stream_scheme2_trace( ...
            traces{k},128,cfg,'atan2');
        m=local_complete_training(m,matrix.training(k),condition, ...
            'M128_ATAN2_REPLAY',0);
        history=local_enrich_history(history,reference,condition);
        caseDir=fullfile(outDir,'node_scan',char(condition),'M128');
        local_save_training(caseDir,state,m,history,reference,runtime, ...
            [],struct(),matrix.training(k),cfg);
        nodeScanResults(end+1,1)=local_normalize_training(m); %#ok<AGROW>
    end

    [newSweeps,sweepStates] = local_run_sweeps( ...
        traces,matrix.training_condition,cfg);
    sweepResults=[sweepResults;newSweeps];
    writetable(struct2table(local_sweep_rows(sweepResults)), ...
        fullfile(outDir,'sweeps.csv'));
    write_json_file(fullfile(outDir,'sweeps.json'),sweepResults);
    save(fullfile(outDir,'sweep_states.mat'),'sweepStates','-v7.3');

    schemeComparisons = local_scheme_comparisons( ...
        traces,matrix.training_condition,states,cfg);
    write_json_file(fullfile(outDir,'scheme_comparison.json'),schemeComparisons);
    writetable(struct2table(schemeComparisons), ...
        fullfile(outDir,'scheme_comparison.csv'));

    [newPairs,~] = local_run_frozen_matrix( ...
        matrix,runtimes,cfg,outDir,options);
    frozenMatrix=[frozenMatrix;newPairs];
    write_json_file(fullfile(outDir,'frozen_matrix.json'),frozenMatrix);
    writetable(struct2table(local_pair_rows(frozenMatrix)), ...
        fullfile(outDir,'frozen_matrix.csv'));

    diagnosticChecks = local_diagnostic_checks(trainingResults, ...
        nodeScanResults,sweepResults,frozenMatrix,noiseRealization,states,cfg);
    if diagnosticChecks.all_mandatory
        result.diagnostic_outcome='PASS';
    else
        result.diagnostic_outcome='FAIL';
        local_write_gate_failures(outDir,diagnosticChecks);
    end
catch exception
    errors(end+1)=string(getReport(exception,'extended','hyperlinks','off'));
    result.diagnostic_outcome='FAIL';
    local_write_text(fullfile(outDir,'failures','run_error.txt'), ...
        getReport(exception,'extended','hyperlinks','off'));
end

% A failed formal Stage 3 is an immutable protocol blocker for this scope.
result.final_status='BLOCKED';
result.prerequisite_stage3=stage3Info;
result.prerequisite_stage2=stage2Info;
result.training_results=trainingResults;
result.node_scan=nodeScanResults;
result.sweep_results=sweepResults;
result.scheme_comparison=schemeComparisons;
result.frozen_matrix=frozenMatrix;
result.noise_realization=noiseRealization;
result.diagnostic_checks=diagnosticChecks;
result.result_path=outDir;
gate=local_gate(result,stage3Info,testSummary,errors,cfg);
local_write_core_outputs(outDir,result,gate,trainingResults, ...
    nodeScanResults,frozenMatrix,sweepResults);

stage4HashAfter = "";
if isfile(cfg.project.stage4_harness_model)
    stage4HashAfter = string(file_sha256(cfg.project.stage4_harness_model));
end
manifest=struct('schema_version','stage4-noise-diagnostic-manifest-v1', ...
    'run_id',char(runId),'started_at_utc',started, ...
    'completed_at_utc',local_iso_time(),'scope','NOISE_DIAGNOSTIC', ...
    'final_status','BLOCKED','diagnostic_outcome',result.diagnostic_outcome, ...
    'formal_stage3_prerequisite_satisfied',stage3Info.satisfied, ...
    'prerequisite_stage3',stage3Info,'prerequisite_stage2',stage2Info, ...
    'random_seed',cfg.stage4.random_seed, ...
    'source_model_sha256_before',sourceHash, ...
    'source_model_sha256_after',file_sha256(cfg.source_model), ...
    'stage1_harness_sha256_before',stage1Hash, ...
    'stage1_harness_sha256_after',file_sha256(cfg.harness_model), ...
    'stage2_harness_sha256_before',stage2Hash, ...
    'stage2_harness_sha256_after',file_sha256(cfg.project.stage2_harness_model), ...
    'stage3_harness_sha256_before',stage3Hash, ...
    'stage3_harness_sha256_after',file_sha256(cfg.project.stage3_harness_model), ...
    'stage4_harness_sha256_before',char(stage4Hash), ...
    'stage4_harness_sha256_after',char(stage4HashAfter), ...
    'stage4_harness_sha256',char(stage4HashAfter),'tests',testSummary, ...
    'truth_feedback_used',false,'history_stored_inside_algorithm',false, ...
    'formal_latest_stage4_updated',false,'result_path',outDir);
write_json_file(fullfile(outDir,'run_manifest.json'),manifest);

reportOk=true;
try
    generate_stage4_reports(result,trainingHistories,sweepResults, ...
        frozenMatrix,schemeComparisons,fullfile(outDir,'reports'));
catch reportException
    reportOk=false;
    local_write_text(fullfile(outDir,'failures','report_error.txt'), ...
        getReport(reportException,'extended','hyperlinks','off'));
end
gate.checks.report_bundle_generated=reportOk;
gate.status='BLOCKED'; manifest.report_bundle_generated=reportOk;
write_json_file(fullfile(outDir,'gate.json'),gate);
write_json_file(fullfile(outDir,'result.json'),result);
write_json_file(fullfile(outDir,'run_manifest.json'),manifest);
pointer=fullfile(cfg.project_root,'results','latest_stage4_diagnostic.txt');
local_write_text(pointer,char(runId));
local_assert_passed_hashes(cfg,sourceHash,stage1Hash,stage2Hash,stage3Hash);
if bdIsLoaded('angle_lut_stage4_harness')
    close_system('angle_lut_stage4_harness',0);
end
end

function options=local_options(varargin)
options=struct('scope','NOISE_DIAGNOSTIC','rebuild_harness',true, ...
    'run_tests',true,'simulation_mode','rapid-accelerator');
if isscalar(varargin) && isstruct(varargin{1})
    input=varargin{1}; names=fieldnames(input);
    for k=1:numel(names)
        key=lower(names{k}); assert(isfield(options,key), ...
            'anglelut:Stage4UnknownOption','Unknown Stage-4 option %s.',names{k});
        options.(key)=input.(names{k});
    end
elseif ~isempty(varargin)
    assert(mod(numel(varargin),2)==0,'anglelut:Stage4NameValue', ...
        'Stage-4 options must be name/value pairs.');
    for k=1:2:numel(varargin)
        key=lower(char(string(varargin{k})));
        assert(isfield(options,key),'anglelut:Stage4UnknownOption', ...
            'Unknown Stage-4 option %s.',key);
        options.(key)=varargin{k+1};
    end
end
options.scope=upper(char(string(options.scope)));
assert(strcmp(options.scope,'NOISE_DIAGNOSTIC'), ...
    'anglelut:Stage4FormalBlocked', ...
    'Only NOISE_DIAGNOSTIC is available while formal Stage 3 is FAIL.');
options.simulation_mode=char(validatestring(options.simulation_mode, ...
    {'normal','accelerator','rapid-accelerator'}));
options.rebuild_harness=logical(options.rebuild_harness);
options.run_tests=logical(options.run_tests);
end

function info=local_stage3_prerequisite(cfg)
pointer=fullfile(cfg.project_root,'results','latest_stage3.txt');
info=struct('run_id','','path','','status','','scope','', ...
    'gate_sha256','','result_sha256','','satisfied',false, ...
    'critical_early_stop',struct(),'policy', ...
    'Immutable FAIL is retained; diagnostic execution cannot become formal PASS.');
if ~isfile(pointer), return; end
runId=strtrim(fileread(pointer)); path=fullfile(cfg.project_root,'results',runId,'stage3');
gatePath=fullfile(path,'gate.json'); resultPath=fullfile(path,'result.json');
info.run_id=runId; info.path=path;
if ~isfile(gatePath) || ~isfile(resultPath), return; end
g=jsondecode(fileread(gatePath)); r=jsondecode(fileread(resultPath));
info.status=char(r.final_status); info.scope=char(g.scope);
info.gate_sha256=file_sha256(gatePath); info.result_sha256=file_sha256(resultPath);
if isfield(g,'critical_early_stop'), info.critical_early_stop=g.critical_early_stop; end
info.satisfied=strcmp(g.status,'PASS') && strcmp(g.scope,'FULL_STAGE3') && ...
    strcmp(r.final_status,'PASS');
end

function info=local_stage2_prerequisite(cfg)
pointer=fullfile(cfg.project_root,'results','latest_stage2.txt');
info=struct('run_id','','path','','status','','scope','', ...
    'gate_sha256','','result_sha256','','satisfied',false);
if ~isfile(pointer), return; end
runId=strtrim(fileread(pointer)); path=fullfile(cfg.project_root,'results',runId,'stage2');
gatePath=fullfile(path,'gate.json'); resultPath=fullfile(path,'result.json');
info.run_id=runId; info.path=path;
if ~isfile(gatePath) || ~isfile(resultPath), return; end
g=jsondecode(fileread(gatePath)); r=jsondecode(fileread(resultPath));
info.status=char(r.final_status); info.scope=char(g.scope);
info.gate_sha256=file_sha256(gatePath); info.result_sha256=file_sha256(resultPath);
info.satisfied=strcmp(g.status,'PASS') && strcmp(g.scope,'FULL_STAGE2') && ...
    strcmp(r.final_status,'PASS');
end

function [ok,summary]=local_run_tests(cfg,outDir,enabled)
if ~enabled
    tableOut=table("stage4_tests",false,false,true, ...
        'VariableNames',{'Name','Passed','Failed','Incomplete'});
    writetable(tableOut,fullfile(outDir,'tests.csv'));
    ok=false; summary=struct('passed',false,'count',0,'failed',0, ...
        'incomplete',1,'skipped',true); return;
end
results=runtests(fullfile(cfg.project_root,'tests'),'IncludeSubfolders',true);
names=string({results.Name}).'; passed=logical([results.Passed]).';
failed=logical([results.Failed]).'; incomplete=logical([results.Incomplete]).';
tableOut=table(names,passed,failed,incomplete, ...
    'VariableNames',{'Name','Passed','Failed','Incomplete'});
writetable(tableOut,fullfile(outDir,'tests.csv'));
ok=all(passed & ~failed & ~incomplete);
summary=struct('passed',ok,'count',numel(results),'failed',nnz(failed), ...
    'incomplete',nnz(incomplete),'skipped',false);
end

function m=local_complete_training(m,c,condition,phase,elapsed)
m.case_id=char(c.case_id); m.condition=char(condition); m.phase=phase;
m.status='PASS'; m.elapsed_s=elapsed;
end

function h=local_enrich_history(h,reference,condition)
h.condition=char(condition); h.reference_lut_e_rad=reference.lut_e_rad(:);
rows=size(h.active_lut_e_rad,1); h.active_rmse_e_deg=NaN(rows,1);
h.shadow_rmse_e_deg=NaN(rows,1);
mask=reference.valid_mask(:);
for k=1:rows
    ae=anglelut.wrap_to_pi(h.active_lut_e_rad(k,:).'-reference.lut_e_rad(:));
    se=anglelut.wrap_to_pi(h.shadow_lut_e_rad(k,:).'-reference.lut_e_rad(:));
    h.active_rmse_e_deg(k)=rad2deg(sqrt(mean(ae(mask).^2)));
    h.shadow_rmse_e_deg(k)=rad2deg(sqrt(mean(se(mask).^2)));
end
if isfield(h,'travel_m_rad')
    h.mechanical_cycles=h.travel_m_rad/(2*pi);
elseif isfield(h,'fusion_travel_m_rad')
    h.travel_m_rad=h.fusion_travel_m_rad;
    h.mechanical_cycles=h.travel_m_rad/(2*pi);
end
if isfield(h,'fusion_time_s'), h.time_s=h.fusion_time_s; end
end

function stats=local_noise_realization(zeroTrace,noisyTrace,cfg)
z=double(zeroTrace.IdentificationBus.iabc_A);
n=double(noisyTrace.IdentificationBus.iabc_A);
count=min(size(z,1),size(n,1)); z=z(1:count,:); n=n(1:count,:);
noise=n-z; finite=all(isfinite(noise),2); noise=noise(finite,:);
stats=struct('distribution','independent zero-mean Gaussian', ...
    'requested_95_percent_half_width_A',cfg.stage4.noise_95_half_width_A, ...
    'sigma_A',cfg.stage4.noise_sigma_A,'random_seed',cfg.stage4.random_seed, ...
    'injection_point','post-ADC-quantizer identification measurement', ...
    'adc_quantization_enabled_in_both_conditions',true, ...
    'adc_current_lsb_A',cfg.stage4.adc_current_lsb_A, ...
    'sample_count_per_phase',size(noise,1),'mean_A',mean(noise,1), ...
    'std_A',std(noise,0,1),'rms_A',sqrt(mean(noise.^2,1)), ...
    'max_abs_A',max(abs(noise),[],1), ...
    'fraction_within_requested_band',mean(abs(noise(:)) <= ...
    cfg.stage4.noise_95_half_width_A));
stats.percent_within_requested_band=100*stats.fraction_within_requested_band;
stats.noise_samples_reconstructed_by_paired_subtraction=true;
end

function [rows,states]=local_run_sweeps(traces,conditions,cfg)
rows=repmat(local_sweep_template(),0,1); states=cell(0,1);
families={"mu2",cfg.stage4.sweep_mu2; ...
    "epsilon2",cfg.stage4.sweep_epsilon2; ...
    "decimation",cfg.stage4.sweep_update_decimation; ...
    "smoothing",cfg.stage4.sweep_smoothing_strength; ...
    "gamma",cfg.stage4.sweep_gamma};
for cidx=1:2
    for f=1:size(families,1)
        values=double(families{f,2});
        for v=values
            localCfg=cfg; name=string(families{f,1});
            if name=="mu2", localCfg.stage4.mu2=v;
            elseif name=="epsilon2", localCfg.stage4.epsilon2=v;
            elseif name=="decimation", localCfg.stage4.update_decimation=round(v);
            elseif name=="smoothing", localCfg.stage4.smoothing_strength=v;
            else
                localCfg.stage4.gamma=v; localCfg.stage2.gamma=v;
            end
            [state,m]=stream_scheme2_trace(traces{cidx},64,localCfg,'atan2');
            r=local_sweep_template(); r.sweep_family=char(name);
            r.setting=sprintf('%.17g',v); r.value=v;
            r.condition=char(conditions(cidx)); r.nodes=64; r.mode='atan2';
            r.active_rmse_e_deg=m.active_rmse_e_deg;
            r.shadow_rmse_e_deg=m.shadow_rmse_e_deg;
            r.active_max_error_e_deg=m.active_max_error_e_deg;
            r.fusion_count=m.fusion_count; r.coverage_fraction=m.coverage_fraction;
            r.finite=all(isfinite(state.active_lut_e_rad));
            r.active_lut_e_rad=state.active_lut_e_rad(:).';
            rows(end+1,1)=r; states{end+1,1}=state; %#ok<AGROW>
        end
    end
    [state,m]=stream_scheme2_trace(traces{cidx},128,cfg,'atan2');
    r=local_sweep_template(); r.sweep_family='nodes'; r.setting='128';
    r.value=128; r.condition=char(conditions(cidx)); r.nodes=128;
    r.mode='atan2'; r.active_rmse_e_deg=m.active_rmse_e_deg;
    r.shadow_rmse_e_deg=m.shadow_rmse_e_deg;
    r.active_max_error_e_deg=m.active_max_error_e_deg;
    r.fusion_count=m.fusion_count; r.coverage_fraction=m.coverage_fraction;
    r.finite=all(isfinite(state.active_lut_e_rad));
    r.active_lut_e_rad=state.active_lut_e_rad(:).';
    rows(end+1,1)=r; states{end+1,1}=state; %#ok<AGROW>
    [state,m]=stream_scheme2_trace(traces{cidx},64,cfg,'atan2_free');
    r=local_sweep_template(); r.sweep_family='algorithm_variant';
    r.setting='atan2_free'; r.value=NaN; r.condition=char(conditions(cidx));
    r.nodes=64; r.mode='atan2_free'; r.active_rmse_e_deg=m.active_rmse_e_deg;
    r.shadow_rmse_e_deg=m.shadow_rmse_e_deg;
    r.active_max_error_e_deg=m.active_max_error_e_deg;
    r.fusion_count=m.fusion_count; r.coverage_fraction=m.coverage_fraction;
    r.finite=all(isfinite(state.active_lut_e_rad));
    r.active_lut_e_rad=state.active_lut_e_rad(:).';
    rows(end+1,1)=r; states{end+1,1}=state; %#ok<AGROW>
end
end

function comparisons=local_scheme_comparisons(traces,conditions,scheme2States,cfg)
comparisons=repmat(local_comparison_template(),0,1);
for k=1:2
    [state4,m4]=stream_scheme4_trace(traces{k},64,cfg);
    [state5,m5]=stream_scheme5_trace(traces{k},64,cfg, ...
        cfg.stage3.MODE_NOMINAL);
    state2=scheme2States{k};
    ref=anglelut.aggregate_reference_lut(traces{k}.theta_m_raw_rad, ...
        traces{k}.truth_error_e_rad,64,traces{k}.valid & ...
        traces{k}.evaluation_mask);
    e2=anglelut.wrap_to_pi(state2.active_lut_e_rad-ref.lut_e_rad);
    mask=ref.valid_mask;
    row=local_comparison_template(); row.condition=char(conditions(k));
    row.scheme4_active_rmse_e_deg=m4.active_rmse_e_deg;
    row.scheme5_active_rmse_e_deg=m5.active_rmse_e_deg;
    row.scheme2_active_rmse_e_deg=rad2deg(sqrt(mean(e2(mask).^2)));
    row.scheme4_storage_bytes=local_bytes(state4);
    row.scheme5_storage_bytes=local_bytes(state5);
    row.scheme2_storage_bytes=local_bytes(state2);
    row.scheme4_sample_ops_estimate=24; row.scheme5_sample_ops_estimate=32;
    row.scheme2_sample_ops_estimate=20;
    row.cost_estimate_policy='scalar operation estimate; transcendental cost listed separately';
    comparisons(end+1,1)=row; %#ok<AGROW>
end
end

function [pairs,baselines]=local_run_frozen_matrix(matrix,runtimes,cfg,outDir,options)
pairs=repmat(local_pair_template(),0,1); baselines=cell(2,1);
for e=1:2
    evalCondition=matrix.evaluation_condition(e); c=matrix.evaluation(e);
    dirPath=fullfile(outDir,'frozen','baselines',char(evalCondition));
    [metrics,trace,stage1Trace]=local_frozen_sim(c,false, ...
        zeros(cfg.stage4.runtime_nodes,1),cfg,options);
    baselines{e}=metrics;
    local_save_frozen(dirPath,metrics,trace,stage1Trace);
end
for t=1:2
    for e=1:2
        trainCondition=matrix.training_condition(t);
        evalCondition=matrix.evaluation_condition(e); c=matrix.evaluation(e);
        dirPath=fullfile(outDir,'frozen', ...
            char("train_"+trainCondition+"__eval_"+evalCondition));
        [active,trace,stage1Trace]=local_frozen_sim( ...
            c,true,runtimes{t},cfg,options);
        local_save_frozen(fullfile(dirPath,'active_on'), ...
            active,trace,stage1Trace);
        pair=pair_stage2_metrics(baselines{e},active);
        pair.training_condition=char(trainCondition);
        pair.evaluation_condition=char(evalCondition);
        pair.profile_source_id=char(trainCondition);
        [~,pair.control_angle_gate_basis,pair.control_angle_gate_details]= ...
            control_angle_gate(pair,c,cfg);
        write_json_file(fullfile(dirPath,'pair_metrics.json'),pair);
        pairs(end+1,1)=local_normalize_pair(pair); %#ok<AGROW>
    end
end
end

function [metrics,trace,stage1Trace]=local_frozen_sim(c,activeEnable,runtime,cfg,options)
[simOut,elapsed]=simulate_stage2_case(c,cfg,activeEnable,runtime, ...
    options.simulation_mode,'angle_lut_stage4_harness');
[~,stage1Trace]=analyze_stage1_case(simOut,c,cfg);
[metrics,trace]=evaluate_stage4_frozen( ...
    simOut,stage1Trace,c,cfg,activeEnable);
metrics.elapsed_s=elapsed;
end

function checks=local_diagnostic_checks(training,nodeScan,sweeps,pairs,noise,states,cfg)
g=local_stage4_gates(cfg);
checks=struct();
checks.formal_stage3_prerequisite=false;
checks.training_count=numel(training)==2;
checks.m64_coverage=checks.training_count && all([training.coverage_fraction]>=g.coverage_fraction_min);
checks.m64_fusion_count=checks.training_count && all([training.fusion_count]>=g.fusion_count_min);
checks.active_convergence=checks.training_count && ...
    all([training.last_active_update_rms_e_rad]<=g.final_active_update_rms_max_e_rad) && ...
    all([training.previous_active_update_rms_e_rad]<=g.final_active_update_rms_max_e_rad);
checks.active_accuracy=checks.training_count && ...
    all([training.active_rmse_e_rad]<=g.active_lut_rmse_max_e_rad) && ...
    all([training.active_max_error_e_rad]<=g.active_lut_max_error_e_rad) && ...
    all([training.active_improvement_fraction]>=g.nonzero_lut_improvement_min);
checks.safety_constraints=checks.training_count && ...
    all([training.amplitude_constraint_satisfied]) && ...
    all([training.monotonic_constraint_satisfied]) && ...
    all(cellfun(@(x)all(isfinite(x.active_lut_e_rad)),states));
checks.training_lut_drift=false;
if checks.training_count
    delta=anglelut.wrap_to_pi(states{2}.active_lut_e_rad-states{1}.active_lut_e_rad);
    checks.training_lut_drift=sqrt(mean(delta.^2))<g.noise_lut_drift_max_e_rad;
end
checks.m128_complete=numel(nodeScan)==2 && ...
    all([nodeScan.coverage_fraction]>=g.coverage_fraction_min);
checks.m128_not_worse=checks.m128_complete && checks.training_count;
if checks.m128_not_worse
    for k=1:2
        checks.m128_not_worse=checks.m128_not_worse && ...
            nodeScan(k).active_rmse_e_rad <= training(k).active_rmse_e_rad + ...
            g.m128_rmse_regression_max_e_rad;
    end
end
checks.sweeps_finite=~isempty(sweeps) && all([sweeps.finite]);
fraction=local_field(noise,'fraction_within_requested_band',NaN);
checks.realized_noise_fraction=isfinite(fraction) && ...
    fraction>=g.noise_fraction_min && fraction<=g.noise_fraction_max;
checks.frozen_matrix_complete=numel(pairs)==4;
checks.control_angle=true; checks.iq_tracking=true; checks.mean_torque=true;
if checks.frozen_matrix_complete
    for k=1:numel(pairs)
        isNoisy=strcmp(pairs(k).evaluation_condition,'noise95_pm0p1A');
        if isNoisy
            controlPass=pairs(k).control_angle_improvement >= ...
                cfg.gates.stage3.nonideal_control_angle_improvement_min;
        else
            [controlPass,~,~]=control_angle_gate(pairs(k), ...
                struct('case_id','periodic_combined_zero_noise'),cfg);
        end
        checks.control_angle=checks.control_angle && controlPass;
        checks.iq_tracking=checks.iq_tracking && ...
            pairs(k).iq_tracking_change<=cfg.gates.stage3.iq_tracking_regression_max;
        checks.mean_torque=checks.mean_torque && ...
            pairs(k).mean_torque_change<=cfg.gates.stage3.mean_torque_change_max;
    end
end
ideal=pairs(strcmp({pairs.evaluation_condition},'zero_noise'));
nonideal=pairs(strcmp({pairs.evaluation_condition},'noise95_pm0p1A'));
checks.ideal_physical=local_physical_gate(ideal,0.05,-0.02);
checks.nonideal_physical=local_physical_gate(nonideal,0,-0.10);
mandatory={'training_count','m64_coverage','m64_fusion_count', ...
    'active_convergence','active_accuracy','safety_constraints', ...
    'training_lut_drift','m128_complete','m128_not_worse','sweeps_finite', ...
    'realized_noise_fraction','frozen_matrix_complete','control_angle', ...
    'iq_tracking','mean_torque','ideal_physical','nonideal_physical'};
checks.all_mandatory=all(cellfun(@(n)logical(checks.(n)),mandatory));
end

function pass=local_physical_gate(pairs,medianMinimum,regressionMinimum)
if isempty(pairs), pass=false; return; end
values=[[pairs.id_rms_improvement].',[pairs.prediction_residual_improvement].', ...
    [pairs.torque_ripple_improvement].'];
pass=all(median(values,1)>=medianMinimum) && all(values(:)>=regressionMinimum);
end

function g=local_stage4_gates(cfg)
if isfield(cfg.gates,'stage4'), g=cfg.gates.stage4; return; end
g=struct('coverage_fraction_min',1,'fusion_count_min',18, ...
    'final_active_update_rms_max_e_rad',deg2rad(0.25), ...
    'active_lut_rmse_max_e_rad',deg2rad(1), ...
    'active_lut_max_error_e_rad',deg2rad(2), ...
    'nonzero_lut_improvement_min',0.8, ...
    'noise_lut_drift_max_e_rad',deg2rad(0.5), ...
    'm128_rmse_regression_max_e_rad',deg2rad(0.25), ...
    'noise_fraction_min',0.94,'noise_fraction_max',0.96);
end

function gate=local_gate(result,stage3Info,tests,errors,cfg)
gate=struct('schema_version','angle-lut-stage4-noise-gate-v1', ...
    'status','BLOCKED','scope','NOISE_DIAGNOSTIC', ...
    'formal_stage3_prerequisite_satisfied',stage3Info.satisfied, ...
    'blocking_reason','Formal Stage 3 is not FULL_STAGE3/PASS.', ...
    'diagnostic_outcome',result.diagnostic_outcome, ...
    'checks',struct('stage3_prerequisite',stage3Info.satisfied, ...
    'unit_and_structure_tests',tests.passed, ...
    'numeric',result.diagnostic_checks,'report_bundle_generated',false), ...
    'thresholds',local_stage4_gates(cfg),'errors',errors);
end

function local_save_training(path,state,m,history,reference,runtime,trace,implementation,c,cfg)
local_mkdir(path); write_json_file(fullfile(path,'metrics.json'),m);
implementation2=struct('schema_version','scheme2-learning-implementation-v1', ...
    'sample_interface',{{'phi_m_rad','z_e_rad','quality_weight', ...
    'theta_m_unwrapped_rad','timestamp_s','valid'}}, ...
    'truth_feedback_used',false,'history_stored_inside_state',false, ...
    'source_implementation',implementation);
write_json_file(fullfile(path,'implementation.json'),implementation2);
M=double(state.M); node=(0:M-1).'; phi=node*2*pi/M;
hits=double(state.node_hits(:)); weight=double(state.node_weight(:));
variance=local_node_step_variance(state,M);
writetable(table(node,phi,state.shadow_lut_e_rad,state.active_lut_e_rad, ...
    reference.lut_e_rad,state.valid_mask,hits,weight,variance, ...
    'VariableNames',{'node','phi_m_rad','shadow_e_rad','active_e_rad', ...
    'reference_e_rad','valid','update_hits','effective_weight', ...
    'innovation_variance'}),fullfile(path,'lut_nodes.csv'));
writetable(table((0:cfg.stage4.runtime_nodes-1).',runtime(:), ...
    'VariableNames',{'node','active_e_rad'}), ...
    fullfile(path,'runtime_lut_512.csv'));
snapshot=struct('schema_version',state.schema_version,'M',M, ...
    'sample_count',state.sample_count,'accepted_count',state.accepted_count, ...
    'fusion_count',state.fusion_count,'coverage_fraction',m.coverage_fraction, ...
    'history_stored_inside_state',false);
write_json_file(fullfile(path,'state_snapshot.json'),snapshot);
save(fullfile(path,'scheme2_state.mat'),'state','history','reference','runtime','-v7.3');
if ~isempty(trace), save(fullfile(path,'training_trace.mat'),'trace','-v7.3'); end
write_json_file(fullfile(path,'case_config.json'),c);
end

function local_save_frozen(path,metrics,trace,stage1Trace)
local_mkdir(path); write_json_file(fullfile(path,'metrics.json'),metrics);
save(fullfile(path,'trace.mat'),'trace','stage1Trace','-v7.3');
end

function local_write_core_outputs(outDir,result,gate,training,nodeScan,pairs,sweeps)
write_json_file(fullfile(outDir,'result.json'),result);
write_json_file(fullfile(outDir,'gate.json'),gate);
write_json_file(fullfile(outDir,'training_metrics.json'),training);
write_json_file(fullfile(outDir,'node_scan_metrics.json'),nodeScan);
rows=local_metrics_rows(training,nodeScan,pairs,sweeps);
writetable(struct2table(rows),fullfile(outDir,'metrics.csv'));
end

function rows=local_metrics_rows(training,nodeScan,pairs,sweeps)
rows=repmat(struct('record_type','','id','','condition','', ...
    'active_lut_rmse_e_deg',NaN,'control_angle_off_e_deg',NaN, ...
    'control_angle_on_e_deg',NaN,'control_angle_improvement',NaN, ...
    'coverage_fraction',NaN,'fusion_count',NaN,'finite',true),0,1);
allTraining=[training(:);nodeScan(:)];
for k=1:numel(allTraining)
    r=rows_template(); r.record_type='learning'; r.id=allTraining(k).phase;
    r.condition=allTraining(k).condition;
    r.active_lut_rmse_e_deg=allTraining(k).active_rmse_e_deg;
    r.coverage_fraction=allTraining(k).coverage_fraction;
    r.fusion_count=allTraining(k).fusion_count; rows(end+1,1)=r; %#ok<AGROW>
end
for k=1:numel(pairs)
    r=rows_template(); r.record_type='frozen_pair';
    r.id=[pairs(k).training_condition '__' pairs(k).evaluation_condition];
    r.condition=pairs(k).evaluation_condition;
    r.control_angle_off_e_deg=pairs(k).baseline.control_angle_rmse_e_deg;
    r.control_angle_on_e_deg=pairs(k).active.control_angle_rmse_e_deg;
    r.control_angle_improvement=pairs(k).control_angle_improvement;
    rows(end+1,1)=r; %#ok<AGROW>
end
for k=1:numel(sweeps)
    r=rows_template(); r.record_type='sweep';
    r.id=[sweeps(k).sweep_family '=' sweeps(k).setting];
    r.condition=sweeps(k).condition;
    r.active_lut_rmse_e_deg=sweeps(k).active_rmse_e_deg;
    r.coverage_fraction=sweeps(k).coverage_fraction;
    r.fusion_count=sweeps(k).fusion_count; r.finite=sweeps(k).finite;
    rows(end+1,1)=r; %#ok<AGROW>
end
end

function r=rows_template()
r=struct('record_type','','id','','condition','', ...
    'active_lut_rmse_e_deg',NaN,'control_angle_off_e_deg',NaN, ...
    'control_angle_on_e_deg',NaN,'control_angle_improvement',NaN, ...
    'coverage_fraction',NaN,'fusion_count',NaN,'finite',true);
end

function rows=local_sweep_rows(input)
rows=rmfield(input,'active_lut_e_rad');
end

function rows=local_pair_rows(input)
rows=repmat(struct('training_condition','','evaluation_condition','', ...
    'expected_class','','control_angle_off_e_deg',NaN, ...
    'control_angle_on_e_deg',NaN,'control_angle_improvement',NaN, ...
    'id_rms_improvement',NaN,'prediction_residual_improvement',NaN, ...
    'torque_ripple_improvement',NaN,'iq_tracking_change',NaN, ...
    'mean_torque_change',NaN,'control_angle_gate_basis',''),numel(input),1);
for k=1:numel(input)
    rows(k).training_condition=input(k).training_condition;
    rows(k).evaluation_condition=input(k).evaluation_condition;
    rows(k).expected_class=input(k).expected_class;
    rows(k).control_angle_off_e_deg=input(k).baseline.control_angle_rmse_e_deg;
    rows(k).control_angle_on_e_deg=input(k).active.control_angle_rmse_e_deg;
    rows(k).control_angle_improvement=input(k).control_angle_improvement;
    rows(k).id_rms_improvement=input(k).id_rms_improvement;
    rows(k).prediction_residual_improvement=input(k).prediction_residual_improvement;
    rows(k).torque_ripple_improvement=input(k).torque_ripple_improvement;
    rows(k).iq_tracking_change=input(k).iq_tracking_change;
    rows(k).mean_torque_change=input(k).mean_torque_change;
    rows(k).control_angle_gate_basis=input(k).control_angle_gate_basis;
end
end

function local_write_gate_failures(outDir,checks)
names=fieldnames(checks); failed=names(~cellfun(@(n)logical(checks.(n)),names));
write_json_file(fullfile(outDir,'failures','diagnostic_failures.json'), ...
    struct('failed_checks',{failed}));
local_write_text(fullfile(outDir,'failures','diagnostic_failures.txt'), ...
    strjoin(failed,newline));
end

function local_assert_passed_hashes(cfg,source,stage1,stage2,stage3)
assert(strcmpi(source,file_sha256(cfg.source_model)), ...
    'anglelut:Stage4ChangedSource','Stage 4 changed the source model.');
assert(strcmpi(stage1,file_sha256(cfg.harness_model)), ...
    'anglelut:Stage4ChangedStage1','Stage 4 changed the Stage-1 harness.');
assert(strcmpi(stage2,file_sha256(cfg.project.stage2_harness_model)), ...
    'anglelut:Stage4ChangedStage2','Stage 4 changed the Stage-2 harness.');
assert(strcmpi(stage3,file_sha256(cfg.project.stage3_harness_model)), ...
    'anglelut:Stage4ChangedStage3','Stage 4 changed the Stage-3 harness.');
end

function bytes=local_bytes(value)
bytes=strlength(string(jsonencode(value)));
end

function variance=local_node_step_variance(state,n)
variance=NaN(n,1);
if ~isfield(state,'node_step_M2_e_rad2') || ~isfield(state,'node_hits')
    return;
end
hits=double(state.node_hits(:)); mask=hits>1;
variance(mask)=double(state.node_step_M2_e_rad2(mask))./(hits(mask)-1);
end

function value=local_field(s,name,fallback)
if isstruct(s) && isfield(s,name), value=s.(name); else, value=fallback; end
end

function result=local_result(runId,path)
result=struct('schema_version','stage4-noise-diagnostic-result-v1', ...
    'run_id',char(runId),'final_status','','diagnostic_outcome','', ...
    'prerequisite_stage3',struct(),'prerequisite_stage2',struct(), ...
    'training_results',[],'node_scan',[],'sweep_results',[], ...
    'scheme_comparison',[],'frozen_matrix',[], ...
    'noise_realization',struct(),'diagnostic_checks',struct(), ...
    'result_path',path);
end

function t=local_training_template()
t=struct('case_id','','condition','','phase','','status','', ...
    'elapsed_s',NaN,'nodes',NaN,'sample_count',NaN,'accepted_count',NaN, ...
    'effective_weight',NaN,'coverage_fraction',NaN,'fusion_count',NaN, ...
    'total_abs_travel_m_rad',NaN,'mechanical_revolutions',NaN, ...
    'shadow_rmse_e_rad',NaN,'shadow_rmse_e_deg',NaN, ...
    'active_rmse_e_rad',NaN,'active_rmse_e_deg',NaN, ...
    'baseline_rmse_e_rad',NaN,'baseline_rmse_e_deg',NaN, ...
    'active_max_error_e_rad',NaN,'active_max_error_e_deg',NaN, ...
    'active_improvement_fraction',NaN,'last_active_update_rms_e_rad',NaN, ...
    'previous_active_update_rms_e_rad',NaN,'active_max_abs_e_rad',NaN, ...
    'minimum_monotonic_margin',NaN,'all_nodes_valid',false, ...
    'finite_state',false,'amplitude_constraint_satisfied',false, ...
    'monotonic_constraint_satisfied',false);
end

function out=local_normalize_training(input)
out=local_training_template(); names=fieldnames(input);
for k=1:numel(names), if isfield(out,names{k}), out.(names{k})=input.(names{k}); end, end
end

function s=local_sweep_template()
s=struct('sweep_family','','setting','','value',NaN,'condition','', ...
    'nodes',NaN,'mode','','active_rmse_e_deg',NaN, ...
    'shadow_rmse_e_deg',NaN,'active_max_error_e_deg',NaN, ...
    'fusion_count',NaN,'coverage_fraction',NaN,'finite',false, ...
    'active_lut_e_rad',zeros(1,0));
end

function p=local_pair_template()
metric=struct('case_id','','active_enable',false,'expected_class','', ...
    'sample_count',NaN,'control_angle_rmse_e_rad',NaN,'id_rms_A',NaN, ...
    'iq_tracking_rmse_A',NaN,'prediction_residual_rms_A',NaN, ...
    'mean_torque_Nm',NaN,'compensation_rms_e_rad',NaN, ...
    'compensation_max_abs_e_rad',NaN,'control_angle_rmse_e_deg',NaN, ...
    'torque_ripple_rms_Nm',NaN,'elapsed_s',NaN);
p=struct('case_id','','expected_class','','baseline',metric,'active',metric, ...
    'control_angle_improvement',NaN,'id_rms_improvement',NaN, ...
    'prediction_residual_improvement',NaN,'torque_ripple_improvement',NaN, ...
    'iq_tracking_change',NaN,'mean_torque_change',NaN, ...
    'profile_source_id','','training_condition','','evaluation_condition','', ...
    'control_angle_gate_basis','','control_angle_gate_details',struct());
end

function out=local_normalize_pair(input)
out=local_pair_template(); names=fieldnames(input);
for k=1:numel(names), if isfield(out,names{k}), out.(names{k})=input.(names{k}); end, end
end

function c=local_comparison_template()
c=struct('condition','','scheme4_active_rmse_e_deg',NaN, ...
    'scheme5_active_rmse_e_deg',NaN,'scheme2_active_rmse_e_deg',NaN, ...
    'scheme4_storage_bytes',NaN,'scheme5_storage_bytes',NaN, ...
    'scheme2_storage_bytes',NaN,'scheme4_sample_ops_estimate',NaN, ...
    'scheme5_sample_ops_estimate',NaN,'scheme2_sample_ops_estimate',NaN, ...
    'cost_estimate_policy','');
end

function h=local_history_template()
h=struct('condition','','fusion_count',zeros(0,1),'time_s',zeros(0,1), ...
    'travel_m_rad',zeros(0,1),'mechanical_cycles',zeros(0,1), ...
    'active_lut_e_rad',zeros(0,0),'shadow_lut_e_rad',zeros(0,0), ...
    'active_rmse_e_deg',zeros(0,1),'shadow_rmse_e_deg',zeros(0,1), ...
    'reference_lut_e_rad',zeros(0,1));
end

function out=local_normalize_history(input)
out=local_history_template(); names=fieldnames(out);
for k=1:numel(names), if isfield(input,names{k}), out.(names{k})=input.(names{k}); end, end
end

function rows=local_sweep_rows_placeholder %#ok<DEFNU>
rows=struct();
end

function local_mkdir(path)
if ~isfolder(path), mkdir(path); end
end

function local_write_text(path,textValue)
local_mkdir(fileparts(path)); fid=fopen(path,'w');
assert(fid>=0,'anglelut:Stage4WriteFailed','Cannot write %s.',path);
cleanup=onCleanup(@()fclose(fid));
fprintf(fid,'%s\n',char(string(textValue)));
clear cleanup
end

function value=local_iso_time()
value=char(datetime('now','TimeZone','UTC', ...
    'Format','yyyy-MM-dd''T''HH:mm:ss.SSSXXX'));
end
