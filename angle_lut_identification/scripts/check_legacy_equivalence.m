function result = check_legacy_equivalence(cfg, outputDir)
%CHECK_LEGACY_EQUIVALENCE Numerically compare source and legacy harness.
%   RESULT = CHECK_LEGACY_EQUIVALENCE(CFG) runs the preserved source model
%   and angle_lut_harness for 0.02 s with the same 2.172724711 rev/s step
%   command and
%   zero load. The harness is forced to LEGACY_ELECTRICAL/error-off with
%   every added inverter/sensor nonideality set to zero. Phase currents,
%   effective duty, mechanical speed, and the controller electrical angle
%   are logged directly from matching block output ports in both models.
%
%   Source-model logging is enabled only on the in-memory diagram. The
%   model is closed without saving, and its SHA256 is checked before and
%   after the comparison.
%
%   CHECK_LEGACY_EQUIVALENCE(CFG, OUTPUTDIR) also writes
%   legacy_equivalence.json and legacy_equivalence_metrics.csv.

if nargin < 1 || isempty(cfg)
    cfg = setup_project();
end
if nargin < 2
    outputDir = '';
end

[sourcePath, harnessPath] = local_model_paths(cfg);
stopTimeS = 0.02;
speedCommandRevPerS = 2.17272471102184;
loadTorqueNm = 0;

result = struct();
result.schema_version = 'legacy-equivalence-v1';
result.status = 'BLOCKED';
result.evidence_level = ...
    'A_NUMERICAL_DUAL_MODEL_RUNTIME_PORT_LOGGING';
result.description = [ ...
    'Direct dual-model comparison at matched block output ports; ' ...
    'source logging is transient and the source model is never saved.'];
result.source_model = sourcePath;
result.harness_model = harnessPath;
result.stop_time_s = stopTimeS;
result.common_input = struct( ...
    'speed_step_time_s', 0, ...
    'speed_command_rev_per_s', speedCommandRevPerS, ...
    'load_torque_Nm', loadTorqueNm);
result.harness_mode = struct( ...
    'sensor_mode', uint8(0), ...
    'sensor_mode_name', 'LEGACY_ELECTRICAL', ...
    'encoder_error_mode', uint8(0), ...
    'encoder_error_mode_name', 'off');
result.thresholds = local_thresholds();
result.signals = local_empty_signal_metrics();
result.failure = '';

assert(isfile(sourcePath), 'anglelut:LegacyMissingSource', ...
    'Source model not found: %s', sourcePath);
assert(isfile(harnessPath), 'anglelut:LegacyMissingHarness', ...
    'Harness model not found: %s', harnessPath);

sourceHashBefore = file_sha256(sourcePath);
result.source_sha256_before = sourceHashBefore;

try
    sourceTrace = local_run_and_log(sourcePath, false, ...
        stopTimeS, speedCommandRevPerS, loadTorqueNm);
    harnessTrace = local_run_and_log(harnessPath, true, ...
        stopTimeS, speedCommandRevPerS, loadTorqueNm);
    result.signals = local_compare_traces( ...
        sourceTrace, harnessTrace, result.thresholds);
catch ME
    result.failure = getReport(ME, 'extended', 'hyperlinks', 'off');
end

sourceHashAfter = file_sha256(sourcePath);
result.source_sha256_after = sourceHashAfter;
result.source_unchanged = strcmpi(sourceHashBefore, sourceHashAfter);

if isempty(result.failure)
    signalPass = ~isempty(result.signals) && ...
        all([result.signals.passed]);
    result.all_observables_pass = signalPass;
    if signalPass && result.source_unchanged
        result.status = 'PASS';
    else
        result.status = 'FAIL';
    end
else
    result.all_observables_pass = false;
end

result.gate_passed = strcmp(result.status, 'PASS');
result.completed_utc = char(datetime('now', ...
    'TimeZone', 'UTC', 'Format', 'yyyy-MM-dd''T''HH:mm:ss.SSSXXX'));

