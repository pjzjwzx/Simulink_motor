function [metrics, reference] = apply_predictor_floor_reference(metrics)
%APPLY_PREDICTOR_FLOOR_REFERENCE Apply the measured Stage-1 predictor floor.
%   The implementation specification defines predictor_floor as the
%   intrinsic RMSE measured with zero injected angle error and no configured
%   noise.  FIXED_00DEG_E is that frozen calibration case.  The Euler/RK2/
%   Heun disagreement remains a useful diagnostic, but it is not the floor:
%   all three predictors share ADC quantization and alignment uncertainty.

reference = struct( ...
    'available',false, ...
    'source_case_id','fixed_00deg_e', ...
    'condition','zero injected angle error; configured noise disabled', ...
    'euler_rmse_e_rad',NaN, ...
    'euler_rmse_e_deg',NaN, ...
    'rk2_rmse_e_rad',NaN, ...
    'rk2_rmse_e_deg',NaN, ...
    'heun_rmse_e_rad',NaN, ...
    'heun_rmse_e_deg',NaN);

if isempty(metrics)
    return;
end

ids = string({metrics.case_id});
index = find(ids == reference.source_case_id,1);
if isempty(index)
    return;
end

eulerFloor = double(metrics(index).rmse_e_rad);
rk2Floor = double(metrics(index).rk2_rmse_e_rad);
heunFloor = double(metrics(index).heun_rmse_e_rad);
if ~all(isfinite([eulerFloor,rk2Floor,heunFloor]))
    return;
end

reference.available = true;
reference.euler_rmse_e_rad = eulerFloor;
reference.euler_rmse_e_deg = rad2deg(eulerFloor);
reference.rk2_rmse_e_rad = rk2Floor;
reference.rk2_rmse_e_deg = rad2deg(rk2Floor);
reference.heun_rmse_e_rad = heunFloor;
reference.heun_rmse_e_deg = rad2deg(heunFloor);

copyLegacyDisagreement = isfield(metrics,'predictor_floor_e_rad') && ...
    ~isfield(metrics,'predictor_disagreement_e_rad');
for k = 1:numel(metrics)
    if copyLegacyDisagreement
        metrics(k).predictor_disagreement_e_rad = ...
            metrics(k).predictor_floor_e_rad;
        metrics(k).predictor_disagreement_e_deg = ...
            metrics(k).predictor_floor_e_deg;
    end
    metrics(k).predictor_floor_e_rad = eulerFloor;
    metrics(k).predictor_floor_e_deg = rad2deg(eulerFloor);
end
end
