function [metrics, trace, implementation] = analyze_stage1_case(simOut, caseCfg, cfg)
%ANALYZE_STAGE1_CASE Build the Stage-1 identification stream and metrics.
%   Only stage1_* observer signals enter this function.  Plant truth is
%   used after the deployment residual has been evaluated, solely for
%   acceptance metrics and the independent voltage A/B comparison.

required = { ...
    'stage1_iabc_meas', 'stage1_duty_applied', 'stage1_vdc', ...
    'stage1_theta_m_raw', 'stage1_theta_m_true', ...
    'stage1_theta_e_true', 'stage1_omega_m_true', ...
    'stage1_encoder_error_m', ...
    'stage1_vabc_plant', 'stage1_iq_ref', 'stage1_overmod_flag', ...
    'stage1_min_pulse_flag', 'stage1_timestamp_s', 'stage1_valid'};
for k = 1:numel(required)
    assert(any(strcmp(simOut.who, required{k})), ...
        'anglelut:MissingStage1Log', 'Missing observer log %s.', required{k});
end

timestampLog = simOut.get('stage1_timestamp_s');
eventTime_s = double(timestampLog.Time(:));
timestampData_s = local_sample(simOut, 'stage1_timestamp_s', eventTime_s, 'previous');
if ~isempty(timestampData_s) && all(isfinite(timestampData_s(:)))
    eventTime_s = double(timestampData_s(:,1));
end
assert(numel(eventTime_s) >= 3, 'anglelut:TooFewSamples', ...
    'Stage 1 requires at least three identification events.');

boundaryTime_s = eventTime_s - cfg.timing.identification_event_offset_s;
extraDelay_s = double(caseCfg.extra_sensor_delay_s);

% One IdentificationBus record must describe one physical PWM boundary.
% Observer samples are logged at boundary + identification phase.  A
% requested latency therefore moves the complete record to an earlier
% representative boundary; it must not move only current/angle while
% leaving duty, Vdc and validity flags at the undelayed interval.
representativeTime_s = boundaryTime_s - extraDelay_s;
logQueryTime_s = eventTime_s - extraDelay_s;

% IdentificationBus candidates.  Extra latency is represented as a pure
% timestamped signal shift in analysis; the model sample time is untouched.
% Current and wrapped angle are boundary values, so they use fractional
% interpolation at the representative boundary.  Duty, Vdc and their
% interval flags instead describe the complete following PWM interval.  A
% fractional delay makes that interval straddle two nominal PWM intervals,
% so use an exact zero-order-held interval average rather than selecting
% only the value at its start.  Sampling the nominal event records with
% linear interpolation also avoids an interp1('previous') one-interval
% slip when an integer-delay query lies a few ulps below an event time.
iabc_A = local_sample(simOut, 'stage1_iabc_meas', logQueryTime_s, 'linear');
theta_m_raw_rad = local_sample_angle(simOut, 'stage1_theta_m_raw', ...
    logQueryTime_s);

dutyEvent = local_sample(simOut, 'stage1_duty_applied', eventTime_s, 'linear');
vdcEvent_V = local_sample(simOut, 'stage1_vdc', eventTime_s, 'linear');
overmodEvent = local_sample(simOut, 'stage1_overmod_flag', ...
    eventTime_s, 'linear') > 0.5;
minPulseEvent = local_sample(simOut, 'stage1_min_pulse_flag', ...
    eventTime_s, 'linear') > 0.5;
adcValidEvent = local_sample(simOut, 'stage1_valid', ...
    eventTime_s, 'linear') > 0.5;

dutyEvent = local_three_columns(dutyEvent, 'stage1_duty_applied');
vdcEvent_V = double(vdcEvent_V(:,1));
[vdc_V, intervalSupport] = anglelut.interval_average( ...
    vdcEvent_V, extraDelay_s, cfg.timing.T_ident_s);
vdcDutyAverage = anglelut.interval_average( ...
    bsxfun(@times, vdcEvent_V, dutyEvent), ...
    extraDelay_s, cfg.timing.T_ident_s);
% Preserve the exact interval-average phase voltage even if Vdc varies:
% Vdc_avg*duty_equiv = average(Vdc*duty).  Common-mode removal in
% reconstruct_voltage then yields average[Vdc*(duty-mean(duty))].
duty_abc = bsxfun(@rdivide, vdcDutyAverage, vdc_V);

