function [state,event] = scheme4_update64(state,sample,cfg)
%SCHEME4_UPDATE64 Fixed 64-node E20-E22 update wrapper.
assert(numel(state.diag_A) == 64,'anglelut:Scheme4WrapperSize', ...
    'scheme4_update64 requires a 64-node state.');
[state,event] = anglelut.scheme4_update(state,sample,cfg);
end
