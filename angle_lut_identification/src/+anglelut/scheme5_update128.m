function [state,event] = scheme5_update128(state,sample,cfg)
%SCHEME5_UPDATE128 Fixed M=128 wrapper.
%#codegen
assert(state.M == uint16(128),'anglelut:Scheme5WrapperSize','Expected M=128.');
[state,event] = anglelut.scheme5_update(state,sample,cfg);
end