if ~isempty(outputDir)
    local_write_outputs(result, outputDir);
end
end

function [sourcePath, harnessPath] = local_model_paths(cfg)
if isfield(cfg, 'source_model')
    sourcePath = char(cfg.source_model);
else
    sourcePath = char(cfg.project.baseline_model);
end
if isfield(cfg, 'harness_model')
    harnessPath = char(cfg.harness_model);
else
    harnessPath = char(cfg.project.harness_model);
end
end

function thresholds = local_thresholds()
thresholds = struct();
thresholds.phase_current_A = 1e-10;
thresholds.duty = 1e-12;
thresholds.mechanical_speed_radps = 1e-10;
thresholds.control_angle_e_rad = 1e-12;
thresholds.time_s = 1e-15;
end

function trace = local_run_and_log(modelPath, isHarness, ...
        stopTimeS, speedCommandRevPerS, loadTorqueNm)
[~, modelName] = fileparts(modelPath);
if bdIsLoaded(modelName)
    close_system(modelName, 0);
end
load_system(modelPath);
cleanupModel = onCleanup(@() local_close_model(modelName));

ports = local_observable_ports(modelName);
restoreState = local_enable_transient_logging(ports);
cleanupLogging = onCleanup(@() ...
    local_restore_logging(restoreState));

speedStep = local_speed_step(modelName);
loadBlock = [modelName '/Constant16'];
assert(getSimulinkBlockHandle(loadBlock) > 0, ...
    'anglelut:LegacyMissingLoadBlock', ...
    'Load-torque block Constant16 is missing in %s.', modelName);

simIn = Simulink.SimulationInput(modelName);
simIn = simIn.setModelParameter( ...
    'StopTime', sprintf('%.17g', stopTimeS), ...
    'SimulationMode', 'normal', ...
    'SignalLogging', 'on', ...
    'SignalLoggingName', 'legacy_equivalence_logsout', ...
    'ReturnWorkspaceOutputs', 'on', ...
    'SaveTime', 'off', 'SaveOutput', 'off', 'SaveState', 'off');
simIn = simIn.setBlockParameter(speedStep, 'Time', '0');
simIn = simIn.setBlockParameter(speedStep, 'Before', '0');
simIn = simIn.setBlockParameter(speedStep, 'After', ...
    sprintf('%.17g', speedCommandRevPerS));
simIn = simIn.setBlockParameter(loadBlock, ...
    'Value', sprintf('%.17g', loadTorqueNm));

if isHarness
    overrides = { ...
        'sensor_mode', uint8(0); ...
        'encoder_error_mode', uint8(0); ...
        'encoder_theta_offset_rad', 0; ...
        'encoder_error_bias_m_rad', 0; ...
        'encoder_error_amp1_m_rad', 0; ...
        'encoder_error_amp2_m_rad', 0; ...
        'theta0_e_rad', 0; ...
        'encoder_noise_std_m_rad', 0; ...
        'stage1_current_noise_std_A', 0; ...
        'pwm_deadtime_s', 0; ...
        'pwm_min_pulse_duty', 0; ...
        'inverter_voltage_drop_V', 0; ...
        'stage1_speed_target_rpm', speedCommandRevPerS; ...
        'stage1_load_torque_Nm', loadTorqueNm};
    for k = 1:size(overrides, 1)
        simIn = simIn.setVariable(overrides{k, 1}, overrides{k, 2}, ...
            'Workspace', modelName);
    end
end

evalc('simOut = sim(simIn);');
logs = simOut.get('legacy_equivalence_logsout');
assert(isa(logs, 'Simulink.SimulationData.Dataset'), ...
    'anglelut:LegacyNoSignalLog', ...
    'Signal log was not returned by %s.', modelName);

ids = fieldnames(ports);
trace = struct();
for k = 1:numel(ids)
    id = ids{k};
    signal = logs.getElement(id);
    assert(~isempty(signal), 'anglelut:LegacyMissingLoggedSignal', ...
        'Logged signal %s is missing from %s.', id, modelName);
    [trace.(id).time, trace.(id).data] = ...
        local_timeseries_matrix(signal.Values);