overmodFraction = anglelut.interval_average(double(overmodEvent(:,1)), ...
    extraDelay_s, cfg.timing.T_ident_s);
minPulseFraction = anglelut.interval_average(double(minPulseEvent(:,1)), ...
    extraDelay_s, cfg.timing.T_ident_s);
adcValidFraction = anglelut.interval_average(double(adcValidEvent(:,1)), ...
    extraDelay_s, cfg.timing.T_ident_s);
overmodulated = overmodFraction > 0;
min_pulse_clipped = minPulseFraction > 0;
adc_valid = intervalSupport.valid & ...
    adcValidFraction >= 1 - 64*eps;

iq_ref_A = local_sample(simOut, 'stage1_iq_ref', logQueryTime_s, 'linear');

iabc_A = local_three_columns(iabc_A, 'stage1_iabc_meas');
duty_abc = local_three_columns(duty_abc, 'stage1_duty_applied');
vdc_V = double(vdc_V(:,1));
theta_m_raw_rad = double(theta_m_raw_rad(:,1));
iq_ref_A = double(iq_ref_A(:,1));
overmodulated = logical(overmodulated(:,1));
min_pulse_clipped = logical(min_pulse_clipped(:,1));
adc_valid = logical(adc_valid(:,1));
n = numel(eventTime_s);
assert(all([size(iabc_A,1), size(duty_abc,1), numel(vdc_V), ...
    numel(theta_m_raw_rad)] == n), 'anglelut:LogLengthMismatch', ...
    'Observer log lengths do not agree.');

implementation = struct();
implementation.encoder_angle_noise = local_mode(caseCfg.angle_noise_std_m_rad > 0, ...
    'harness_forward_model', 'disabled');
implementation.current_noise = local_mode(caseCfg.current_noise_std_A > 0, ...
    'harness_measurement_path', 'disabled');
implementation.deadtime = local_mode(caseCfg.deadtime_s > 0, ...
    'harness_plant_duty_path', 'disabled');
implementation.minimum_pulse = local_mode(caseCfg.min_pulse_duty > 0, ...
    'harness_plant_duty_path', 'disabled');
implementation.inverter_voltage_drop = local_mode(caseCfg.inverter_voltage_drop_V > 0, ...
    'harness_plant_voltage_path', 'disabled');
implementation.extra_sensor_delay = local_mode(caseCfg.extra_sensor_delay_s > 0, ...
    'common_record_shift_with_interval_zoh_average', 'disabled');
implementation.delay_whole_intervals = intervalSupport.whole_intervals;
implementation.delay_previous_interval_fraction = ...
    intervalSupport.previous_fraction;
implementation.delay_current_interval_fraction = ...
    intervalSupport.current_fraction;
implementation.angle_timestamp_extrapolation = local_mode( ...
    caseCfg.angle_extrapolation_enabled, 'deployment_analysis_path', 'disabled');
implementation.note = ['Electrical nonidealities and current noise are applied ' ...
    'inside the copied harness. Requested extra sensor delay shifts current, ' ...
    'raw angle and timestamps to one common representative boundary; effective ' ...
    'duty, Vdc and flags are averaged over its complete following PWM interval.'];

% The logged duty is the interval-effective duty that also drives the
% copied plant.  Logged current noise and plant voltage are likewise
% already physical harness outputs; do not inject them a second time.
duty_effective = duty_abc;

% Raw-mechanical-angle-only speed path.  Sensor timestamps repeat at the
% configured encoder rate.  No EvaluationTruthBus speed enters this path.
speedCfg = cfg;
speedCfg.encoder.sample_Hz = double(caseCfg.angle_sample_Hz);
speedState = anglelut.init_speed_estimator_state();
directionState = int8(0);
theta_m_unwrapped_rad = zeros(n,1);
theta_m_analysis_rad = zeros(n,1);
omega_m_est_radps = zeros(n,1);
omega_e_est_radps = zeros(n,1);
direction_sign = zeros(n,1,'int8');
direction_valid = false(n,1);
encoder_valid = isfinite(theta_m_raw_rad);

