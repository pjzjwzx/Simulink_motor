function state = init_speed_estimator_state()
%INIT_SPEED_ESTIMATOR_STATE Fixed-layout state for ESTIMATE_SPEED_STEP.

state.initialized = false;
state.theta_m_wrapped_prev_rad = 0.0;
state.theta_m_unwrapped_rad = 0.0;
state.timestamp_prev_s = 0.0;
state.omega_m_filt_radps = 0.0;

end
