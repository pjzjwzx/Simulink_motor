function xdq = park_alphabeta(xab, theta_e_rad)
%PARK_ALPHABETA Park transform using the E03 sign convention.
%   [xd; xq] = [cos(theta) sin(theta); -sin(theta) cos(theta)]
%              * [xalpha; xbeta].
%   THETA_E_RAD is electrical radians. XAB and XDQ retain their input unit.

c = cos(theta_e_rad);
s = sin(theta_e_rad);
xalpha = xab(1);
xbeta = xab(2);

xd = c * xalpha + s * xbeta;
xq = -s * xalpha + c * xbeta;
xdq = [xd; xq];

end
