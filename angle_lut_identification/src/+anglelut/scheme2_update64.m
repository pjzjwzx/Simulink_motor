function [state,event] = scheme2_update64(state,sample,cfg)
%SCHEME2_UPDATE64 Fixed M=64 atan2 wrapper.
%#codegen
assert(state.M == uint16(64),'anglelut:Scheme2WrapperSize','Expected M=64.');
[state,event] = anglelut.scheme2_update(state,sample,cfg);
end
