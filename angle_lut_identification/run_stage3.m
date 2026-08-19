function result = run_stage3(options)
%RUN_STAGE3 Train Scheme 5 and execute the frozen Stage-3 matrix.

if nargin < 1, options=struct(); end
options=local_options(options);
base=setup_project(); cfg=stage3_config(); cfg.project_root=base.project_root;
cfg.source_model=cfg.project.baseline_model; cfg.harness_model=cfg.project.harness_model;
matrix=stage3_case_matrix(cfg);
runId="stage3_"+string(datetime('now','Format','yyyyMMdd_HHmmss_SSS'));
outDir=fullfile(cfg.project_root,'results',char(runId),'stage3');
local_mkdir(outDir); local_mkdir(fullfile(outDir,'failures'));
started=local_iso_time();
result=local_result(runId,outDir);
p64=repmat(local_profile(),0,1); p128=p64; diagnostics=p64;
pairs=repmat(local_pair(),0,1); drift=repmat(local_drift(),0,1);
sensitivity=repmat(local_sensitivity(),0,1);
errors=strings(0,1); prerequisite=struct();
testSummary=struct('passed',false,'count',0,'failed',0,'incomplete',0);
stop=struct('triggered',false,'phase','','case_id','','reason','');
sourceHash=file_sha256(cfg.source_model);
stage1Hash=file_sha256(cfg.harness_model);
stage2Hash=file_sha256(cfg.project.stage2_harness_model);
stage3Hash="";
configuration=struct('schema_version','angle-lut-stage3-run-config-v1', ...
    'gate_schema_version',cfg.gates.schema_version,'run_id',char(runId), ...
    'config',cfg,'case_matrix',matrix,'options',options, ...
    'random_seed',cfg.stage3.random_seed);
write_json_file(fullfile(outDir,'configuration.json'),configuration);

