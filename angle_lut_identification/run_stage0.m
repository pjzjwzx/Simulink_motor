function result = run_stage0()
%RUN_STAGE0 Run the mandatory read-only preflight and baseline gate.

cfg = setup_project();
runId = ['stage0_' char(datetime('now','Format','yyyyMMdd_HHmmss_SSS'))];
outDir = fullfile(cfg.project_root, 'results', runId, 'stage0');
if ~exist(outDir, 'dir'), mkdir(outDir); end

result = struct('run_id', runId, 'final_status', 'BLOCKED', ...
    'output_dir', outDir, 'message', '', 'baseline_elapsed_s', NaN);
manifest = struct();
manifest.run_id = runId;
manifest.stage = 0;
createdAt = datetime('now','TimeZone','local', ...
    'Format','yyyy-MM-dd''T''HH:mm:ss.SSSXXX');
manifest.created_at = char(createdAt);
manifest.matlab_version = version;
manifest.model_path = cfg.source_model;
manifest.model_sha256_before = '';
manifest.model_sha256_after = '';
manifest.workspace_is_git = false;

gate = struct('status','BLOCKED','checks',struct(), 'errors',{{}});
mdl = '';
try
    required = {cfg.source_model, cfg.theory_pdf, cfg.implementation_doc};
    gate.checks.required_files = all(cellfun(@(p) exist(p,'file') == 2, required));
    if ~gate.checks.required_files
        error('anglelut:MissingInput','A required source model or specification file is missing.');
    end

    % In this non-Git workspace, a deterministic file inventory replaces
    % the usual commit/diff provenance. Generated results and build caches
    % are excluded by the collector.
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
    gate.checks.file_inventory_written = isfile(inventoryCsv) && ...
        isfile(inventoryJson) && height(inventory) > 0;

    manifest.environment = collect_environment_manifest( ...
        cfg.source_model,cfg.timing);
    gate.checks.environment_manifest_recorded = ...
        ~isempty(manifest.environment.products) && ...
        isfield(manifest.environment,'model') && ...
        isfield(manifest.environment,'powergui');
    manifest.model_sha256_before = file_sha256(cfg.source_model);

    [~, mdl] = fileparts(cfg.source_model);
    load_system(cfg.source_model);
    gate.checks.model_loaded = true;
    gate.checks.solver_preserved = strcmp(get_param(mdl,'SolverType'),'Variable-step') && ...
        strcmp(get_param(mdl,'Solver'),'VariableStepAuto');

    mw = get_param(mdl, 'ModelWorkspace');
    manifest.parameters = struct('pn',mw.evalin('pn'),'Rs',mw.evalin('Rs'), ...
        'Ld',mw.evalin('Ld'),'Lq',mw.evalin('Lq'),'psif',mw.evalin('psif'), ...
        'Ts_base_s',mw.evalin('Ts'),'fpwm_hz',mw.evalin('fpwm'));
    gate.checks.parameters_match = manifest.parameters.pn == 21 && ...
        abs(manifest.parameters.Ts_base_s - 5e-6) < eps && ...
        abs(manifest.parameters.fpwm_hz - 2e4) < eps;

    requiredBlocks = { ...
        [mdl '/PWM_and_Actuation'], ...
        [mdl '/Current_Sensing_ADC_Latency_Ia'], ...
        [mdl '/Current_Sensing_ADC_Latency_Ib'], ...
        [mdl '/Current_Sensing_ADC_Latency_Ic'], ...
        [mdl '/Position_Sensing_Encoder_Latency_Theta'], ...
        [mdl '/Average-Value Inverter'], ...
        [mdl '/Inverter_Nonideal']};
    gate.checks.required_signals = all(cellfun(@(b) getSimulinkBlockHandle(b) > 0, requiredBlocks));

    set_param(mdl, 'SimulationCommand', 'update');
    gate.checks.model_update = true;
    gate.checks.model_clean_after_update = strcmp(get_param(mdl,'Dirty'),'off');

    in = Simulink.SimulationInput(mdl);
    in = in.setModelParameter('StopTime', get_param(mdl,'StopTime'), ...
        'SimulationMode', 'rapid-accelerator', 'ReturnWorkspaceOutputs','on');
    started = tic;
    out = sim(in); %#ok<NASGU>
    result.baseline_elapsed_s = toc(started);
    gate.checks.baseline_simulation = true;

    close_system(mdl, 0);
    mdl = '';
    manifest.model_sha256_after = file_sha256(cfg.source_model);
    gate.checks.source_hash_unchanged = strcmp(manifest.model_sha256_before, manifest.model_sha256_after);
    gate.status = ternary(all(structfun(@logical,gate.checks)), 'PASS', 'FAIL');
catch ME
    gate.errors = {getReport(ME,'extended','hyperlinks','off')};
    if strcmp(ME.identifier,'anglelut:MissingInput')
        gate.status = 'BLOCKED';
    else
        gate.status = 'FAIL';
    end
    if ~isempty(mdl) && bdIsLoaded(mdl), close_system(mdl,0); end
    try
        manifest.model_sha256_after = file_sha256(cfg.source_model);
    catch
    end
end

result.final_status = gate.status;
if isempty(gate.errors), result.message = 'Stage 0 preflight completed.'; else, result.message = gate.errors{1}; end
manifest.final_status = gate.status;
manifest.baseline_elapsed_s = result.baseline_elapsed_s;
write_json_file(fullfile(outDir,'gate.json'), gate);
write_json_file(fullfile(outDir,'run_manifest.json'), manifest);
write_json_file(fullfile(outDir,'result.json'), result);
fid = fopen(fullfile(cfg.project_root,'results','latest_stage0.txt'),'w');
if fid >= 0, fprintf(fid,'%s\n',outDir); fclose(fid); end
end

function out = ternary(condition, yesValue, noValue)
if condition, out = yesValue; else, out = noValue; end
end
