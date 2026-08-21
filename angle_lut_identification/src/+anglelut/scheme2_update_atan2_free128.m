function [state,event] = scheme2_update_atan2_free128(state,sample,cfg)
%SCHEME2_UPDATE_ATAN2_FREE128 Fixed M=128 diagnostic wrapper.
%#codegen
assert(state.M == uint16(128),'anglelut:Scheme2WrapperSize','Expected M=128.');
[state,event] = anglelut.scheme2_update_atan2_free(state,sample,cfg);
end