try
    [prerequisite,ok,message]=local_prerequisite(cfg,options);
    if ~ok
        result.final_status='BLOCKED'; stop=local_stop(stop,'prerequisite','',message);
        errors=string(message);
        error('anglelut:Stage3Prerequisite','%s',message);
    end
    if options.rebuild_harness, build_stage3_harness(); end
    assert(isfile(cfg.project.stage3_harness_model), ...
        'anglelut:MissingStage3Harness','Stage-3 harness is missing.');
    stage3Hash=string(file_sha256(cfg.project.stage3_harness_model));
    local_guard_hashes(cfg,sourceHash,stage1Hash,stage2Hash);
    environment=collect_environment_manifest(cfg.project.stage3_harness_model,cfg.timing);
    write_json_file(fullfile(outDir,'environment_manifest.json'),environment);
    inventory=collect_file_inventory(cfg.project_root);
    writetable(inventory,fullfile(outDir,'file_inventory.csv'));
    write_json_file(fullfile(outDir,'file_inventory.json'),table2struct(inventory));
    [testsOk,testSummary]=local_run_tests(cfg,outDir,options.run_tests);
    if ~testsOk
        stop=local_stop(stop,'tests','','Stage-3 unit or structure tests failed.');
        error('anglelut:Stage3TestsFailed','Stage-3 tests failed.');
    end

    training=local_select(matrix.training,options.training_case_ids, ...
        options.max_training_profiles);
    validation=local_select(matrix.validation,options.validation_case_ids, ...
        options.max_validation_cases);
    states=cell(numel(training),1); runtimes=cell(numel(training),1);
    for k=1:numel(training)
        c=training(k); sourceTrace=local_training_trace(prerequisite.path,c.case_id);
        loaded=load(sourceTrace,'trace'); t=tic;
        [state,m,history,reference,runtime]=stream_scheme5_trace( ...
            loaded.trace,64,cfg,cfg.stage3.MODE_NOMINAL);
        m=local_complete_profile(m,c,'M64_NOMINAL',toc(t));
        m=local_scheme4_compare(m,state,prerequisite.path,c.case_id);
        caseDir=fullfile(outDir,'training',char(c.case_id),'M64','nominal_model');
        local_save_learning(caseDir,state,m,history,reference,runtime, ...
            sourceTrace,c,cfg);
        p64(end+1,1)=local_normalize_profile(m); %#ok<AGROW>
        states{k}=state; runtimes{k}=runtime;
        [profilePass,reason]=local_profile_gate(m,c,cfg,true);
        if options.stop_on_gate_failure && ~profilePass
            stop=local_stop(stop,'M64_training',char(c.case_id),reason); break;
        end

        for mode=[cfg.stage3.MODE_MEASURED_MAGNITUDE, ...
                cfg.stage3.MODE_DIRECTION_NORMALIZED]
            t=tic; [ds,dm,dh,dr,du]=stream_scheme5_trace(loaded.trace,64,cfg,mode);
            dm=local_complete_profile(dm,c,'M64_DIAGNOSTIC',toc(t));
            ddir=fullfile(outDir,'amplitude_diagnostics',char(c.case_id),dm.amplitude_mode);
            local_save_learning(ddir,ds,dm,dh,dr,du,sourceTrace,c,cfg);
            diagnostics(end+1,1)=local_normalize_profile(dm); %#ok<AGROW>
            if options.stop_on_gate_failure && ~local_diagnostic_gate(dm)
                stop=local_stop(stop,'amplitude_diagnostic',char(c.case_id), ...
                    sprintf('Diagnostic amplitude mode %s diverged.',dm.amplitude_mode));
                break;
            end
        end
        if stop.triggered, break; end
    end

    if ~stop.triggered && numel(p64)==numel(training)
        for k=1:numel(training)
            c=training(k); sourceTrace=local_training_trace(prerequisite.path,c.case_id);
            loaded=load(sourceTrace,'trace'); t=tic;
            [state,m,history,reference,runtime]=stream_scheme5_trace( ...
                loaded.trace,128,cfg,cfg.stage3.MODE_NOMINAL);
            m=local_complete_profile(m,c,'M128_NOMINAL_REPLAY',toc(t));
            m=local_scheme4_compare(m,state,prerequisite.path,c.case_id,'M128');
            caseDir=fullfile(outDir,'training',char(c.case_id),'M128','nominal_model');
            local_save_learning(caseDir,state,m,history,reference,runtime, ...
                sourceTrace,c,cfg);
            p128(end+1,1)=local_normalize_profile(m); %#ok<AGROW>
            [profilePass,reason]=local_profile_gate(m,c,cfg,false);
            if options.stop_on_gate_failure && ~profilePass
                stop=local_stop(stop,'M128_scan',char(c.case_id),reason); break;
            end
        end
    end

    if ~stop.triggered
        for k=1:numel(training)
            c=local_override_stop(training(k),options.stop_time_override_s);
            pairDir=fullfile(outDir,'profile_freeze',char(c.case_id));
            pair=local_run_pair(c,cfg,runtimes{k},pairDir,options);
            pair.profile_source_id=char(c.case_id);
            write_json_file(fullfile(pairDir,'pair_metrics.json'),pair);
            pairs(end+1,1)=local_normalize_pair(pair); %#ok<AGROW>
            [pairPass,~,details]=evaluate_stage3_pair_gate(pair,c,cfg);
            if options.stop_on_gate_failure && ~pairPass
                write_json_file(fullfile(pairDir,'gate_details.json'),details);
                stop=local_stop(stop,'profile_freeze',char(c.case_id), ...
                    'A frozen Scheme-5 profile gate failed.'); break;
            end
        end
    end

    primary=find(string({p64.case_id})==cfg.stage3.primary_profile_id,1);
    if ~stop.triggered && ~isempty(primary)
        local_save_primary(outDir,states{primary},runtimes{primary},cfg);
        stage1Path=char(prerequisite.stage1_path);
        drift=local_run_drift(stage1Path,states{primary},cfg,matrix,outDir);
        if options.stop_on_gate_failure && any([drift.lut_drift_e_rad] >= ...
                cfg.gates.stage3.cross_condition_lut_drift_max_e_rad)
            stop=local_stop(stop,'condition_drift','', ...
                'A Scheme-5 speed/direction/load LUT drift is >=0.5 deg_e.');
        end
        if ~stop.triggered
            sensitivity=local_run_sensitivity(stage1Path,states{primary}, ...
                cfg,matrix,outDir);
            if options.stop_on_gate_failure && (~all([sensitivity.finite_diagnostics]) || ...
                    any([sensitivity.valid_fraction] < ...
                    cfg.gates.stage3.sensitivity_valid_fraction_min))
                stop=local_stop(stop,'sensitivity','', ...
                    'A Stage-3 sensitivity diagnostic is incomplete.');
            end
        end
        if ~stop.triggered
            for k=1:numel(validation)
                c=local_override_stop(validation(k),options.stop_time_override_s);
                pairDir=fullfile(outDir,'frozen_validation',char(c.case_id));
                pair=local_run_pair(c,cfg,runtimes{primary},pairDir,options);
                pair.profile_source_id=char(cfg.stage3.primary_profile_id);
                write_json_file(fullfile(pairDir,'pair_metrics.json'),pair);
                pairs(end+1,1)=local_normalize_pair(pair); %#ok<AGROW>
                [pairPass,~,details]=evaluate_stage3_pair_gate(pair,c,cfg);
                if options.stop_on_gate_failure && ~pairPass
                    write_json_file(fullfile(pairDir,'gate_details.json'),details);
                    stop=local_stop(stop,'frozen_validation',char(c.case_id), ...
                        'A frozen Scheme-5 validation gate failed.'); break;
                end
            end
        end
    elseif ~stop.triggered
        stop=local_stop(stop,'primary_lut','', ...
            'The nominal periodic_combined M64 LUT is unavailable.');
    end

    complete=local_complete(options,matrix,p64,p128,diagnostics,pairs, ...
        drift,sensitivity,stop);
    [numeric,aggregate]=evaluate_stage3_acceptance(p64,p128,diagnostics, ...
        pairs,drift,sensitivity,cfg,complete);
    checks=struct('stage2_prerequisite',ok,'unit_and_structure_tests', ...
        testSummary.passed,'source_hash_unchanged',strcmpi(sourceHash, ...
        file_sha256(cfg.source_model)),'stage1_harness_hash_unchanged', ...
        strcmpi(stage1Hash,file_sha256(cfg.harness_model)), ...
        'stage2_harness_hash_unchanged',strcmpi(stage2Hash, ...
        file_sha256(cfg.project.stage2_harness_model)), ...
        'learning_interface_truth_free',true,'joint_parameter_update_disabled', ...
        ~cfg.stage3.joint_parameter_identification_enabled, ...
        'stage4_disabled',~cfg.stage3.enable_stage4,'numeric',numeric);
    allChecks=ok && testSummary.passed && checks.source_hash_unchanged && ...
        checks.stage1_harness_hash_unchanged && ...
        checks.stage2_harness_hash_unchanged && numeric.all_mandatory;
    if ~strcmp(options.mode,'full')
        status='BLOCKED';
    elseif complete && allChecks
        status='PASS';
    elseif complete || stop.triggered
        status='FAIL';
    else
        status='BLOCKED';
    end
    result.final_status=status;
    gate=local_gate(status,complete,checks,aggregate,cfg,stop,errors);
