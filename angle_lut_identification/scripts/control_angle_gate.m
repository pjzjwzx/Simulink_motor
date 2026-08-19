function [pass,basis,details] = control_angle_gate(pair,c,cfg)
%CONTROL_ANGLE_GATE Versioned frozen control-angle acceptance contract.

className = string(pair.expected_class);
useStage3 = isfield(cfg,'stage3') && ...
    isfield(cfg.stage3,'control_gate_namespace') && ...
    cfg.stage3.control_gate_namespace == "stage3";
if useStage3, g = cfg.gates.stage3; else, g = cfg.gates.stage2; end
details = struct('improvement',double(pair.control_angle_improvement), ...
    'active_rmse_e_rad',double(pair.active.control_angle_rmse_e_rad), ...
    'percentage_threshold',NaN,'floor_threshold_e_rad',NaN);
if className == "saturation_diagnostic"
    pass = isfinite(pair.active.compensation_max_abs_e_rad) && ...
        pair.active.compensation_max_abs_e_rad <= ...
        local_max_abs_lut(cfg,useStage3)+100*eps;
    basis = "saturation_safety";
elseif className == "ideal" && string(c.case_id) == "fixed_00deg_e"
    pass = true;
    basis = "fixed_zero_exempt";
elseif className == "ideal"
    quantizationFloor = 2*pi*cfg.motor.pole_pairs/( ...
        cfg.encoder.counts_per_rev*sqrt(12));
    floorLimit = quantizationFloor + ...
        g.ideal_control_angle_floor_margin_e_rad;
    details.percentage_threshold = g.ideal_control_angle_improvement_min;
    details.floor_threshold_e_rad = floorLimit;
    percentagePass = pair.control_angle_improvement >= ...
        g.ideal_control_angle_improvement_min;
    floorPass = pair.active.control_angle_rmse_e_rad <= floorLimit;
    pass = percentagePass || floorPass;
    if percentagePass
        basis = "percentage";
    elseif floorPass
        basis = "quantization_floor";
    else
        basis = "failed";
    end
else
    details.percentage_threshold = ...
        g.nonideal_control_angle_improvement_min;
    pass = pair.control_angle_improvement >= ...
        g.nonideal_control_angle_improvement_min;
    if pass, basis = "percentage"; else, basis = "failed"; end
end
pass = logical(pass);
basis = char(basis);
end

function value = local_max_abs_lut(cfg,useStage3)
if useStage3
    value = cfg.stage3.max_abs_lut_e_rad;
else
    value = cfg.stage2.max_abs_lut_e_rad;
end
end