end
end

function ports = local_observable_ports(modelName)
ports = struct();
ports.phase_current_a_A = local_outport( ...
    [modelName '/Current_Sensing_ADC_Latency_Ia'], 1);
ports.phase_current_b_A = local_outport( ...
    [modelName '/Current_Sensing_ADC_Latency_Ib'], 1);
ports.phase_current_c_A = local_outport( ...
    [modelName '/Current_Sensing_ADC_Latency_Ic'], 1);
ports.duty_abc = local_outport([modelName '/PWM_and_Actuation'], 1);

busSelectors = find_system(modelName, 'SearchDepth', 1, ...
    'BlockType', 'BusSelector');
assert(isscalar(busSelectors), ...
    'anglelut:LegacyAmbiguousMotorBus', ...
    'Expected one top-level motor Bus Selector in %s.', modelName);
ports.mechanical_speed_radps = local_outport(busSelectors{1}, 1);
ports.control_angle_e_rad = local_outport( ...
    [modelName '/Position_Sensing_Encoder_Latency_Theta'], 1);
end

function port = local_outport(block, index)
assert(getSimulinkBlockHandle(block) > 0, ...
    'anglelut:LegacyMissingObservableBlock', ...
    'Observable block is missing: %s', block);
handles = get_param(block, 'PortHandles');
assert(numel(handles.Outport) >= index, ...
    'anglelut:LegacyMissingObservablePort', ...
    'Observable output port %d is missing: %s', index, block);
port = handles.Outport(index);
end

function state = local_enable_transient_logging(ports)
ids = fieldnames(ports);
state = repmat(struct('port', -1, 'DataLogging', '', ...
    'DataLoggingNameMode', '', 'DataLoggingName', ''), numel(ids), 1);
for k = 1:numel(ids)
    port = ports.(ids{k});
    state(k).port = port;
    state(k).DataLogging = get_param(port, 'DataLogging');
    state(k).DataLoggingNameMode = ...
        get_param(port, 'DataLoggingNameMode');
    state(k).DataLoggingName = get_param(port, 'DataLoggingName');
    set_param(port, 'DataLogging', 'on', ...
        'DataLoggingNameMode', 'Custom', ...
        'DataLoggingName', ids{k});
end
end

function local_restore_logging(state)
for k = 1:numel(state)
    try
        set_param(state(k).port, ...
            'DataLogging', state(k).DataLogging, ...
            'DataLoggingNameMode', state(k).DataLoggingNameMode, ...
            'DataLoggingName', state(k).DataLoggingName);
    catch
        % close_system(...,0) below is the final no-save safeguard.
    end
end
end

function speedStep = local_speed_step(modelName)
steps = find_system(modelName, 'SearchDepth', 1, 'BlockType', 'Step');
speedStep = '';
for k = 1:numel(steps)
    ports = get_param(steps{k}, 'PortHandles');
    lineHandle = get_param(ports.Outport, 'Line');
    if lineHandle == -1
        continue;
    end
    destinations = get_param(lineHandle, 'DstBlockHandle');
    for j = 1:numel(destinations)
        if destinations(j) ~= -1 && ...
                contains(get_param(destinations(j), 'Name'), 'Rate Limiter2')
            speedStep = steps{k};
            break;
        end
    end
    if ~isempty(speedStep)
        break;
    end
end
assert(~isempty(speedStep), 'anglelut:LegacyMissingSpeedStep', ...
    'Could not locate the closed-loop speed step in %s.', modelName);
end

function [time, data] = local_timeseries_matrix(values)
assert(isa(values, 'timeseries'), ...
    'anglelut:LegacyUnsupportedLoggedType', ...
    'Expected logged Values to be a timeseries.');
time = double(values.Time(:));
raw = double(values.Data);
n = numel(time);

if n == 0
    data = zeros(0, 1);
elseif isvector(raw) && numel(raw) == n
    data = raw(:);
