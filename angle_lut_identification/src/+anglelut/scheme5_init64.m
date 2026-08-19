function state = scheme5_init64(cfg,modeCode)
%SCHEME5_INIT64 Fixed M=64 wrapper.
if nargin < 2, modeCode = cfg.stage3.primary_amplitude_mode_code; end
state = anglelut.scheme5_init(64,cfg,modeCode);
end
