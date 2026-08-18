function metrics = circular_metrics(estimateRad, truthRad, valid)
%CIRCULAR_METRICS Circular error metrics in radians and electrical degrees.

if nargin < 3 || isempty(valid), valid = true(size(estimateRad)); end
valid = logical(valid(:)) & isfinite(estimateRad(:)) & isfinite(truthRad(:));
errorRad = angle(exp(1i * (estimateRad(:) - truthRad(:))));
errorRad = errorRad(valid);
metrics = struct('count',numel(errorRad),'rmse_rad',NaN,'mean_rad',NaN, ...
    'max_abs_rad',NaN,'rmse_deg_e',NaN,'mean_deg_e',NaN,'max_abs_deg_e',NaN);
if isempty(errorRad), return; end
metrics.rmse_rad = sqrt(mean(errorRad.^2));
metrics.mean_rad = angle(mean(exp(1i*errorRad)));
metrics.max_abs_rad = max(abs(errorRad));
metrics.rmse_deg_e = rad2deg(metrics.rmse_rad);
metrics.mean_deg_e = rad2deg(metrics.mean_rad);
metrics.max_abs_deg_e = rad2deg(metrics.max_abs_rad);
end

