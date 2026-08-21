function [state,event] = scheme2_update_atan2_free64(state,sample,cfg)
%SCHEME2_UPDATE_ATAN2_FREE64 Fixed M=64 diagnostic wrapper.
%#codegen
assert(state.M == uint16(64),'anglelut:Scheme2WrapperSize','Expected M=64.');
[state,event] = anglelut.scheme2_update_atan2_free(state,sample,cfg);
end