anglePeriod_s = 1 / double(caseCfg.angle_sample_Hz);
isSynchronousAngle = double(caseCfg.angle_sample_Hz) >= ...
    (1 / cfg.timing.T_ident_s) * (1 - 32*eps);
if isSynchronousAngle
    % Fractional-delay interpolation produces an angle at the common
    % representative time, rather than at an older encoder event.
    angleTimestamp_s = representativeTime_s;
else
    angleTimestamp_s = floor((representativeTime_s + ...
        16*eps(max(1,abs(representativeTime_s)))) ./ anglePeriod_s) .* ...
        anglePeriod_s;
end
for k = 1:n
    [speedOut, speedState] = anglelut.estimate_speed_step( ...
        theta_m_raw_rad(k), angleTimestamp_s(k), speedState, speedCfg);
    encoder_valid(k) = encoder_valid(k) && speedState.initialized;
    theta_m_unwrapped_rad(k) = speedOut.theta_m_unwrapped_rad;
    omega_m_est_radps(k) = speedOut.omega_m_radps;
    omega_e_est_radps(k) = speedOut.omega_e_est_radps;
    [direction_sign(k), directionState, dirOK, transitioned] = ...
        anglelut.direction_hysteresis(omega_e_est_radps(k), directionState, cfg);
    direction_valid(k) = dirOK && ~transitioned;

    thetaUsed = speedOut.theta_m_unwrapped_rad;
    if caseCfg.angle_extrapolation_enabled && speedState.initialized
        age_s = max(0, representativeTime_s(k) - angleTimestamp_s(k));
        thetaUsed = thetaUsed + speedOut.omega_m_radps * age_s;
    end
    theta_m_analysis_rad(k) = thetaUsed;
end

theta_e_raw_rad = cfg.motor.pole_pairs .* theta_m_analysis_rad ...
    + double(caseCfg.theta0_e_rad);

% Base latency is aligned by the +5-us identification phase. A requested
% extra delay moves all deployment-side representative timestamps together.
measurementTimestamp_s = representativeTime_s;
if caseCfg.angle_extrapolation_enabled
    effectiveAngleTimestamp_s = representativeTime_s;
else
    effectiveAngleTimestamp_s = angleTimestamp_s;
end

% FORMAL_IDENTIFICATION_BUS_ASSEMBLED_BEFORE_RESIDUAL
% This is the complete deployment-side Stage-1 interface.  From this point
% through the residual loop, deployment computation reads only this struct;
% raw observer arrays are not captured by the sample adapter.
identificationBus = struct( ...
    'iabc_A',iabc_A, ...
    'duty_abc',duty_effective, ...
    'vdc_V',vdc_V, ...
    'theta_m_raw_rad',theta_m_raw_rad, ...
    'theta_m_unwrapped_rad',theta_m_unwrapped_rad, ...
    'theta_e_rad',theta_e_raw_rad, ...
    'omega_e_radps',omega_e_est_radps, ...
    'adc_valid',adc_valid & all(isfinite(iabc_A),2), ...
    'encoder_valid',encoder_valid & isfinite(theta_e_raw_rad), ...
    'pwm_saturated',overmodulated, ...
    'pwm_overmodulated',overmodulated, ...
    'min_pulse_clipped',min_pulse_clipped, ...
    'current_limited',isfinite(iq_ref_A) & ...
        abs(iq_ref_A) >= cfg.motor.iq_limit_A - 10*eps(cfg.motor.iq_limit_A), ...
    'direction_sign',direction_sign, ...
    'direction_valid',direction_valid, ...
    'timestamp_s',representativeTime_s, ...
    'current_timestamp_s',measurementTimestamp_s, ...
    'voltage_timestamp_s',representativeTime_s, ...
    'angle_timestamp_s',effectiveAngleTimestamp_s, ...
    'angle_age_s',max(0,representativeTime_s-angleTimestamp_s));
local_assert_bus_schema(identificationBus,'IdentificationBus');

