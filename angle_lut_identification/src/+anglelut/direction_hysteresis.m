function [direction_sign, state_next, valid, transitioned] = ...
    direction_hysteresis(omega_e_radps, state, cfg)
%DIRECTION_HYSTERESIS Direction sign with an invalid reversal band.
%   STATE is int8(-1), int8(0), or int8(+1). A stopped state enters a
%   direction only at ENTER_THRESHOLD_E_RADPS. A running state becomes
%   invalid when speed crosses EXIT_THRESHOLD_E_RADPS toward zero. It must
%   pass through state zero before entering the opposite direction.
%
%   Required CFG fields [electrical rad/s]:
%     enter_threshold_e_radps
%     exit_threshold_e_radps

if isfield(cfg, 'speed_estimator')
    enter_threshold = abs(cfg.speed_estimator.direction_enter_e_radps);
    exit_threshold = abs(cfg.speed_estimator.direction_exit_e_radps);
else
    enter_threshold = abs(cfg.enter_threshold_e_radps);
    exit_threshold = abs(cfg.exit_threshold_e_radps);
end
previous = int8(state);
if (previous ~= int8(-1)) && (previous ~= int8(1))
    previous = int8(0);
end

state_next = previous;
if ~isfinite(omega_e_radps)
    state_next = int8(0);
elseif previous == int8(0)
    if omega_e_radps >= enter_threshold
        state_next = int8(1);
    elseif omega_e_radps <= -enter_threshold
        state_next = int8(-1);
    end
elseif previous == int8(1)
    if omega_e_radps <= exit_threshold
        state_next = int8(0);
    end
else
    if omega_e_radps >= -exit_threshold
        state_next = int8(0);
    end
end

direction_sign = state_next;
valid = (state_next ~= int8(0));
transitioned = (state_next ~= previous);

end