elseif size(raw, 1) == n
    data = reshape(raw, n, []);
elseif size(raw, ndims(raw)) == n
    order = [ndims(raw), 1:ndims(raw)-1];
    data = reshape(permute(raw, order), n, []);
elseif n == 1
    data = reshape(raw, 1, []);
else
    error('anglelut:LegacyLoggedShapeMismatch', ...
        'Cannot map logged data size %s to %d timestamps.', ...
        mat2str(size(raw)), n);
end
end

function metrics = local_compare_traces(reference, candidate, thresholds)
definitions = { ...
    'phase_current_a_A', 'phase_current_A', false; ...
    'phase_current_b_A', 'phase_current_A', false; ...
    'phase_current_c_A', 'phase_current_A', false; ...
    'duty_abc', 'duty', false; ...
    'mechanical_speed_radps', 'mechanical_speed_radps', false; ...
    'control_angle_e_rad', 'control_angle_e_rad', true};
metrics = repmat(local_empty_signal_metrics(), size(definitions, 1), 1);

for k = 1:size(definitions, 1)
    id = definitions{k, 1};
    thresholdName = definitions{k, 2};
    isCircular = definitions{k, 3};
    a = reference.(id);
    b = candidate.(id);

    sameSamples = numel(a.time) == numel(b.time);
    sameWidth = size(a.data, 2) == size(b.data, 2);
    maxTimeError = inf;
    if sameSamples
        maxTimeError = max(abs(a.time - b.time), [], 'omitnan');
        if isempty(maxTimeError)
            maxTimeError = 0;
        end
    end
    timeAligned = sameSamples && isfinite(maxTimeError) && ...
        maxTimeError <= thresholds.time_s;

    maxAbsError = inf;
    rmsError = inf;
    finiteValues = false;
    if timeAligned && sameWidth && size(a.data, 1) == numel(a.time) && ...
            size(b.data, 1) == numel(b.time)
        delta = b.data - a.data;
        if isCircular
            delta = mod(delta + pi, 2*pi) - pi;
        end
        finiteValues = all(isfinite(a.data), 'all') && ...
            all(isfinite(b.data), 'all') && all(isfinite(delta), 'all');
        if finiteValues
            maxAbsError = max(abs(delta), [], 'all');
            rmsError = sqrt(mean(delta.^2, 'all'));
        end
    end

    tolerance = thresholds.(thresholdName);
    metrics(k).signal = id;
    metrics(k).sample_count_source = numel(a.time);
    metrics(k).sample_count_harness = numel(b.time);
    metrics(k).width_source = size(a.data, 2);
    metrics(k).width_harness = size(b.data, 2);
    metrics(k).max_time_error_s = maxTimeError;
    metrics(k).time_aligned = timeAligned;
    metrics(k).finite = finiteValues;
    metrics(k).max_abs_error = maxAbsError;
    metrics(k).rms_error = rmsError;
    metrics(k).tolerance = tolerance;
    metrics(k).passed = timeAligned && sameWidth && finiteValues && ...
        maxAbsError <= tolerance;
end
end

function metrics = local_empty_signal_metrics()
metrics = struct( ...
    'signal', {}, ...
    'sample_count_source', {}, ...
    'sample_count_harness', {}, ...
    'width_source', {}, ...
    'width_harness', {}, ...
    'max_time_error_s', {}, ...
    'time_aligned', {}, ...
    'finite', {}, ...
    'max_abs_error', {}, ...
    'rms_error', {}, ...
    'tolerance', {}, ...
    'passed', {});
end

function local_write_outputs(result, outputDir)
outputDir = char(outputDir);
if ~isfolder(outputDir)
    mkdir(outputDir);
end
write_json_file(fullfile(outputDir, 'legacy_equivalence.json'), result);
if ~isempty(result.signals)
    writetable(struct2table(result.signals), ...
        fullfile(outputDir, 'legacy_equivalence_metrics.csv'));
end
end

function local_close_model(modelName)
if bdIsLoaded(modelName)
    close_system(modelName, 0);
end
end