catch exception
    if ~startsWith(string(exception.identifier),'anglelut:Stage3Prerequisite')
        errors=string(getReport(exception,'extended','hyperlinks','off'));
    end
    local_write_text(fullfile(outDir,'failures','run_error.txt'), ...
        getReport(exception,'extended','hyperlinks','off'));
    if isempty(result.final_status)
        if strcmp(options.mode,'bounded')
            result.final_status='BLOCKED';
        else
            result.final_status='FAIL';
        end
    end
    checks=struct('stage2_prerequisite',~isempty(fieldnames(prerequisite)), ...
        'unit_and_structure_tests',testSummary.passed, ...
        'source_hash_unchanged',strcmpi(sourceHash,file_sha256(cfg.source_model)), ...
        'stage1_harness_hash_unchanged',strcmpi(stage1Hash,file_sha256(cfg.harness_model)), ...
        'stage2_harness_hash_unchanged',strcmpi(stage2Hash, ...
        file_sha256(cfg.project.stage2_harness_model)));
    gate=local_gate(result.final_status,false,checks,struct(),cfg,stop,errors);
end

result.prerequisite_stage2=prerequisite; result.training_results=p64;
result.amplitude_mode_results=diagnostics; result.node_scan=p128;
result.scheme4_comparison=local_scheme4_summary(p64);
result.frozen_cases=pairs; result.sensitivity_results=sensitivity;
result.condition_drift=drift;
local_write_outputs(outDir,result,gate,p64,p128,diagnostics,pairs,drift,sensitivity);
manifest=struct('schema_version','angle-lut-stage3-manifest-v1', ...
    'run_id',char(runId),'started_at_utc',started,'completed_at_utc', ...
    local_iso_time(),'final_status',result.final_status,'scope',local_scope(options), ...
    'random_seed',cfg.stage3.random_seed,'prerequisite_stage2',prerequisite, ...
    'source_model_sha256_before',sourceHash,'source_model_sha256_after', ...
    file_sha256(cfg.source_model),'stage1_harness_sha256_before',stage1Hash, ...
    'stage1_harness_sha256_after',file_sha256(cfg.harness_model), ...
    'stage2_harness_sha256_before',stage2Hash,'stage2_harness_sha256_after', ...
    file_sha256(cfg.project.stage2_harness_model),'stage3_harness_sha256', ...
    char(stage3Hash),'tests',testSummary,'critical_early_stop',stop, ...
    'primary_amplitude_mode',char(cfg.stage3.primary_amplitude_mode), ...
    'joint_parameter_identification_enabled',false,'stage4_executed',false, ...
    'result_path',outDir);
write_json_file(fullfile(outDir,'run_manifest.json'),manifest);
reportOk=true;
try
    generate_stage3_reports(outDir);
catch reportException
    reportOk=false; local_write_text(fullfile(outDir,'failures','report_error.txt'), ...
        getReport(reportException,'extended','hyperlinks','off'));
    if strcmp(result.final_status,'PASS'), result.final_status='FAIL'; end
end
gate.checks.report_bundle_generated=reportOk; gate.status=result.final_status;
manifest.final_status=result.final_status; manifest.report_bundle_generated=reportOk;
write_json_file(fullfile(outDir,'gate.json'),gate);
write_json_file(fullfile(outDir,'result.json'),result);
write_json_file(fullfile(outDir,'run_manifest.json'),manifest);
local_write_text(fullfile(cfg.project_root,'results','latest_stage3.txt'),char(runId));
if bdIsLoaded('angle_lut_stage3_harness'), close_system('angle_lut_stage3_harness',0); end
end

function options=local_options(input)
options=struct('mode','full','rebuild_harness',true,'run_tests',true, ...
    'simulation_mode','rapid-accelerator','max_training_profiles',8, ...
    'max_validation_cases',24,'stop_time_override_s',[], ...
    'stop_on_gate_failure',true,'training_case_ids',strings(0,1), ...
    'validation_case_ids',strings(0,1),'prerequisite_stage2_run_id','');
