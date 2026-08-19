function [pass,basis,details] = evaluate_stage3_pair_gate(pair,c,cfg)
%EVALUATE_STAGE3_PAIR_GATE Frozen Scheme-5 per-case critical gate.

g = cfg.gates.stage3;
[anglePass,basis,angleDetails] = control_angle_gate(pair,c,cfg);
className = string(pair.expected_class);
physical = [pair.id_rms_improvement, ...
    pair.prediction_residual_improvement,pair.torque_ripple_improvement];
if className == "saturation_diagnostic"
    pass = anglePass;
elseif className == "ideal"
    pass = anglePass && all(physical >= -g.ideal_per_case_regression_max) && ...
        pair.iq_tracking_change <= g.iq_tracking_regression_max && ...
        pair.mean_torque_change <= g.mean_torque_change_max;
else
    pass = anglePass && all(physical >= -g.nonideal_per_case_regression_max) && ...
        pair.iq_tracking_change <= g.iq_tracking_regression_max && ...
        pair.mean_torque_change <= g.mean_torque_change_max;
end
details = struct('angle',angleDetails,'physical_improvements',physical, ...
    'iq_tracking_change',pair.iq_tracking_change, ...
    'mean_torque_change',pair.mean_torque_change);
pass = logical(pass);
end
