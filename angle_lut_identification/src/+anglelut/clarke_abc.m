function xab = clarke_abc(xabc)
%CLARKE_ABC Amplitude-invariant Clarke transform.
%   XABC is [xa; xb; xc]. XAB is [x_alpha; x_beta] in the same unit.
%   For a balanced set, x_alpha equals phase-a amplitude.

xa = xabc(1);
xb = xabc(2);
xc = xabc(3);

xalpha = (2.0 / 3.0) * (xa - 0.5 * xb - 0.5 * xc);
xbeta = (1.0 / sqrt(3.0)) * (xb - xc);
xab = [xalpha; xbeta];

end
