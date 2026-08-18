function out = encoder_forward_model(theta_true_m_rad, cfg)
%ENCODER_FORWARD_MODEL Encoder error and quantization forward model.
%   This simulation-only function deliberately accepts true mechanical
%   angle. It must not be used by deployment residual or gating code.
%
%   CFG may be DEFAULT_CONFIG's full project struct or the following flat
%   fixed-layout subset (all angles in radians):
%     sensor_mode                 uint8(0): LEGACY_ELECTRICAL
%                                 uint8(1): MECHANICAL_STAGE1
%     error_mode                  uint8(0): off, uint8(1): fixed,
%                                 uint8(2): periodic
%     pole_pairs                  motor pole-pair count
%     theta0_e_rad                fixed nominal electrical zero
%     legacy_offset_e_rad         legacy electrical-domain bias
%     fixed_error_e_rad           requested fixed electrical error
%     periodic_bias_m_rad         mechanical periodic-model constant term
%     periodic_amp1_m_rad         mechanical 1x sine amplitude
%     periodic_phase1_rad         mechanical 1x phase
%     periodic_amp2_m_rad         mechanical 2x sine amplitude
%     periodic_phase2_rad         mechanical 2x phase
%     counts_per_rev              encoder counts per mechanical revolution
%     quantization_enabled        logical scalar
%
%   MECHANICAL_STAGE1 order is: true mechanical angle -> injected error ->
%   [0,2*pi) wrap -> mechanical quantization -> pole-pair multiplication.
%   Timestamping and delay are intentionally external stateful operations.

LEGACY_ELECTRICAL = uint8(0);
ERROR_FIXED = uint8(1);
ERROR_PERIODIC = uint8(2);

[sensor_mode, error_mode, p, theta0_e_rad, legacy_offset_e_rad, ...
    fixed_error_e_rad, periodic_bias_m_rad, periodic_amp1_m_rad, ...
    periodic_phase1_rad, periodic_amp2_m_rad, periodic_phase2_rad, ...
    counts_per_rev, quantization_enabled] = resolve_config(cfg);

theta_true_e_rad = p * theta_true_m_rad + theta0_e_rad;
quant_step_rad = 2.0 * pi / counts_per_rev;

if sensor_mode == LEGACY_ELECTRICAL
    % Match the original subsystem domain: bias and one-revolution
    % quantization are applied directly to the electrical angle.
    error_m_rad = legacy_offset_e_rad / p;
    theta_before_wrap_rad = theta_true_e_rad + legacy_offset_e_rad;
    theta_wrapped_rad = anglelut.wrap_to_2pi(theta_before_wrap_rad);

    if quantization_enabled
        encoder_count = mod(floor(theta_wrapped_rad / quant_step_rad + 0.5), ...
                            counts_per_rev);
        theta_e_raw_rad = encoder_count * quant_step_rad;
    else
        encoder_count = theta_wrapped_rad / quant_step_rad;
        theta_e_raw_rad = theta_wrapped_rad;
    end

    theta_m_raw_rad = anglelut.wrap_to_2pi( ...
        (theta_e_raw_rad - theta0_e_rad) / p);
else
    if error_mode == ERROR_FIXED
        error_m_rad = fixed_error_e_rad / p;
    elseif error_mode == ERROR_PERIODIC
        error_m_rad = periodic_bias_m_rad ...
            + periodic_amp1_m_rad * sin(theta_true_m_rad ...
                                        + periodic_phase1_rad) ...
            + periodic_amp2_m_rad * sin(2.0 * theta_true_m_rad ...
                                        + periodic_phase2_rad);
    else
        error_m_rad = 0.0;
    end

    theta_before_wrap_rad = theta_true_m_rad + error_m_rad;
    theta_wrapped_rad = anglelut.wrap_to_2pi(theta_before_wrap_rad);

    if quantization_enabled
        encoder_count = mod(floor(theta_wrapped_rad / quant_step_rad + 0.5), ...
                            counts_per_rev);
        theta_m_raw_rad = encoder_count * quant_step_rad;
    else
        encoder_count = theta_wrapped_rad / quant_step_rad;
        theta_m_raw_rad = theta_wrapped_rad;
    end

    theta_e_raw_rad = p * theta_m_raw_rad + theta0_e_rad;
end

out.theta_true_m_rad = theta_true_m_rad;
out.theta_true_e_rad = theta_true_e_rad;
out.error_m_rad = error_m_rad;
out.error_e_rad = p * error_m_rad;
out.injected_error_m_rad = error_m_rad;
out.injected_error_e_rad = p * error_m_rad;
out.theta_before_wrap_rad = theta_before_wrap_rad;
out.theta_wrapped_rad = theta_wrapped_rad;
out.encoder_count = encoder_count;
out.theta_m_raw_rad = theta_m_raw_rad;
out.theta_e_raw_rad = theta_e_raw_rad;
out.total_error_e_rad = anglelut.wrap_to_pi(theta_e_raw_rad ...
                                            - theta_true_e_rad);

end

function [sensor_mode, error_mode, p, theta0_e_rad, legacy_offset_e_rad, ...
          fixed_error_e_rad, periodic_bias_m_rad, periodic_amp1_m_rad, ...
          periodic_phase1_rad, periodic_amp2_m_rad, periodic_phase2_rad, ...
          counts_per_rev, quantization_enabled] = resolve_config(cfg)
% Accept the project configuration without forcing harness adapter code.
if isfield(cfg, 'sensor')
    sensor_mode = cfg.encoder.sensor_mode;
    error_mode = cfg.encoder.error_mode;
    p = cfg.motor.pole_pairs;
    theta0_e_rad = cfg.encoder.theta0_e_rad;
    legacy_offset_e_rad = cfg.encoder.legacy_offset_e_rad;
    fixed_error_e_rad = cfg.encoder.fixed_error_e_rad;
    periodic_bias_m_rad = cfg.encoder.periodic_bias_m_rad;
    periodic_amp1_m_rad = cfg.encoder.periodic_amp1_m_rad;
    periodic_phase1_rad = cfg.encoder.periodic_phase1_rad;
    periodic_amp2_m_rad = cfg.encoder.periodic_amp2_m_rad;
    periodic_phase2_rad = cfg.encoder.periodic_phase2_rad;
    counts_per_rev = cfg.encoder.counts_per_rev;
    if isfield(cfg.encoder, 'quantization_enabled')
        quantization_enabled = cfg.encoder.quantization_enabled;
    else
        quantization_enabled = true;
    end
else
    sensor_mode = cfg.sensor_mode;
    error_mode = cfg.error_mode;
    p = cfg.pole_pairs;
    theta0_e_rad = cfg.theta0_e_rad;
    legacy_offset_e_rad = cfg.legacy_offset_e_rad;
    fixed_error_e_rad = cfg.fixed_error_e_rad;
    periodic_bias_m_rad = cfg.periodic_bias_m_rad;
    periodic_amp1_m_rad = cfg.periodic_amp1_m_rad;
    periodic_phase1_rad = cfg.periodic_phase1_rad;
    periodic_amp2_m_rad = cfg.periodic_amp2_m_rad;
    periodic_phase2_rad = cfg.periodic_phase2_rad;
    counts_per_rev = cfg.counts_per_rev;
    quantization_enabled = cfg.quantization_enabled;
end
end
