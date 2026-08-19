function [state,event] = scheme5_update64(state,sample,cfg)
%SCHEME5_UPDATE64 Fixed M=64 wrapper.
%#codegen
assert(state.M == uint16(64),'anglelut:Scheme5WrapperSize','Expected M=64.');
[state,event] = anglelut.scheme5_update(state,sample,cfg);
end