z_euler_rad = zeros(n-1,1);
z_rk2_rad = zeros(n-1,1);
z_heun_rad = zeros(n-1,1);
residual_A = zeros(n-1,2);
y_A = zeros(n-1,2);
residualAmplitude_A = zeros(n-1,1);
expectedAmplitude_A = zeros(n-1,1);
qualityWeight = zeros(n-1,1);
valid = false(n-1,1);
timestampOK = false(n-1,1);
residualRatioOK = false(n-1,1);
vabc_reconstructed_V = zeros(n-1,3);
gateTrace = struct( ...
    'speed_ok',false(n-1,1), ...
    'direction_ok',false(n-1,1), ...
    'pwm_ok',false(n-1,1), ...
    'adc_ok',false(n-1,1), ...
    'encoder_ok',false(n-1,1), ...
    'current_limit_ok',false(n-1,1), ...
    'vdc_ok',false(n-1,1), ...
    'timestamp_ok',false(n-1,1), ...
    'residual_ratio_ok',false(n-1,1), ...
    'signals_finite',false(n-1,1), ...
    'valid',false(n-1,1), ...
    'residual_ratio',NaN(n-1,1), ...
    'speed_weight',zeros(n-1,1), ...
    'amplitude_weight',zeros(n-1,1), ...
    'quality_weight',zeros(n-1,1));
gateNames = fieldnames(gateTrace);

predictCfg = cfg;
predictCfg.motor.Rs_ohm = cfg.motor.Rs_ohm * double(caseCfg.Rs_scale);
predictCfg.motor.Ls_H = cfg.motor.Ls_H * double(caseCfg.Ls_scale);
predictCfg.motor.psi_f_Wb = cfg.motor.psi_f_Wb * double(caseCfg.psi_f_scale);

% DEPLOYMENT_RESIDUAL_LOOP_USES_FORMAL_IDENTIFICATION_BUS
for k = 1:n-1
    s0 = local_identification_sample(identificationBus,k);
    s1 = local_identification_sample(identificationBus,k+1);
    r = anglelut.physical_residual(s0, s1, predictCfg);
    z_euler_rad(k) = r.euler.z_rad;
    z_rk2_rad(k) = r.rk2.z_rad;
    z_heun_rad(k) = r.heun.z_rad;
    residual_A(k,:) = r.euler.residual_A(:).';
    y_A(k,:) = r.euler.y_A(:).';
    residualAmplitude_A(k) = r.euler.amplitude_A;
    expectedAmplitude_A(k) = r.expected_amplitude_A;
    qualityWeight(k) = r.quality_weight;
    valid(k) = r.valid;
    timestampOK(k) = r.gates.timestamp_ok;
    residualRatioOK(k) = r.gates.residual_ratio_ok;
    vabc_reconstructed_V(k,:) = r.vabc_reconstructed_V(:).';
    for gateIndex = 1:numel(gateNames)
        gateName = gateNames{gateIndex};
        gateTrace.(gateName)(k) = r.gates.(gateName);
    end
end
assert(isequal(gateTrace.valid,valid) && ...
    isequal(gateTrace.timestamp_ok,timestampOK) && ...
    isequal(gateTrace.residual_ratio_ok,residualRatioOK), ...
    'anglelut:GateTraceMismatch', ...
    'Persisted gate diagnostics differ from deployment gate outputs.');

% EvaluationTruthBus is accessed only after the deployment computation.
% The truth electrical angle is wrapped, so ordinary linear interpolation
% across 2*pi would create large false spikes.  Sample it at the observer
% event and propagate backward to the record's representative boundary;
% this operation is evaluation-only and never enters deployment code.
theta_e_true_event_rad = local_sample_angle(simOut, 'stage1_theta_e_true', ...
    eventTime_s(1:end-1));
omega_m_true_event_radps = local_sample(simOut, 'stage1_omega_m_true', ...
    eventTime_s(1:end-1), 'linear');
theta_e_true_event_rad = double(theta_e_true_event_rad(:,1));
omega_m_true_event_radps = double(omega_m_true_event_radps(:,1));
truthPropagation_s = eventTime_s(1:end-1) - ...
    representativeTime_s(1:end-1);
theta_e_true_rad = anglelut.wrap_to_2pi(theta_e_true_event_rad - ...
    cfg.motor.pole_pairs .* omega_m_true_event_radps .* ...
    truthPropagation_s);
truth_error_e_rad = anglelut.wrap_to_pi(theta_e_raw_rad(1:end-1) - theta_e_true_rad);

