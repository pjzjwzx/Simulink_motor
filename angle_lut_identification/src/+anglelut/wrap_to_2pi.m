function y = wrap_to_2pi(theta)
%WRAP_TO_2PI Wrap an angle to [0, 2*pi).
%   THETA and Y use the same angular unit; this project uses radians.
%   The element-wise implementation is compatible with fixed-size code
%   generation inputs.

two_pi = 2.0 * pi;
y = mod(theta, two_pi);
% For a tiny negative input, floating-point MOD can round mathematically
% valid 2*pi-|theta| up to exactly 2*pi. Clamp that rounding artifact to
% the largest representable project-domain value below the upper bound.
y = min(y, two_pi - eps(two_pi));

end
