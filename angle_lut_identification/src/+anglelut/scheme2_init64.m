function state = scheme2_init64(cfg,sourceMode)
%SCHEME2_INIT64 Fixed M=64 wrapper.
if nargin < 2, sourceMode = cfg.stage4.MODE_ATAN2; end
state = anglelut.scheme2_init(64,cfg,sourceMode);
end