names=fieldnames(input);
for k=1:numel(names)
    assert(isfield(options,names{k}),'anglelut:Stage3UnknownOption', ...
        'Unknown Stage-3 option %s.',names{k}); options.(names{k})=input.(names{k});
end
options.mode=char(validatestring(options.mode,{'full','bounded'}));
options.simulation_mode=char(validatestring(options.simulation_mode, ...
    {'normal','accelerator','rapid-accelerator'}));
end

function [info,ok,message]=local_prerequisite(cfg,options)
runId=string(options.prerequisite_stage2_run_id);
if strlength(runId)==0
    pointer=fullfile(cfg.project_root,'results','latest_stage2.txt');
    if ~isfile(pointer), runId=""; else, runId=strtrim(string(fileread(pointer))); end
end
if contains(runId,filesep), [~,runId]=fileparts(char(runId)); end
path=fullfile(cfg.project_root,'results',char(runId),'stage2');
gatePath=fullfile(path,'gate.json'); resultPath=fullfile(path,'result.json');
info=struct('run_id',char(runId),'path',path,'status','', ...
    'gate_sha256','','result_sha256','','stage1_path','');
ok=false; message='';
if ~isfile(gatePath) || ~isfile(resultPath)
    message='A complete Stage-2 result is not available.'; return;
end
gate=jsondecode(fileread(gatePath)); r=jsondecode(fileread(resultPath));
info.status=char(r.final_status); info.gate_sha256=file_sha256(gatePath);
info.result_sha256=file_sha256(resultPath);
manifestPath=fullfile(path,'run_manifest.json');
if isfile(manifestPath)
    manifest=jsondecode(fileread(manifestPath));
    if isfield(manifest,'stage1_source') && isfield(manifest.stage1_source,'path')
        info.stage1_path=char(manifest.stage1_source.path);
    end
end
ok=strcmp(gate.status,'PASS') && strcmp(gate.scope,'FULL_STAGE2') && ...
    strcmp(r.final_status,'PASS');
if ~ok, message=sprintf('Stage-2 result %s is not FULL_STAGE2/PASS.',runId); end
if ok && isempty(info.stage1_path)
    message='Stage-2 manifest does not identify its Stage-1 source.'; ok=false;
end
end

function path=local_training_trace(stage2Path,id)
path=fullfile(stage2Path,'training',char(id),'M64','training_trace.mat');
assert(isfile(path),'anglelut:Stage3TrainingTraceMissing', ...
    'Stage-2 training trace is missing for %s.',id);
end

function m=local_complete_profile(m,c,phase,elapsed)
m.case_id=char(c.case_id); m.phase=phase; m.status='PASS'; m.elapsed_s=elapsed;
m.scheme4_shadow_difference_e_rad=NaN; m.scheme4_active_difference_e_rad=NaN;
end

function m=local_scheme4_compare(m,state,stage2Path,id,nodes)
if nargin<5, nodes='M64'; end
path=fullfile(stage2Path,'training',char(id),nodes,'scheme4_state.mat');
assert(isfile(path),'anglelut:Stage3Scheme4ReferenceMissing', ...
    'Scheme-4 state is missing for %s/%s.',id,nodes);
loaded=load(path,'state');
m.scheme4_shadow_difference_e_rad=local_circular_rms( ...
    state.shadow_lut_e_rad-loaded.state.shadow_lut_e_rad);
m.scheme4_active_difference_e_rad=local_circular_rms( ...
    state.active_lut_e_rad-loaded.state.active_lut_e_rad);
end

function pass=local_diagnostic_gate(m)
pass=m.coverage_fraction>=1 && m.finite_state && m.all_nodes_valid && ...
    m.amplitude_constraint_satisfied && m.monotonic_constraint_satisfied;
end

function [pass,reason]=local_profile_gate(m,c,cfg,isDefault)
g=cfg.gates.stage3;
pass=m.coverage_fraction>=1 && m.all_nodes_valid && m.finite_state && ...
    m.amplitude_constraint_satisfied && m.monotonic_constraint_satisfied;
if isDefault
    pass=pass && m.fusion_count>=g.fusion_count_min && ...
        m.last_active_update_rms_e_rad<=g.final_active_update_rms_max_e_rad && ...
        m.previous_active_update_rms_e_rad<=g.final_active_update_rms_max_e_rad && ...
        m.shadow_rmse_e_rad<=g.shadow_lut_rmse_max_e_rad && ...
        m.active_rmse_e_rad<=g.active_lut_rmse_max_e_rad && ...
        m.active_max_error_e_rad<=g.active_lut_max_error_e_rad && ...
        m.scheme4_shadow_difference_e_rad<=g.scheme4_lut_difference_max_e_rad && ...
        m.scheme4_active_difference_e_rad<=g.scheme4_lut_difference_max_e_rad;
    if string(c.case_id)=="fixed_00deg_e"
        pass=pass && m.active_rmse_e_rad<=g.fixed_zero_lut_rmse_max_e_rad;
    else
        pass=pass && m.active_improvement_fraction>=g.nonzero_lut_improvement_min;
    end
end
if pass, reason=''; else, reason=sprintf('Scheme-5 profile gate failed for %s.',c.case_id); end
end

