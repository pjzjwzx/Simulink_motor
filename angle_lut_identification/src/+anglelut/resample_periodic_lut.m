function runtime = resample_periodic_lut(lut_e_rad,runtimeNodes)
%RESAMPLE_PERIODIC_LUT Generate a fixed periodic runtime table with E09.

assert(isscalar(runtimeNodes) && runtimeNodes >= 2 && ...
    runtimeNodes == floor(runtimeNodes), ...
    'anglelut:RuntimeNodeCount','runtimeNodes must be an integer >=2.');
runtime = zeros(runtimeNodes,1);
for j = 1:runtimeNodes
    phi = (j-1)*2*pi/runtimeNodes;
    runtime(j) = anglelut.periodic_lut_interp(phi,lut_e_rad);
end
end
