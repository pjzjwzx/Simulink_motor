function [state,event] = scheme2_update(state,sample,cfg)
%SCHEME2_UPDATE E40 atan2-pseudomeasurement circular-NLMS update.
%   SAMPLE is deliberately limited to the six deployment-safe Scheme-4
%   scalars.  The separate atan2-free diagnostic has a different API.

s = local_stage4(cfg);
local_validate_sample(sample);
assert(state.source_mode == s.MODE_ATAN2, ...
    'anglelut:Scheme2SourceModeMismatch', ...
    'The atan2 updater requires an atan2 Scheme-2 state.');
sampleValid = logical(sample.valid) && isfinite(sample.phi_m_rad) && ...
    isfinite(sample.z_e_rad) && isfinite(sample.quality_weight) && ...
    sample.quality_weight > 0 && ...
    isfinite(sample.theta_m_unwrapped_rad) && ...
    isfinite(sample.timestamp_s);
innovation = NaN;
rawSine = NaN;
clippedSine = NaN;
if sampleValid
    prediction = anglelut.periodic_lut_interp( ...
        sample.phi_m_rad,state.shadow_lut_e_rad);
    rawInnovation = anglelut.wrap_to_pi(sample.z_e_rad-prediction);
    innovation = min(max(rawInnovation,-s.innovation_clip_e_rad), ...
        s.innovation_clip_e_rad);
    rawSine = sin(rawInnovation);
    clippedSine = sin(innovation);
end
[state,event] = anglelut.scheme2_apply_update(state, ...
    double(sample.phi_m_rad),clippedSine,rawSine,innovation, ...
    double(sample.quality_weight),double(sample.theta_m_unwrapped_rad), ...
    double(sample.timestamp_s),sampleValid,cfg);
end

function local_validate_sample(sample)
allowed = sort(["phi_m_rad","z_e_rad","quality_weight", ...
    "theta_m_unwrapped_rad","timestamp_s","valid"]);
actual = sort(string(fieldnames(sample)).');
assert(isequal(actual,allowed),'anglelut:Scheme2Atan2SampleSchema', ...
    'Scheme-2 atan2 sample must contain only the six-field whitelist.');
end

function s = local_stage4(cfg)
if isfield(cfg,'stage4'), s = cfg.stage4; else, s = cfg; end
end
