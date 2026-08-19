function state = scheme5_init128(cfg,modeCode)
%SCHEME5_INIT128 Fixed M=128 wrapper.
if nargin < 2, modeCode = cfg.stage3.primary_amplitude_mode_code; end
state = anglelut.scheme5_init(128,cfg,modeCode);
end