function pair=local_run_pair(c,cfg,runtime,pairDir,options)
local_mkdir(pairDir); write_json_file(fullfile(pairDir,'case_config.json'),c);
zero=zeros(cfg.stage3.runtime_nodes,1); model='angle_lut_stage3_harness';
[offOut,offElapsed]=simulate_stage2_case(c,cfg,false,zero, ...
    options.simulation_mode,model);
[~,offStage1]=analyze_stage1_case(offOut,c,cfg);
[offMetrics,offTrace]=evaluate_stage3_frozen(offOut,offStage1,c,cfg,false);
offMetrics.elapsed_s=offElapsed;
local_save_frozen(fullfile(pairDir,'active_off'),offMetrics,offTrace,offStage1);
[onOut,onElapsed]=simulate_stage2_case(c,cfg,true,runtime, ...
    options.simulation_mode,model);
[~,onStage1]=analyze_stage1_case(onOut,c,cfg);
[onMetrics,onTrace]=evaluate_stage3_frozen(onOut,onStage1,c,cfg,true);
onMetrics.elapsed_s=onElapsed;
local_save_frozen(fullfile(pairDir,'active_on'),onMetrics,onTrace,onStage1);
pair=pair_stage2_metrics(offMetrics,onMetrics); pair.profile_source_id='';
[~,pair.control_angle_gate_basis,pair.control_angle_gate_details]= ...
    control_angle_gate(pair,c,cfg);
write_json_file(fullfile(pairDir,'pair_metrics.json'),pair);
end

function local_save_frozen(path,metrics,trace,stage1Trace)
local_mkdir(path); write_json_file(fullfile(path,'metrics.json'),metrics);
save(fullfile(path,'trace.mat'),'trace','stage1Trace','-v7.3');
end

function local_save_learning(path,state,m,history,reference,runtime,source,c,cfg)
local_mkdir(path); write_json_file(fullfile(path,'case_config.json'),c);
write_json_file(fullfile(path,'metrics.json'),m);
implementation=struct('schema_version','scheme5-learning-implementation-v1', ...
    'source_trace',source,'source_trace_sha256',file_sha256(source), ...
    'sample_interface',{{'phi_m_rad','y_d_A','y_q_A', ...
    'omega_e_est_radps','quality_weight','theta_m_unwrapped_rad', ...
    'timestamp_s','valid'}},'truth_feedback_used',false, ...
    'primary_mode',strcmp(m.amplitude_mode,cfg.stage3.primary_amplitude_mode));
write_json_file(fullfile(path,'implementation.json'),implementation);
M=double(state.M); node=(0:M-1).'; phi=node*2*pi/M;
writetable(table(node,phi,state.shadow_lut_e_rad,state.active_lut_e_rad, ...
    reference.lut_e_rad,state.valid_mask,'VariableNames', ...
    {'node','phi_m_rad','shadow_e_rad','active_e_rad','reference_e_rad','valid'}), ...
    fullfile(path,'lut_nodes.csv'));
writetable(table((0:numel(runtime)-1).',runtime, ...
    'VariableNames',{'node','active_e_rad'}),fullfile(path,'runtime_lut_512.csv'));
snapshot=struct('schema_version',state.schema_version,'M',M, ...
    'amplitude_mode',m.amplitude_mode,'sample_count',state.sample_count, ...
    'accepted_count',state.accepted_count,'fusion_count',state.fusion_count, ...
    'coverage_fraction',m.coverage_fraction,'total_abs_travel_m_rad', ...
    state.total_abs_travel_m_rad,'history_stored_inside_state',false);
write_json_file(fullfile(path,'state_snapshot.json'),snapshot);
save(fullfile(path,'scheme5_state.mat'),'state','history','reference','runtime','-v7.3');
end

function drift=local_run_drift(stage1Path,primary,cfg,matrix,outDir)
drift=repmat(local_drift(),0,1); root=fullfile(outDir,'condition_drift'); local_mkdir(root);
for id=matrix.condition_drift_ids
    path=fullfile(stage1Path,'cases',char(id),'trace.mat');
    assert(isfile(path),'anglelut:Stage3DriftTraceMissing','Missing %s.',id);
    loaded=load(path,'trace'); [state,m,history,reference,runtime]= ...
        stream_scheme5_trace(loaded.trace,64,cfg,cfg.stage3.MODE_NOMINAL);
    d=local_drift(); d.case_id=char(id); d.lut_drift_e_rad= ...
        local_circular_rms(state.shadow_lut_e_rad-primary.shadow_lut_e_rad);
    d.lut_drift_e_deg=rad2deg(d.lut_drift_e_rad); d.coverage_fraction=m.coverage_fraction;
    d.fusion_count=m.fusion_count; drift(end+1,1)=d; %#ok<AGROW>
    local_save_learning(fullfile(root,char(id)),state, ...
        local_complete_profile(m,struct('case_id',id),'CONDITION_DRIFT',0), ...
        history,reference,runtime,path,struct('case_id',id),cfg);
end
end

