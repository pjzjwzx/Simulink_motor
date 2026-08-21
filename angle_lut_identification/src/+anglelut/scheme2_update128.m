function [state,event] = scheme2_update128(state,sample,cfg)
%SCHEME2_UPDATE128 Fixed M=128 atan2 wrapper.
%#codegen
assert(state.M == uint16(128),'anglelut:Scheme2WrapperSize','Expected M=128.');
[state,event] = anglelut.scheme2_update(state,sample,cfg);
end
