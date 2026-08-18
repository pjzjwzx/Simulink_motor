function tests = testDirectionAndTiming
%TDIRECTIONANDTIMING Direction hysteresis, speed, and timing contract.
tests = functiontests(localfunctions);
end

function setupOnce(~)
addProjectPaths();
end

function testDirectionHysteresisSequence(testCase)
cfg = default_config();
omega = [0, 9, 11, 6, 4, -11, -6, -4, 11];
expected = int8([0, 0, 1, 1, 0, -1, -1, 0, 1]);
state = int8(0);
actual = zeros(size(expected), 'int8');
valid = false(size(expected));
for k = 1:numel(omega)
    [actual(k), state, valid(k)] = anglelut.direction_hysteresis( ...
        omega(k), state, cfg.direction);
end
verifyEqual(testCase, actual, expected);
verifyEqual(testCase, valid, expected ~= 0);
end

function testDirectionMustPassThroughInvalidStateOnReversal(testCase)
cfg = default_config();
[~, state] = anglelut.direction_hysteresis(11, int8(0), cfg.direction);
[signNow, state, valid, transitioned] = anglelut.direction_hysteresis( ...
    -11, state, cfg.direction);
verifyEqual(testCase, signNow, int8(0));
verifyEqual(testCase, state, int8(0));
verifyFalse(testCase, valid);
verifyTrue(testCase, transitioned);
[signNow, ~, valid] = anglelut.direction_hysteresis(-11, state, cfg.direction);
verifyEqual(testCase, signNow, int8(-1));
verifyTrue(testCase, valid);
end

function testSpeedEstimatorUnwrapsWithoutTruthSpeed(testCase)
cfg = default_config();
e = cfg.speed_estimator;
e.min_dt_s = 0.5e-3;
e.max_dt_s = 1.5e-3;
state = anglelut.init_speed_estimator_state();
dt = 1e-3;
omegaM = 1;
theta0 = 2*pi - 0.01;
[~, state] = anglelut.estimate_speed_step(theta0, 0, state, e);
for k = 1:100
    theta = anglelut.wrap_to_2pi(theta0 + omegaM*k*dt);
    [out, state] = anglelut.estimate_speed_step(theta, k*dt, state, e);
end
verifyTrue(testCase, out.valid);
verifyEqual(testCase, out.omega_m_raw_radps, omegaM, 'AbsTol', 1e-10);
verifyEqual(testCase, out.omega_m_radps, omegaM, 'AbsTol', 1e-10);
verifyEqual(testCase, out.omega_e_radps, e.pole_pairs*omegaM, ...
    'AbsTol', 1e-9);
verifyGreaterThan(testCase, out.theta_m_unwrapped_rad, 2*pi);
end

function testTimingContractIsIntegerAndAligned(testCase)
t = timing_contract();
verifyEqual(testCase, t.base_steps_per_identification, 10);
verifyEqual(testCase, t.identification_event_base_steps, 1);
verifyEqual(testCase, t.identification_event_offset_s, 5e-6, ...
    'AbsTol', eps);
verifyEqual(testCase, t.existing_adc_latency_s, ...
    t.identification_event_offset_s);
verifyEqual(testCase, t.existing_encoder_latency_s, ...
    t.identification_event_offset_s);
verifyEqual(testCase, t.voltage_park_primary_angle, "interval_midpoint");
verifyEqual(testCase, t.voltage_park_sensitivity_angle, "interval_start");

events = t.identification_event_offset_s + (0:20)*t.T_ident_s;
verifyEqual(testCase, diff(events), t.T_ident_s*ones(1, 20), ...
    'AbsTol', 1e-15);
verifyEqual(testCase, mod(events/t.base_step_s, 1), zeros(size(events)), ...
    'AbsTol', 1e-12);
end

function testFiveMicrosecondDelayUsesBothCrossedIntervals(testCase)
T = 50e-6;
x = (10:10:60).';
[actual, support] = anglelut.interval_average(x, 5e-6, T);
expected = NaN(size(x));
expected(2:end) = 0.1*x(1:end-1) + 0.9*x(2:end);

verifyEqual(testCase, actual, expected, 'AbsTol', 1e-13);
verifyEqual(testCase, support.whole_intervals, 0);
verifyEqual(testCase, support.previous_fraction, 0.1, 'AbsTol', 1e-14);
verifyEqual(testCase, support.current_fraction, 0.9, 'AbsTol', 1e-14);
verifyFalse(testCase, support.valid(1));
verifyTrue(testCase, all(support.valid(2:end)));
end

function testFiftyMicrosecondDelayIsExactlyOnePriorInterval(testCase)
T = 50e-6;
x = (10:10:60).';
[actual, support] = anglelut.interval_average(x, T, T);
expected = [NaN; x(1:end-1)];

verifyEqual(testCase, actual, expected, 'AbsTol', 1e-13);
verifyEqual(testCase, support.whole_intervals, 1);
verifyEqual(testCase, support.previous_fraction, 0);
verifyEqual(testCase, support.current_fraction, 1);
end

function testVdcDutyProductPreservesExactAverageVoltage(testCase)
T = 50e-6;
delay = 5e-6;
vdc = [20; 30; 25; 40];
duty = [0.60 0.40 0.50; ...
        0.55 0.35 0.65; ...
        0.45 0.70 0.30; ...
        0.75 0.25 0.45];
vdcAverage = anglelut.interval_average(vdc, delay, T);
vdcDutyAverage = anglelut.interval_average( ...
    bsxfun(@times,vdc,duty), delay, T);
dutyEquivalent = bsxfun(@rdivide,vdcDutyAverage,vdcAverage);

for k = 2:size(duty,1)
    reconstructed = anglelut.reconstruct_voltage( ...
        dutyEquivalent(k,:).',vdcAverage(k),0);
    previous = anglelut.reconstruct_voltage(duty(k-1,:).',vdc(k-1),0);
    current = anglelut.reconstruct_voltage(duty(k,:).',vdc(k),0);
    expected = 0.1*previous.vabc_V + 0.9*current.vabc_V;
    verifyEqual(testCase,reconstructed.vabc_V,expected,'AbsTol',1e-13);
end
end

function addProjectPaths()
root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root, 'config'));
addpath(fullfile(root, 'src'));
end