function values=local_run_sensitivity(stage1Path,primary,cfg,matrix,outDir)
values=repmat(local_sensitivity(),0,1); root=fullfile(outDir,'sensitivity'); local_mkdir(root);
for id=matrix.sensitivity_ids
    path=fullfile(stage1Path,'cases',char(id),'trace.mat');
    assert(isfile(path),'anglelut:Stage3SensitivityTraceMissing','Missing %s.',id);
    loaded=load(path,'trace'); [state,m,history,reference,runtime]= ...
        stream_scheme5_trace(loaded.trace,64,cfg,cfg.stage3.MODE_NOMINAL);
    s=local_sensitivity(); s.case_id=char(id); s.tangent_rms=m.tangent_rms;
    s.radial_rms=m.radial_rms; s.lut_drift_e_rad=local_circular_rms( ...
        state.shadow_lut_e_rad-primary.shadow_lut_e_rad);
    denom=max(nnz(loaded.trace.evaluation_mask),1);
    s.valid_fraction=double(state.accepted_count)/denom;
    s.finite_diagnostics=all(isfinite([s.tangent_rms,s.radial_rms, ...
        s.lut_drift_e_rad])); values(end+1,1)=s; %#ok<AGROW>
    local_save_learning(fullfile(root,char(id)),state, ...
        local_complete_profile(m,struct('case_id',id),'SENSITIVITY',0), ...
        history,reference,runtime,path,struct('case_id',id),cfg);
end
end

function local_save_primary(outDir,state,runtime,cfg)
path=fullfile(outDir,'luts'); local_mkdir(path); M=double(state.M);
writetable(table((0:M-1).',state.shadow_lut_e_rad,state.active_lut_e_rad, ...
    'VariableNames',{'node','shadow_e_rad','active_e_rad'}), ...
    fullfile(path,'primary_M64.csv'));
writetable(table((0:cfg.stage3.runtime_nodes-1).',runtime, ...
    'VariableNames',{'node','active_e_rad'}),fullfile(path,'runtime_512.csv'));
save(fullfile(path,'primary_luts.mat'),'state','runtime','-v7.3');
end

function complete=local_complete(options,matrix,p64,p128,diagnostics,pairs,drift,sensitivity,stop)
complete=strcmp(options.mode,'full') && ~stop.triggered && numel(p64)==8 && ...
    numel(p128)==8 && numel(diagnostics)==16 && numel(pairs)== ...
    numel(matrix.profile_freeze)+numel(matrix.validation) && numel(drift)==8 && ...
    numel(sensitivity)==10;
end

function local_write_outputs(outDir,result,gate,p64,p128,diag,pairs,drift,sensitivity)
write_json_file(fullfile(outDir,'gate.json'),gate);
write_json_file(fullfile(outDir,'result.json'),result);
rows=repmat(local_row(),0,1);
for v={p64,p128,diag}
    for k=1:numel(v{1})
        rows(end+1,1)=local_profile_row(v{1}(k)); %#ok<AGROW>
    end
end
for k=1:numel(pairs), rows(end+1,1)=local_pair_row(pairs(k)); end %#ok<AGROW>
for k=1:numel(drift), rows(end+1,1)=local_drift_row(drift(k)); end %#ok<AGROW>
for k=1:numel(sensitivity), rows(end+1,1)=local_sensitivity_row(sensitivity(k)); end %#ok<AGROW>
writetable(struct2table(rows),fullfile(outDir,'metrics.csv'));
failures=local_failed_checks(gate); local_mkdir(fullfile(outDir,'failures'));
write_json_file(fullfile(outDir,'failures','gate_failures.json'),failures);
local_write_text(fullfile(outDir,'failures','gate_failures.txt'),strjoin(failures,newline));
end

function gate=local_gate(status,complete,checks,aggregate,cfg,stop,errors)
gate=struct('schema_version','angle-lut-stage3-gate-v1', ...
    'gate_contract_version',cfg.gates.schema_version,'status',status, ...
    'scope',ternary(complete,'FULL_STAGE3','BOUNDED_OR_PARTIAL_STAGE3'), ...
    'checks',checks,'thresholds',cfg.gates.stage3,'aggregate',aggregate, ...
    'critical_early_stop',stop,'errors',{cellstr(errors)});
end

function failed=local_failed_checks(gate)
failed=strings(0,1);
if ~isfield(gate,'checks'), failed="checks_unavailable"; return; end
names=fieldnames(gate.checks);
for k=1:numel(names)
    value=gate.checks.(names{k});
    if islogical(value) && isscalar(value) && ~value
        failed(end+1,1)=string(names{k}); %#ok<AGROW>
    elseif isstruct(value)
        sub=fieldnames(value);
        for j=1:numel(sub)
            if islogical(value.(sub{j})) && ~value.(sub{j})
                failed(end+1,1)=string(names{k})+"."+string(sub{j}); %#ok<AGROW>
            end
        end
    end
end
end

function [passed,summary]=local_run_tests(cfg,outDir,enabled)
if ~enabled
    t=table(string.empty(0,1),false(0,1),false(0,1),false(0,1),zeros(0,1), ...
        'VariableNames',{'Name','Passed','Failed','Incomplete','Duration'});
    writetable(t,fullfile(outDir,'tests.csv')); passed=true;
    summary=struct('passed',false,'skipped',true,'count',0,'failed',0,'incomplete',0);
    return;
