function y = wrap_to_pi(theta)
%WRAP_TO_PI Wrap an angle to (-pi, pi].
%   The +pi representation is used for the branch cut to match the
%   circular-error convention in the theory review.

two_pi = 2.0 * pi;
y = mod(theta + pi, two_pi) - pi;
y = y + two_pi .* (y <= -pi);

end
