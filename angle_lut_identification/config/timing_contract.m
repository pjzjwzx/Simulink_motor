function timing = timing_contract()
%TIMING_CONTRACT Discrete-time alignment contract for Stage 1.

timing.schema_version = "stage1-timing-v1";
timing.base_step_s = 5e-6;
timing.fpwm_Hz = 20e3;
timing.T_ident_s = 1/timing.fpwm_Hz;
timing.base_steps_per_identification = ...
    timing.T_ident_s/timing.base_step_s;

timing.pwm_update_phase_s = 0;
timing.duty_effective_start_phase_s = 0;
timing.nonideal_current_sign_sample_phase_s = 0;
timing.nonideal_interval_hold_s = timing.T_ident_s;
timing.adc_boundary_sample_phase_s = 0;
timing.encoder_boundary_sample_phase_s = 0;
timing.existing_adc_latency_s = timing.base_step_s;
timing.existing_encoder_latency_s = timing.base_step_s;
timing.identification_event_offset_s = timing.base_step_s;
timing.identification_event_base_steps = 1;
timing.timestamp_tolerance_s = timing.base_step_s/2;

timing.interval_definition = ...
    "duty(k) and vdc(k) are effective over [k*T_ident,(k+1)*T_ident)";
timing.nonideal_interval_rule = ...
    "deadtime and device-drop current polarity are sampled at the PWM boundary and held for the complete interval";
timing.state_definition = ...
    "save i(k), duty(k), vdc(k), raw angle(k), and speed(k); compute the residual when i(k+1) arrives";
timing.voltage_park_primary_angle = "interval_midpoint";
timing.voltage_park_sensitivity_angle = "interval_start";
timing.low_rate_angle_rule = ...
    "unwrap with timestamps, extrapolate to the requested interval time, then wrap only for indexing";
timing.direction_rule = ...
    "use estimated electrical speed with 10/5 rad/s enter/exit hysteresis; invalidate low-speed and reversal samples";
timing.baseline_simulink_solver_observed = "VariableStepAuto";
timing.baseline_powergui_mode_observed = "Discrete";
timing.baseline_powergui_sample_time_s = timing.base_step_s;
end