end
v=runtests(fullfile(cfg.project_root,'tests'),'IncludeSubfolders',true);
t=table(string({v.Name}).',logical([v.Passed].'),logical([v.Failed].'), ...
    logical([v.Incomplete].'),double([v.Duration].'),'VariableNames', ...
    {'Name','Passed','Failed','Incomplete','Duration'});
writetable(t,fullfile(outDir,'tests.csv'));
passed=all(t.Passed & ~t.Failed & ~t.Incomplete);
summary=struct('passed',passed,'skipped',false,'count',height(t), ...
    'failed',nnz(t.Failed),'incomplete',nnz(t.Incomplete));
end

function local_guard_hashes(cfg,a,b,c)
assert(strcmpi(a,file_sha256(cfg.source_model)),'anglelut:SourceHashChanged');
assert(strcmpi(b,file_sha256(cfg.harness_model)),'anglelut:Stage1HarnessHashChanged');
assert(strcmpi(c,file_sha256(cfg.project.stage2_harness_model)), ...
    'anglelut:Stage2HarnessHashChanged');
end

function values=local_select(values,requested,maximum)
if isempty(requested) || all(strlength(string(requested))==0)
    values=values(1:min(numel(values),maximum));
    return;
end
requested=string(requested); selected=values([]); ids=string({values.case_id});
for id=requested(:).'
    i=find(ids==id,1); assert(~isempty(i),'anglelut:Stage3UnknownCase','Unknown %s.',id);
    selected(end+1)=values(i); %#ok<AGROW>
end
assert(numel(selected)<=maximum,'anglelut:Stage3CaseLimit'); values=selected;
end
function c=local_override_stop(c,value)
if ~isempty(value), c.stop_time_s=value; end
end
function value=local_circular_rms(x)
x=anglelut.wrap_to_pi(double(x(:))); value=sqrt(mean(x.^2));
end

function out=local_profile()
out=struct('case_id','','phase','','status','','elapsed_s',NaN,'nodes',NaN, ...
    'amplitude_mode','','sample_count',NaN,'accepted_count',NaN, ...
    'effective_weight',NaN,'coverage_fraction',NaN, ...
    'reference_coverage_fraction',NaN,'fusion_count',NaN, ...
    'total_abs_travel_m_rad',NaN,'mechanical_revolutions',NaN, ...
    'shadow_rmse_e_rad',NaN,'shadow_rmse_e_deg',NaN, ...
    'active_rmse_e_rad',NaN,'active_rmse_e_deg',NaN, ...
    'baseline_rmse_e_rad',NaN,'baseline_rmse_e_deg',NaN, ...
    'active_max_error_e_rad',NaN,'active_max_error_e_deg',NaN, ...
    'active_improvement_fraction',NaN,'last_active_update_rms_e_rad',NaN, ...
    'previous_active_update_rms_e_rad',NaN,'active_max_abs_e_rad',NaN, ...
    'minimum_monotonic_margin',NaN,'all_nodes_valid',false, ...
    'finite_state',false,'tangent_rms',NaN,'radial_rms',NaN, ...
    'normalized_step_rms_e_rad',NaN,'max_local_step_e_rad',NaN, ...
    'amplitude_constraint_satisfied',false,'monotonic_constraint_satisfied',false, ...
    'scheme4_shadow_difference_e_rad',NaN,'scheme4_active_difference_e_rad',NaN);
end
function out=local_normalize_profile(input)
out=local_profile(); n=fieldnames(input); for k=1:numel(n), out.(n{k})=input.(n{k}); end
end
function out=local_pair()
blank=struct('case_id','','active_enable',false,'expected_class','', ...
    'sample_count',NaN,'control_angle_rmse_e_rad',NaN, ...
    'control_angle_rmse_e_deg',NaN,'id_rms_A',NaN,'iq_tracking_rmse_A',NaN, ...
    'prediction_residual_rms_A',NaN,'mean_torque_Nm',NaN, ...
    'torque_ripple_rms_Nm',NaN,'compensation_rms_e_rad',NaN, ...
    'compensation_max_abs_e_rad',NaN,'elapsed_s',NaN);
out=struct('case_id','','expected_class','','baseline',blank,'active',blank, ...
    'control_angle_improvement',NaN,'id_rms_improvement',NaN, ...
    'prediction_residual_improvement',NaN,'torque_ripple_improvement',NaN, ...
    'iq_tracking_change',NaN,'mean_torque_change',NaN,'profile_source_id','', ...
    'control_angle_gate_basis','','control_angle_gate_details',struct());
end
function out=local_normalize_pair(input)
out=local_pair(); n=fieldnames(input); for k=1:numel(n), out.(n{k})=input.(n{k}); end
end
function out=local_drift()
out=struct('case_id','','lut_drift_e_rad',NaN,'lut_drift_e_deg',NaN, ...
    'coverage_fraction',NaN,'fusion_count',NaN);
end
function out=local_sensitivity()
out=struct('case_id','','tangent_rms',NaN,'radial_rms',NaN, ...
    'lut_drift_e_rad',NaN,'valid_fraction',NaN,'finite_diagnostics',false);
