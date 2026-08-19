function [activeNext,info] = fuse_active_lut(active,projected,validMask,cfg)
%FUSE_ACTIVE_LUT Slow, step-limited shadow-to-active fusion.

stage2 = local_stage2(cfg);
active = active(:);
projected = projected(:);
validMask = logical(validMask(:));
assert(numel(active) == numel(projected) && ...
    numel(active) == numel(validMask), ...
    'anglelut:LutFusionSize','LUT fusion inputs must have equal lengths.');
desiredStep = stage2.gamma*(projected-active);
step = min(max(desiredStep,-stage2.max_active_step_e_rad), ...
    stage2.max_active_step_e_rad);
step(~validMask) = 0;
activeNext = active+step;
info.max_step_e_rad = max(abs(step));
info.rms_step_e_rad = sqrt(mean(step(validMask).^2));
if ~any(validMask), info.rms_step_e_rad = 0; end
info.uncovered_unchanged = all(activeNext(~validMask) == active(~validMask));
info.step_limit_satisfied = info.max_step_e_rad <= ...
    stage2.max_active_step_e_rad+100*eps;
end

function s = local_stage2(cfg)
if isfield(cfg,'stage2'), s = cfg.stage2; else, s = cfg; end
end
