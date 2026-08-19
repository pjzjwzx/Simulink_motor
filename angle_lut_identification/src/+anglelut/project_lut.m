function [projected,info] = project_lut(shadow,active,validMask,cfg)
%PROJECT_LUT E51 periodic LUT constraint handling (not Euclidean projection).

stage2 = local_stage2(cfg);
shadow = shadow(:);
active = active(:);
validMask = logical(validMask(:));
M = numel(shadow);
assert(numel(active) == M && numel(validMask) == M, ...
    'anglelut:LutProjectionSize','LUT inputs must have equal lengths.');

projected = active;
projected(validMask) = shadow(validMask);
projected(validMask) = min(max(projected(validMask), ...
    -stage2.max_abs_lut_e_rad),stage2.max_abs_lut_e_rad);
limit = stage2.pole_pairs*2*pi/M*(1-stage2.monotonic_margin);

for sweep = 1:double(stage2.constraint_sweeps)
    for j = 1:M
        j1 = mod(j,M)+1;
        excess = projected(j1)-projected(j)-limit;
        if excess > 0
            if validMask(j) && validMask(j1)
                projected(j) = projected(j)+0.5*excess;
                projected(j1) = projected(j1)-0.5*excess;
            elseif validMask(j1)
                projected(j1) = projected(j)+limit;
            elseif validMask(j)
                projected(j) = projected(j1)-limit;
            end
        end
    end
    projected(validMask) = min(max(projected(validMask), ...
        -stage2.max_abs_lut_e_rad),stage2.max_abs_lut_e_rad);
end
projected(~validMask) = active(~validMask);

delta = circshift(projected,-1)-projected;
info.constraint_name = "periodic amplitude/slope handling";
info.is_exact_euclidean_projection = false;
info.max_abs_e_rad = max(abs(projected));
info.minimum_monotonic_margin = min(1-delta/(stage2.pole_pairs*2*pi/M));
info.uncovered_unchanged = all(projected(~validMask) == active(~validMask));
info.constraints_satisfied = info.max_abs_e_rad <= ...
    stage2.max_abs_lut_e_rad+100*eps && ...
    info.minimum_monotonic_margin >= stage2.monotonic_margin-100*eps && ...
    info.uncovered_unchanged;
end

function s = local_stage2(cfg)
if isfield(cfg,'stage2'), s = cfg.stage2; else, s = cfg; end
if ~isfield(s,'pole_pairs')
    if isfield(cfg,'motor'), s.pole_pairs = cfg.motor.pole_pairs; ...
    else, error('anglelut:MissingPolePairs','pole_pairs is required.'); end
end
end