end
function out=local_result(id,path)
out=struct('run_id',char(id),'final_status','','prerequisite_stage2',struct(), ...
    'training_results',repmat(local_profile(),0,1), ...
    'amplitude_mode_results',repmat(local_profile(),0,1), ...
    'scheme4_comparison',repmat(local_scheme4_item(),0,1), ...
    'node_scan',repmat(local_profile(),0,1),'frozen_cases',repmat(local_pair(),0,1), ...
    'sensitivity_results',repmat(local_sensitivity(),0,1), ...
    'condition_drift',repmat(local_drift(),0,1),'result_path',path);
end
function values=local_scheme4_summary(profiles)
values=repmat(local_scheme4_item(),numel(profiles),1);
for k=1:numel(profiles)
    values(k).case_id=profiles(k).case_id;
    values(k).shadow_circular_rms_difference_e_rad= ...
        profiles(k).scheme4_shadow_difference_e_rad;
    values(k).active_circular_rms_difference_e_rad= ...
        profiles(k).scheme4_active_difference_e_rad;
end
end
function out=local_scheme4_item()
out=struct('case_id','','shadow_circular_rms_difference_e_rad',NaN, ...
    'active_circular_rms_difference_e_rad',NaN);
end
function out=local_row()
out=struct('phase','','case_id','','amplitude_mode','','nodes',NaN, ...
    'coverage_fraction',NaN,'fusion_count',NaN,'shadow_rmse_e_deg',NaN, ...
    'active_rmse_e_deg',NaN,'active_improvement_fraction',NaN, ...
    'scheme4_shadow_difference_e_deg',NaN,'scheme4_active_difference_e_deg',NaN, ...
    'control_angle_improvement',NaN,'control_angle_gate_basis','', ...
    'id_rms_improvement',NaN,'prediction_residual_improvement',NaN, ...
    'torque_ripple_improvement',NaN,'iq_tracking_change',NaN, ...
    'mean_torque_change',NaN,'lut_drift_e_deg',NaN,'tangent_rms',NaN, ...
    'radial_rms',NaN,'valid_fraction',NaN);
end
function r=local_profile_row(p)
r=local_row(); r.phase=p.phase; r.case_id=p.case_id; r.amplitude_mode=p.amplitude_mode;
r.nodes=p.nodes; r.coverage_fraction=p.coverage_fraction; r.fusion_count=p.fusion_count;
r.shadow_rmse_e_deg=p.shadow_rmse_e_deg; r.active_rmse_e_deg=p.active_rmse_e_deg;
r.active_improvement_fraction=p.active_improvement_fraction;
r.scheme4_shadow_difference_e_deg=rad2deg(p.scheme4_shadow_difference_e_rad);
r.scheme4_active_difference_e_deg=rad2deg(p.scheme4_active_difference_e_rad);
r.tangent_rms=p.tangent_rms; r.radial_rms=p.radial_rms;
end
function r=local_pair_row(p)
r=local_row(); r.phase='FROZEN_PAIR'; r.case_id=p.case_id;
r.control_angle_improvement=p.control_angle_improvement;
r.control_angle_gate_basis=p.control_angle_gate_basis;
r.id_rms_improvement=p.id_rms_improvement; r.prediction_residual_improvement=p.prediction_residual_improvement;
r.torque_ripple_improvement=p.torque_ripple_improvement; r.iq_tracking_change=p.iq_tracking_change;
r.mean_torque_change=p.mean_torque_change;
end
function r=local_drift_row(d)
r=local_row(); r.phase='CONDITION_DRIFT'; r.case_id=d.case_id;
r.coverage_fraction=d.coverage_fraction; r.fusion_count=d.fusion_count;
r.lut_drift_e_deg=d.lut_drift_e_deg;
end
function r=local_sensitivity_row(s)
r=local_row(); r.phase='SENSITIVITY'; r.case_id=s.case_id;
r.tangent_rms=s.tangent_rms; r.radial_rms=s.radial_rms;
r.valid_fraction=s.valid_fraction; r.lut_drift_e_deg=rad2deg(s.lut_drift_e_rad);
end
function stop=local_stop(stop,phase,id,reason)
if ~stop.triggered, stop.triggered=true; stop.phase=phase; stop.case_id=id; stop.reason=reason; end
end
function value=local_scope(options)
value=ternary(strcmp(options.mode,'full'),'FULL_STAGE3','BOUNDED_OR_PARTIAL_STAGE3');
end
function local_mkdir(path)
if ~isfolder(path), mkdir(path); end
end
function local_write_text(path,value)
fid=fopen(path,'w','n','UTF-8'); assert(fid>=0,'anglelut:IO','Cannot open %s.',path);
cleanup=onCleanup(@()fclose(fid)); fprintf(fid,'%s\n',value);
end
function value=local_iso_time()
value=char(datetime('now','TimeZone','UTC','Format','yyyy-MM-dd''T''HH:mm:ss.SSS''Z'''));
end
function value=ternary(condition,a,b)
if condition, value=a; else, value=b; end
end
