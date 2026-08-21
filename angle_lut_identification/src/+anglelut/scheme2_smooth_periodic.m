function smoothed = scheme2_smooth_periodic(lut_e_rad,strength)
%SCHEME2_SMOOTH_PERIODIC Event-only periodic second-order spatial smoother.

assert(isscalar(strength) && isfinite(strength) && ...
    strength >= 0 && strength <= 0.25, ...
    'anglelut:Scheme2SmoothingStrength', ...
    'Second-order smoothing strength must be in [0,0.25].');
w = lut_e_rad(:);
smoothed = w + strength*(circshift(w,1)-2*w+circshift(w,-1));
end
