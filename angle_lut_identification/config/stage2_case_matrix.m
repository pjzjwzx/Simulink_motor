function matrix = stage2_case_matrix(cfg)
%STAGE2_CASE_MATRIX Explicit learning and frozen-validation identities.

if nargin < 1
    cfg = stage2_config();
end
stage1Cases = case_matrix(cfg);
ids = string({stage1Cases.case_id});

trainingIds = ["fixed_00deg_e", "fixed_05deg_e", ...
    "fixed_10deg_e", "fixed_20deg_e", "periodic_constant", ...
    "periodic_1x", "periodic_2x", "periodic_combined"];
training = stage1Cases(ismember(ids,trainingIds));
training = local_order(training,trainingIds);
for k = 1:numel(training)
    training(k).omega_m_radps = cfg.stage2.training_speed_m_radps;
    training(k).load_torque_Nm = cfg.stage2.training_load_torque_Nm;
    training(k).angle_sample_Hz = cfg.timing.angle_sync_sample_Hz;
    training(k).angle_extrapolation_enabled = false;
    training(k).stop_time_s = local_stop_time(cfg, ...
        training(k).omega_m_radps,cfg.stage2.training_mechanical_cycles);
end

validationIds = ["speed_-20radps_m", "speed_-10radps_m", ...
    "speed_-05radps_m", "speed_+05radps_m", "speed_+10radps_m", ...
    "speed_+20radps_m", "load_0Nm", "load_2Nm", ...
    "mismatch_Rs_-10percent", "mismatch_Rs_+10percent", ...
    "mismatch_Ls_-10percent", "mismatch_Ls_+10percent", ...
    "mismatch_psi_-10percent", "mismatch_psi_+10percent", ...
    "angle_timestamped_1kHz", "nonideal_angle_noise", ...
    "nonideal_current_noise", "nonideal_deadtime", ...
    "nonideal_min_pulse", "nonideal_voltage_drop", ...
    "nonideal_delay_5us", "nonideal_delay_50us", ...
    "nonideal_combined"];
validation = stage1Cases(ismember(ids,validationIds));
validation = local_order(validation,validationIds);
for k = 1:numel(validation)
    validation(k).stop_time_s = local_stop_time(cfg, ...
        validation(k).omega_m_radps,cfg.stage2.frozen_mechanical_cycles);
    validation(k).stage2_expected_class = local_stage2_class(validation(k));
    validation(k).vdc_override_V = cfg.motor.vdc_nominal_V;
end

saturation = validation(find(string({validation.case_id}) == ...
    "speed_+20radps_m",1));
saturation.case_id = "stage2_pwm_saturation";
saturation.group = "stage2_saturation";
saturation.omega_m_radps = 20;
saturation.load_torque_Nm = 2;
saturation.vdc_override_V = 18;
saturation.stage2_expected_class = "saturation_diagnostic";
saturation.stop_time_s = local_stop_time(cfg,saturation.omega_m_radps, ...
    cfg.stage2.frozen_mechanical_cycles);
validation(end+1) = saturation;

matrix.schema_version = "stage2-case-matrix-v1";
matrix.training = training;
matrix.profile_freeze = training;
for k = 1:numel(matrix.profile_freeze)
    matrix.profile_freeze(k).stop_time_s = local_stop_time(cfg, ...
        matrix.profile_freeze(k).omega_m_radps, ...
        cfg.stage2.frozen_mechanical_cycles);
end
matrix.validation = validation;
matrix.node_scan = cfg.stage2.scan_nodes;
matrix.primary_profile_id = cfg.stage2.primary_profile_id;

allIds = ["learn_" + string({training.case_id}), ...
    "profile_" + string({matrix.profile_freeze.case_id}), ...
    "freeze_" + string({validation.case_id})];
assert(numel(unique(allIds)) == numel(allIds), ...
    'anglelut:Stage2DuplicateCaseId', ...
    'Stage-2 case identities must be unique within each phase.');
end

function ordered = local_order(values,ids)
ordered = values([]);
valueIds = string({values.case_id});
for k = 1:numel(ids)
    index = find(valueIds == ids(k),1);
    assert(~isempty(index),'anglelut:Stage2MissingStage1Case', ...
        'Stage-1 case %s is required by Stage 2.',ids(k));
    ordered(end+1) = values(index); %#ok<AGROW>
end
end

function value = local_stage2_class(c)
if c.group == "nonideal" || c.group == "parameter_mismatch" || ...
        c.group == "angle_sampling"
    value = "nonideal";
else
    value = "ideal";
end
end

function t = local_stop_time(cfg,omegaM,cycles)
t = cfg.simulation.steady_state_time_s + max( ...
    cfg.simulation.minimum_evaluation_time_s,2*pi*cycles/abs(omegaM)) + ...
    cfg.simulation.identification_flush_margin_s;
end
