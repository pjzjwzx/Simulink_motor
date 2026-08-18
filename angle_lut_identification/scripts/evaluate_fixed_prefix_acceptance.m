function [passed, checks, aggregate] = evaluate_fixed_prefix_acceptance(metrics,cfg)
%EVALUATE_FIXED_PREFIX_ACCEPTANCE Critical gates after the first five cases.
%   This is an acceptance-only helper. It does not alter or recompute any
%   residual estimate. METRICS must contain, in execution order, the
%   baseline legacy case followed by fixed 0/5/10/20 electrical degrees.

requiredIds = ["baseline_legacy_equivalence", ...
    "fixed_00deg_e", "fixed_05deg_e", ...
    "fixed_10deg_e", "fixed_20deg_e"];
ids = string({metrics.case_id});
[metrics,predictorFloor] = apply_predictor_floor_reference(metrics);

checks = struct();
checks.prefix_complete = isequal(ids,requiredIds);

fixed5 = find(ids == "fixed_05deg_e",1);
checks.fixed_5deg_mean_error = ~isempty(fixed5) && ...
    isfinite(metrics(fixed5).mean_estimation_error_e_rad) && ...
    abs(metrics(fixed5).mean_estimation_error_e_rad) <= ...
    cfg.gates.stage1.fixed_5deg_mean_error_max_e_rad;

fixedIds = requiredIds(2:end);
fixedIdx = arrayfun(@(id)find(ids==id,1),fixedIds, ...
    'UniformOutput',false);
if all(~cellfun(@isempty,fixedIdx))
    idx = cell2mat(fixedIdx);
    x = [metrics(idx).commanded_fixed_error_e_rad].';
    y = [metrics(idx).mean_estimate_e_rad].';
    if all(isfinite(x)) && all(isfinite(y))
        fit = polyfit(x,y,1);
    else
        fit = [NaN NaN];
    end
else
    fit = [NaN NaN];
end
checks.fixed_fit = isfinite(fit(1)) && ...
    fit(1) >= cfg.gates.stage1.fixed_fit_slope_range(1) && ...
    fit(1) <= cfg.gates.stage1.fixed_fit_slope_range(2) && ...
    abs(fit(2)) <= cfg.gates.stage1.fixed_fit_intercept_abs_max_e_rad;

if isempty(metrics)
    idealPass = false(1,0);
    isIdeal = false(1,0);
else
    % fixed_00deg_e is the measured floor calibration, not a sample to test
    % against a threshold derived from itself.
    isIdeal = strcmp({metrics.expected_class},'ideal') & ...
        ids ~= predictorFloor.source_case_id;
    idealThreshold = max(cfg.gates.stage1.ideal_rmse_floor_e_rad, ...
        cfg.gates.stage1.ideal_rmse_predictor_floor_multiplier .* ...
        [metrics.predictor_floor_e_rad]);
    idealPass = isfinite([metrics.rmse_e_rad]) & ...
        [metrics.rmse_e_rad] < idealThreshold;
end
checks.ideal_rmse = checks.prefix_complete && any(isIdeal) && ...
    all(idealPass(isIdeal));

values = struct2cell(checks);
passed = all(cellfun(@(value)islogical(value) && isscalar(value) && value, ...
    values));

aggregate = struct();
aggregate.required_case_ids = requiredIds;
aggregate.observed_case_ids = ids;
aggregate.fixed_5deg_mean_error_e_deg = local_field_or_nan( ...
    metrics,fixed5,'mean_estimation_error_e_deg');
aggregate.fixed_fit_slope = fit(1);
aggregate.fixed_fit_intercept_e_deg = rad2deg(fit(2));
aggregate.ideal_case_count = nnz(isIdeal);
aggregate.ideal_failed_case_ids = ids(isIdeal & ~idealPass);
aggregate.predictor_floor_reference = predictorFloor;
end

function value = local_field_or_nan(metrics,index,field)
if isempty(index)
    value = NaN;
else
    value = metrics(index).(field);
end
end
