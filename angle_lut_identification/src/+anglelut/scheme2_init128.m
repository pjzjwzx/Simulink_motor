function state = scheme2_init128(cfg,sourceMode)
%SCHEME2_INIT128 Fixed M=128 wrapper.
if nargin < 2, sourceMode = cfg.stage4.MODE_ATAN2; end
state = anglelut.scheme2_init(128,cfg,sourceMode);
end
