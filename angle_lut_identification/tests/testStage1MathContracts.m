function tests = testStage1MathContracts
%TSTAGE1MATHCONTRACTS E03 and E05-E08 sign/voltage tests.
tests = functiontests(localfunctions);
end

function setupOnce(~)
addProjectPaths();
end

function testE03ParkConvention(testCase)
xab = [2; 3];
verifyEqual(testCase, anglelut.park_alphabeta(xab, 0), xab, ...
    'AbsTol', 10*eps);
verifyEqual(testCase, anglelut.park_alphabeta(xab, pi/2), [3; -2], ...
    'AbsTol', 1e-14);
verifyEqual(testCase, anglelut.park_alphabeta([1; 0], pi), [-1; 0], ...
    'AbsTol', 1e-14);
end

function testAmplitudeInvariantClarke(testCase)
theta = 0.71;
xabc = [cos(theta); cos(theta-2*pi/3); cos(theta+2*pi/3)];
verifyEqual(testCase, anglelut.clarke_abc(xabc), [cos(theta); sin(theta)], ...
    'AbsTol', 1e-14);
end

function testDutyVoltageReconstruction(testCase)
duty = [0.6; 0.4; 0.5];
vdc = 24;
out = anglelut.reconstruct_voltage(duty, vdc, 0);
expectedVabc = [2.4; -2.4; 0];
expectedVab = anglelut.clarke_abc(expectedVabc);
verifyEqual(testCase, out.common_mode_duty, 0.5, 'AbsTol', eps);
verifyEqual(testCase, out.vabc_V, expectedVabc, 'AbsTol', 1e-14);
verifyEqual(testCase, out.vab_V, expectedVab, 'AbsTol', 1e-14);
verifyEqual(testCase, out.vdq_V, expectedVab, 'AbsTol', 1e-14);

zero = anglelut.reconstruct_voltage([0.73; 0.73; 0.73], vdc, 1.2);
verifyEqual(testCase, zero.vabc_V, zeros(3, 1), 'AbsTol', 1e-14);
verifyEqual(testCase, zero.vdq_V, zeros(2, 1), 'AbsTol', 1e-14);
end

function testPositiveFiveDegreeResidualSignBothDirections(testCase)
cfg = default_config();
delta = deg2rad(5);

[sk, sk1, expectedRaw] = syntheticResidualSamples(cfg, delta, 100);
outForward = anglelut.physical_residual(sk, sk1, cfg.residual);
verifyTrue(testCase, outForward.valid);
verifyEqual(testCase, outForward.euler.residual_A, expectedRaw, ...
    'AbsTol', 1e-12);
verifyEqual(testCase, outForward.z_rad, delta, 'AbsTol', 1e-12);

% One 1024-count mechanical encoder step is 7.3828125 electrical degrees
% at p=21.  Changing only the next raw-frame angle must not create a false
% current residual: the E05 integration is coordinate-invariant alpha-beta.
sk1.theta_e_rad = sk.theta_e_rad + ...
    cfg.motor.pole_pairs * 2*pi/cfg.encoder.counts_per_rev;
outQuantizerJump = anglelut.physical_residual(sk, sk1, cfg.residual);
verifyEqual(testCase, outQuantizerJump.euler.residual_A, expectedRaw, ...
    'AbsTol', 1e-12);
verifyEqual(testCase, outQuantizerJump.z_rad, delta, 'AbsTol', 1e-12);

[sk, sk1, expectedRaw] = syntheticResidualSamples(cfg, delta, -100);
outReverse = anglelut.physical_residual(sk, sk1, cfg.residual);
verifyTrue(testCase, outReverse.valid);
verifyEqual(testCase, outReverse.euler.residual_A, expectedRaw, ...
    'AbsTol', 1e-12);
verifyEqual(testCase, outReverse.z_rad, delta, 'AbsTol', 1e-12);
verifyEqual(testCase, outReverse.y_A, outForward.y_A, 'AbsTol', 1e-12);
end

function testResidualIsPredictionMinusMeasurement(testCase)
cfg = default_config();
delta = deg2rad(5);
[sk, sk1, expectedRaw] = syntheticResidualSamples(cfg, delta, 100);
out = anglelut.physical_residual(sk, sk1, cfg.residual);
verifyEqual(testCase, out.euler.residual_A, ...
    out.euler.i_pred_A - out.idq_kp1_A, 'AbsTol', 1e-14);
verifyEqual(testCase, out.euler.residual_A, expectedRaw, 'AbsTol', 1e-12);
end

function testTimestampMisalignmentFreezesPseudoAngle(testCase)
cfg = default_config();
[sk, sk1] = syntheticResidualSamples(cfg, deg2rad(5), 100);
sk1.current_timestamp_s = sk1.current_timestamp_s + 10e-6;
out = anglelut.physical_residual(sk, sk1, cfg.residual);
verifyFalse(testCase, out.valid);
verifyFalse(testCase, out.gates.timestamp_ok);
verifyEqual(testCase, out.z_rad, 0);
verifyEqual(testCase, out.quality_weight, 0);
end

function [sk, sk1, rawResidual] = syntheticResidualSamples(cfg, delta, omegaE)
Ts = cfg.residual.Ts_s;
A = Ts*cfg.residual.psi_f_Wb*abs(omegaE)/cfg.residual.Ls_H;
direction = int8(sign(omegaE));
y = A*[sin(delta); cos(delta)];
rawResidual = double(direction)*y;
thetaMid = 0.5 * Ts * omegaE;
residualAlphaBeta = inversePark(rawResidual, thetaMid);
measuredAlphaBetaKp1 = -residualAlphaBeta;

sk = validSample(0, omegaE, direction);
sk.iabc_A = [0; 0; 0];
sk1 = validSample(Ts, omegaE, direction);
sk1.iabc_A = inverseClarke(measuredAlphaBetaKp1);
end

function s = validSample(timestamp, omegaE, direction)
s.iabc_A = zeros(3, 1);
s.duty_abc = 0.5*ones(3, 1);
s.vdc_V = 24;
s.theta_e_rad = 0;
s.omega_e_radps = omegaE;
s.direction_sign = direction;
s.direction_valid = true;
s.adc_valid = true;
s.pwm_saturated = false;
s.pwm_overmodulated = false;
s.min_pulse_clipped = false;
s.current_limited = false;
s.timestamp_s = timestamp;
s.current_timestamp_s = timestamp;
s.angle_timestamp_s = timestamp;
s.voltage_timestamp_s = timestamp;
end

function abc = inverseClarke(ab)
abc = [ab(1); -0.5*ab(1) + sqrt(3)*0.5*ab(2); ...
    -0.5*ab(1) - sqrt(3)*0.5*ab(2)];
end

function ab = inversePark(dq, theta)
c = cos(theta);
s = sin(theta);
ab = [c, -s; s, c] * dq;
end

function addProjectPaths()
root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root, 'config'));
addpath(fullfile(root, 'src'));
end