% Independent evaluation-only plant voltage uses the same representative
% interval support as the deployment reconstruction.  It is intentionally
% assembled after every physical_residual call and is never passed back to
% the estimator or any deployment gate.
vabcPlantEvent_V = local_sample(simOut, 'stage1_vabc_plant', ...
    eventTime_s, 'linear');
vabcPlantEvent_V = local_three_columns(vabcPlantEvent_V, 'stage1_vabc_plant');
vabcPlantAverage_V = anglelut.interval_average(vabcPlantEvent_V, ...
    extraDelay_s, cfg.timing.T_ident_s);
vabc_plant_eval_V = vabcPlantAverage_V(1:end-1,:);

% FORMAL_EVALUATION_TRUTH_BUS_ASSEMBLED_AFTER_RESIDUAL
% Complete EvaluationTruthBus is assembled only after all deployment-safe
% residual samples have been computed.  None of these arrays is passed
% back to the estimator, gates, or physical_residual.
theta_m_true_event_rad = local_sample(simOut, 'stage1_theta_m_true', ...
    eventTime_s(1:end-1), 'linear');
theta_m_true_rad = double(theta_m_true_event_rad(:,1)) - ...
    omega_m_true_event_radps .* truthPropagation_s;
omega_m_true_radps = omega_m_true_event_radps;
injected_error_m_rad = local_sample(simOut, 'stage1_encoder_error_m', ...
    representativeTime_s(1:end-1), 'linear');
