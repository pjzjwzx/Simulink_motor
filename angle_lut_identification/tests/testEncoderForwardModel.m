function tests = testEncoderForwardModel
%TENCODERFORWARDMODEL E01 waveform, wrapping, and quantization tests.
tests = functiontests(localfunctions);
end

function setupOnce(~)
addProjectPaths();
end

function testWrapRangesAndBranchConvention(testCase)
small = 1e-12;
x = [-4*pi, -2*pi, -small, 0, pi, 2*pi, 4*pi];
y2 = anglelut.wrap_to_2pi(x);
verifyGreaterThanOrEqual(testCase, y2, zeros(size(y2)));
verifyLessThan(testCase, y2, 2*pi*ones(size(y2)));
verifyEqual(testCase, y2([1, 2, 4, 6, 7]), zeros(1, 5), ...
    'AbsTol', 10*eps);
verifyEqual(testCase, y2(3), 2*pi-small, 'AbsTol', 10*eps);

yp = anglelut.wrap_to_pi([-pi, pi, 3*pi, -3*pi, 0]);
verifyEqual(testCase, yp, [pi, pi, pi, pi, 0], 'AbsTol', 10*eps);
verifyGreaterThan(testCase, yp, -pi*ones(size(yp)));
verifyLessThanOrEqual(testCase, yp, pi*ones(size(yp)));
end

function testSelectedPeriodicWaveformBeforeQuantization(testCase)
cfg = default_config();
enc = cfg.encoder;
enc.quantization_enabled = false;
theta = [0, pi/7, pi/2, pi, 7*pi/4];
out = anglelut.encoder_forward_model(theta, enc);
expectedError = enc.periodic_bias_m_rad ...
    + enc.periodic_amp1_m_rad .* sin(theta + enc.periodic_phase1_rad) ...
    + enc.periodic_amp2_m_rad .* sin(2*theta + enc.periodic_phase2_rad);
verifyEqual(testCase, out.error_m_rad, expectedError, 'AbsTol', 1e-14);
verifyEqual(testCase, out.error_e_rad, enc.pole_pairs*expectedError, ...
    'AbsTol', 1e-13);
verifyEqual(testCase, out.theta_m_raw_rad, ...
    anglelut.wrap_to_2pi(theta + expectedError), 'AbsTol', 1e-14);
verifyEqual(testCase, out.theta_e_raw_rad, ...
    enc.pole_pairs*out.theta_m_raw_rad + enc.theta0_e_rad, 'AbsTol', 1e-13);
end

function testMechanicalQuantizationOrderAndWrap(testCase)
cfg = default_config();
enc = cfg.encoder;
enc.error_mode = enc.ERROR_OFF;
enc.quantization_enabled = true;
q = 2*pi/enc.counts_per_rev;
theta = [0.49*q, 0.51*q, 2*pi-0.49*q, 2*pi+1.49*q];
out = anglelut.encoder_forward_model(theta, enc);
verifyEqual(testCase, out.encoder_count, [0, 1, 0, 1]);
verifyEqual(testCase, out.theta_m_raw_rad, [0, q, 0, q], 'AbsTol', 10*eps);
verifyEqual(testCase, out.theta_e_raw_rad, enc.pole_pairs*[0, q, 0, q], ...
    'AbsTol', 100*eps);
end

function testFixedElectricalErrorConvertsToMechanicalBias(testCase)
cfg = default_config();
enc = cfg.encoder;
enc.error_mode = enc.ERROR_FIXED;
enc.fixed_error_e_rad = deg2rad(5);
enc.quantization_enabled = false;
out = anglelut.encoder_forward_model(0.37, enc);
verifyEqual(testCase, out.error_m_rad, deg2rad(5)/enc.pole_pairs, ...
    'AbsTol', 1e-15);
verifyEqual(testCase, out.error_e_rad, deg2rad(5), 'AbsTol', 1e-14);
end

function testLegacyModeLeavesMechanicalPeriodicErrorDisabled(testCase)
cfg = default_config();
enc = cfg.encoder;
enc.sensor_mode = cfg.sensor.MODE_LEGACY_ELECTRICAL;
enc.legacy_offset_e_rad = 0;
enc.quantization_enabled = false;
theta = 0.123;
out = anglelut.encoder_forward_model(theta, enc);
verifyEqual(testCase, out.error_m_rad, 0);
verifyEqual(testCase, out.theta_e_raw_rad, ...
    anglelut.wrap_to_2pi(enc.pole_pairs*theta), 'AbsTol', 1e-14);
end

function addProjectPaths()
root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root, 'config'));
addpath(fullfile(root, 'src'));
end
