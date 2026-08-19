function [state,event] = scheme4_update128(state,sample,cfg)
%SCHEME4_UPDATE128 Fixed 128-node E20-E22 update wrapper.
assert(numel(state.diag_A) == 128,'anglelut:Scheme4WrapperSize', ...
    'scheme4_update128 requires a 128-node state.');
[state,event] = anglelut.scheme4_update(state,sample,cfg);
end