injected_error_m_rad = double(injected_error_m_rad(:,1));
plant_vdq_V = zeros(n-1,2);
for k = 1:n-1
    plantAlphaBeta = anglelut.clarke_abc(vabc_plant_eval_V(k,:).');
    plant_vdq_V(k,:) = anglelut.park_alphabeta( ...
        plantAlphaBeta,theta_e_true_rad(k)).';
end
evaluationTruthBus = struct( ...
    'theta_m_true_rad',theta_m_true_rad, ...
    'theta_e_true_rad',theta_e_true_rad, ...
    'omega_m_true_radps',omega_m_true_radps, ...
    'omega_e_true_radps',cfg.motor.pole_pairs.*omega_m_true_radps, ...
    'injected_error_m_rad',injected_error_m_rad, ...
    'injected_error_e_rad',cfg.motor.pole_pairs.*injected_error_m_rad, ...
    'plant_vabc_V',vabc_plant_eval_V, ...
    'plant_vdq_V',plant_vdq_V, ...
    'timestamp_s',representativeTime_s(1:end-1));
local_assert_bus_schema(evaluationTruthBus,'EvaluationTruthBus');

% INDEPENDENT_VOLTAGE_AB_AFTER_DEPLOYMENT_AND_TRUTH_BUS_ASSEMBLY
% The deployment estimator above has already completed using reconstructed
% duty/Vdc voltage. Only now may the evaluation-only plant voltage enter a
% separate residual calculation. The helper copies the deployment valid
% mask and never re-runs gates from plant-derived residuals.
deploymentResult = struct( ...
    'source',"reconstructed_duty_vdc", ...
    'residual_A',residual_A, ...
    'y_A',y_A, ...
    'z_rad',z_euler_rad, ...
    'amplitude_A',residualAmplitude_A, ...
    'valid',valid, ...
    'vabc_reconstructed_V',vabc_reconstructed_V);
voltageAB = evaluate_voltage_ab(identificationBus,deploymentResult, ...
    evaluationTruthBus.plant_vabc_V,predictCfg);
assert(isequal(voltageAB.valid,valid), 'anglelut:VoltageABGateMutation', ...
    'Evaluation-only plant voltage changed the deployment valid mask.');

selectedVoltageSource = string(caseCfg.voltage_source);
assert(isscalar(selectedVoltageSource) && any(selectedVoltageSource == ...
    ["reconstructed","plant_evaluation"]), ...
    'anglelut:VoltageABSource', ...
    'voltage_source must be reconstructed or plant_evaluation.');
selectedVoltageBranch = voltageAB.(char(selectedVoltageSource));
implementation.voltage_ab_evaluator = ...
    'independent_evaluation_only_after_deployment';
implementation.voltage_ab_deployment_source = char(voltageAB.source_a);
implementation.voltage_ab_selected_source = char(selectedVoltageSource);
implementation.voltage_ab_gate_source = char(voltageAB.gate_source);
implementation.voltage_ab_truth_policy = ...
    'truth_error_scores_branches_only; plant voltage never enters gates';

evaluationStart_s = cfg.simulation.steady_state_time_s;
if eventTime_s(end) <= evaluationStart_s
    evaluationStart_s = max(eventTime_s(1), 0.20 * eventTime_s(end));
end
evaluationMask = representativeTime_s(1:end-1) >= evaluationStart_s;
accepted = evaluationMask & valid;

errorEuler_rad = anglelut.wrap_to_pi(z_euler_rad - truth_error_e_rad);
errorRk2_rad = anglelut.wrap_to_pi(z_rk2_rad - truth_error_e_rad);
errorHeun_rad = anglelut.wrap_to_pi(z_heun_rad - truth_error_e_rad);
referenceMean_rad = angle(0.5 .* (exp(1i*z_rk2_rad) + exp(1i*z_heun_rad)));
predictorDelta_rad = anglelut.wrap_to_pi(z_euler_rad - referenceMean_rad);
voltageABReconstructedError_rad = anglelut.wrap_to_pi( ...
    voltageAB.reconstructed.z_rad - truth_error_e_rad);
voltageABPlantError_rad = anglelut.wrap_to_pi( ...
    voltageAB.plant_evaluation.z_rad - truth_error_e_rad);
voltageABSelectedError_rad = anglelut.wrap_to_pi( ...
    selectedVoltageBranch.z_rad - truth_error_e_rad);

metrics = struct();
metrics.case_id = char(caseCfg.case_id);
metrics.group = char(caseCfg.group);
metrics.expected_class = char(caseCfg.expected_class);
metrics.stop_time_s = eventTime_s(end);
metrics.evaluation_start_s = evaluationStart_s;
metrics.sample_count = n - 1;
metrics.evaluation_sample_count = nnz(evaluationMask);
metrics.valid_sample_count = nnz(accepted);
metrics.valid_fraction = nnz(accepted) / max(1, nnz(evaluationMask));
metrics.timestamp_valid_fraction = nnz(timestampOK & evaluationMask) / max(1,nnz(evaluationMask));
metrics.residual_ratio_valid_fraction = nnz(residualRatioOK & evaluationMask) / max(1,nnz(evaluationMask));
metrics.rmse_e_rad = local_rms(errorEuler_rad(accepted));
metrics.rmse_e_deg = rad2deg(metrics.rmse_e_rad);
metrics.rk2_rmse_e_rad = local_rms(errorRk2_rad(accepted));
metrics.heun_rmse_e_rad = local_rms(errorHeun_rad(accepted));
% This is predictor disagreement, not the measured predictor floor.  The
% runner applies the fixed_00deg_e intrinsic-RMSE reference after that
% calibration case has executed.
metrics.predictor_disagreement_e_rad = local_rms(predictorDelta_rad(accepted));
metrics.predictor_disagreement_e_deg = ...
    rad2deg(metrics.predictor_disagreement_e_rad);
metrics.predictor_floor_e_rad = NaN;
metrics.predictor_floor_e_deg = NaN;
metrics.mean_estimation_error_e_rad = local_circular_mean(errorEuler_rad(accepted));
metrics.mean_estimation_error_e_deg = rad2deg(metrics.mean_estimation_error_e_rad);
metrics.mean_estimate_e_rad = local_circular_mean(z_euler_rad(accepted));
metrics.mean_truth_error_e_rad = local_circular_mean(truth_error_e_rad(accepted));
metrics.commanded_fixed_error_e_rad = double(caseCfg.fixed_error_e_rad);
metrics.commanded_fixed_error_e_deg = rad2deg(double(caseCfg.fixed_error_e_rad));
metrics.residual_rms_A = local_rms(residual_A(accepted,:));
metrics.mean_residual_ratio = local_mean(residualAmplitude_A(accepted) ./ ...
    expectedAmplitude_A(accepted));
metrics.voltage_reconstruction_rms_V = local_rms( ...
    voltageAB.delta.vabc_V(evaluationMask,:));
metrics.voltage_ab_independent_evaluation = true;
metrics.voltage_ab_selected_source = char(selectedVoltageSource);
metrics.voltage_ab_gate_source = char(voltageAB.gate_source);
metrics.voltage_ab_selected_branch_rmse_e_rad = ...
    local_rms(voltageABSelectedError_rad(accepted));
metrics.voltage_ab_selected_branch_rmse_e_deg = ...
    rad2deg(metrics.voltage_ab_selected_branch_rmse_e_rad);
metrics.voltage_ab_reconstructed_branch_rmse_e_rad = ...
    local_rms(voltageABReconstructedError_rad(accepted));
metrics.voltage_ab_reconstructed_branch_rmse_e_deg = ...
    rad2deg(metrics.voltage_ab_reconstructed_branch_rmse_e_rad);
metrics.voltage_ab_plant_evaluation_branch_rmse_e_rad = ...
    local_rms(voltageABPlantError_rad(accepted));
metrics.voltage_ab_plant_evaluation_branch_rmse_e_deg = ...
    rad2deg(metrics.voltage_ab_plant_evaluation_branch_rmse_e_rad);
metrics.voltage_ab_pseudo_angle_delta_rms_e_rad = ...
    local_rms(voltageAB.delta.z_rad(accepted));
metrics.voltage_ab_pseudo_angle_delta_rms_e_deg = ...
    rad2deg(metrics.voltage_ab_pseudo_angle_delta_rms_e_rad);
metrics.voltage_ab_pseudo_angle_delta_mean_e_rad = ...
    local_circular_mean(voltageAB.delta.z_rad(accepted));
metrics.voltage_ab_pseudo_angle_delta_mean_e_deg = ...
    rad2deg(metrics.voltage_ab_pseudo_angle_delta_mean_e_rad);
metrics.voltage_ab_residual_delta_rms_A = ...
    local_rms(voltageAB.delta.residual_A(accepted,:));
metrics.voltage_ab_voltage_delta_rms_V = ...
    local_rms(voltageAB.delta.vabc_V(evaluationMask,:));
metrics.voltage_ab_branches_numerically_distinct = ...
    logical(voltageAB.summary.branches_numerically_distinct);
metrics.mean_abs_speed_error_e_radps = NaN; % truth speed is intentionally not read here.
metrics.mechanical_cycles_evaluated = abs(double(caseCfg.omega_m_radps)) * ...
    max(0, eventTime_s(end) - evaluationStart_s) / (2*pi);

trace = struct();
trace.time_s = representativeTime_s(1:end-1);
trace.availability_time_s = eventTime_s(1:end-1);
trace.estimate_e_rad = z_euler_rad;
trace.truth_error_e_rad = truth_error_e_rad;
trace.valid = valid;
trace.evaluation_mask = evaluationMask;
trace.theta_m_raw_rad = theta_m_raw_rad(1:end-1);
trace.theta_m_unwrapped_rad = theta_m_unwrapped_rad(1:end-1);
trace.omega_m_est_radps = omega_m_est_radps(1:end-1);
trace.omega_e_est_radps = omega_e_est_radps(1:end-1);
trace.direction_sign = direction_sign(1:end-1);
trace.residual_A = residual_A;
trace.y_A = y_A;
trace.residual_amplitude_A = residualAmplitude_A;
trace.expected_amplitude_A = expectedAmplitude_A;
trace.z_euler_rad = z_euler_rad;
trace.z_rk2_rad = z_rk2_rad;
trace.z_heun_rad = z_heun_rad;
trace.timestamp_ok = timestampOK;
trace.residual_ratio_ok = residualRatioOK;
trace.gates = gateTrace;
trace.quality_weight = qualityWeight;
trace.vabc_reconstructed_V = vabc_reconstructed_V;
trace.vabc_plant_evaluation_V = vabc_plant_eval_V;
trace.voltage_ab_selected_source = char(selectedVoltageSource);
trace.voltage_ab_selected_estimate_e_rad = selectedVoltageBranch.z_rad;
trace.voltage_ab_selected_error_e_rad = voltageABSelectedError_rad;
trace.voltage_ab = voltageAB;

% Save the same formal interfaces that were used/assembled above; do not
% reconstruct look-alike buses after deployment evaluation.
trace.IdentificationBus = local_bus_rows(identificationBus,1:n-1);
trace.EvaluationTruthBus = evaluationTruthBus;
end

function sample = local_identification_sample(identificationBus,index)
%LOCAL_IDENTIFICATION_SAMPLE Convert one formal bus record for E05-E08.
% The function signature prevents capture of raw observer arrays or truth.
sample = struct();
sample.iabc_A = identificationBus.iabc_A(index,:).';
sample.duty_abc = identificationBus.duty_abc(index,:).';
sample.vdc_V = identificationBus.vdc_V(index);
sample.theta_e_rad = identificationBus.theta_e_rad(index);
sample.omega_e_radps = identificationBus.omega_e_radps(index);
sample.direction_sign = identificationBus.direction_sign(index);
sample.direction_valid = identificationBus.direction_valid(index);
sample.adc_valid = identificationBus.adc_valid(index);
sample.encoder_valid = identificationBus.encoder_valid(index);
sample.pwm_saturated = identificationBus.pwm_saturated(index);
sample.pwm_overmodulated = identificationBus.pwm_overmodulated(index);
sample.min_pulse_clipped = identificationBus.min_pulse_clipped(index);
sample.current_limited = identificationBus.current_limited(index);
sample.timestamp_s = identificationBus.timestamp_s(index);
sample.current_timestamp_s = identificationBus.current_timestamp_s(index);
sample.angle_timestamp_s = identificationBus.angle_timestamp_s(index);
sample.voltage_timestamp_s = identificationBus.voltage_timestamp_s(index);
end

function local_assert_bus_schema(busValue,busName)
defs = bus_definitions(false);
expected = string({defs.(busName).Name}).';
observed = string(fieldnames(busValue));
assert(isequal(observed,expected), 'anglelut:FormalBusSchemaMismatch', ...
    '%s fields differ from config/bus_definitions.m.',busName);
end

function selected = local_bus_rows(busValue,rows)
selected = busValue;
names = fieldnames(busValue);
for k = 1:numel(names)
    data = busValue.(names{k});
    selected.(names{k}) = data(rows,:);
end
end

function values = local_sample(simOut, name, queryTime_s, method)
values = sample_logged_signal(simOut.get(name), queryTime_s, method);
end

function values = local_sample_angle(simOut, name, queryTime_s)
%LOCAL_SAMPLE_ANGLE Fractional-delay interpolation on the unit circle.
% Ordinary linear interpolation of a wrapped angle takes the long path at
% 0/2*pi and creates a false delayed sample.
signal = simOut.get(name);
if isa(signal,'timeseries')
    angleData = double(squeeze(signal.Data));
    angleData = angleData(:);
    phasorSignal = timeseries(exp(1i*angleData),double(signal.Time(:)));
elseif isstruct(signal) && isfield(signal,'time') && isfield(signal,'signals')
    phasorSignal = signal;
    angleData = double(squeeze(signal.signals.values));
    phasorSignal.signals.values = exp(1i*angleData(:));
else
    error('anglelut:LogFormat', ...
        'Unsupported wrapped-angle log class %s.',class(signal));
end
phasor = sample_logged_signal(phasorSignal,queryTime_s,'linear');
values = anglelut.wrap_to_2pi(angle(phasor));
end

function data = local_three_columns(data, name)
data = double(data);
if isvector(data) && numel(data) == 3
    data = reshape(data,1,3);
end
assert(size(data,2) == 3, 'anglelut:LogShape', ...
    '%s must have three columns, got %s.', name, mat2str(size(data)));
end

function value = local_mode(enabled, onValue, offValue)
if enabled
    value = onValue;
else
    value = offValue;
end
end

function value = local_rms(x)
x = double(x(:));
x = x(isfinite(x));
if isempty(x)
    value = NaN;
else
    value = sqrt(mean(x.^2));
end
end

function value = local_mean(x)
x = double(x(:));
x = x(isfinite(x));
if isempty(x), value = NaN; else, value = mean(x); end
end

function value = local_circular_mean(x)
x = double(x(:));
x = x(isfinite(x));
if isempty(x)
    value = NaN;
else
    value = angle(mean(exp(1i*x)));
end
end
