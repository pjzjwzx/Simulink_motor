function [value_rad, node0, node1, alpha] = periodic_lut_interp(phi_rad, lut_rad)
%PERIODIC_LUT_INTERP E09 scalar periodic linear interpolation.
%   PHI_RAD is a raw mechanical angle. LUT_RAD stores electrical-radian
%   compensation values at uniformly spaced nodes over [0,2*pi).
%   NODE0 and NODE1 are MATLAB one-based indices.

M = numel(lut_rad);
phi_wrapped_rad = anglelut.wrap_to_2pi(phi_rad);
u = M * phi_wrapped_rad / (2.0 * pi);
j_zero_based = floor(u);
alpha = u - j_zero_based;
node0 = j_zero_based + 1;
node1 = mod(j_zero_based + 1, M) + 1;
value_rad = (1.0 - alpha) * lut_rad(node0) + alpha * lut_rad(node1);

end
