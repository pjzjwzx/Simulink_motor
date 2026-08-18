function tests = testHarnessIntervalTiming
%THARNESSINTERVALTIMING PWM-interval hold contract for nonideal paths.
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root,'config'));
addpath(fullfile(root,'src'));
testCase.TestData.root = root;
testCase.TestData.cfg = default_config();
end

function testTimingContractDeclaresBoundaryHeldNonidealities(testCase)
t = timing_contract();
verifyEqual(testCase,t.nonideal_current_sign_sample_phase_s,0);
verifyEqual(testCase,t.nonideal_interval_hold_s,t.T_ident_s);
verifyTrue(testCase,contains(t.nonideal_interval_rule, ...
    "sampled at the PWM boundary"));
verifyTrue(testCase,contains(t.nonideal_interval_rule, ...
    "held for the complete interval"));
end

function testSavedHarnessContainsBoundaryCurrentHolds(testCase)
[model,cleanup] = local_load_harness(testCase.TestData.root); %#ok<ASGLU>
paths = { ...
    [model '/Stage1_Duty_Nonideal/iabc_at_pwm_boundary'], ...
    [model '/Stage1_Voltage_Drop/iabc_at_pwm_boundary']};
for k = 1:numel(paths)
    verifyGreaterThan(testCase,getSimulinkBlockHandle(paths{k}),0);
    verifyEqual(testCase,get_param(paths{k},'BlockType'),'ZeroOrderHold');
    verifyEqual(testCase,get_param(paths{k},'SampleTime'),'[T_ident 0]');
end
end

function testCompiledNonidealOutputsAreConstantForOnePwmInterval(testCase)
[model,cleanup] = local_load_harness(testCase.TestData.root); %#ok<ASGLU>
cfg = testCase.TestData.cfg;
set_param(model,'SimulationCommand','update');
feval(model,[],[],[],'compile');
compileCleanup = onCleanup(@() local_terminate(model));

intervalBlocks = { ...
    [model '/Stage1_Duty_Nonideal/Apply_Duty_Nonidealities'], ...
    [model '/Stage1_Duty_Nonideal/duty_effective'], ...
    [model '/Stage1_Duty_Nonideal/min_pulse_flag'], ...
    [model '/Stage1_Voltage_Drop/apply_drop'], ...
    [model '/Stage1_Voltage_Drop/vabc_plant']};
for k = 1:numel(intervalBlocks)
    local_verify_sample_time(testCase,intervalBlocks{k}, ...
        [cfg.timing.T_ident_s,0]);
end

observerBlocks = { ...
    [model '/Stage1_Observer_Taps/duty_applied_sample'], ...
    [model '/Stage1_Observer_Taps/min_pulse_flag_sample'], ...
    [model '/Stage1_Observer_Taps/vabc_plant_sample']};
for k = 1:numel(observerBlocks)
    local_verify_sample_time(testCase,observerBlocks{k}, ...
        [cfg.timing.T_ident_s,cfg.timing.identification_event_offset_s]);
end

feval(model,[],[],[],'term');
end

function local_verify_sample_time(testCase,path,expected)
actual = double(get_param(path,'CompiledSampleTime'));
verifyEqual(testCase,actual,expected,'AbsTol',32*eps(max(expected(1),1e-6)), ...
    sprintf('%s must be held for one complete PWM interval.',path));
end

function [model,cleanup] = local_load_harness(root)
harnessPath = fullfile(root,'models','angle_lut_harness.slx');
assert(isfile(harnessPath),'Stage-1 harness is missing: %s',harnessPath);
[~,model] = fileparts(harnessPath);
if bdIsLoaded(model)
    close_system(model,0);
end
load_system(harnessPath);
cleanup = onCleanup(@() local_close(model));
end

function local_terminate(model)
try
    feval(model,[],[],[],'term');
catch
end
end

function local_close(model)
local_terminate(model);
if bdIsLoaded(model)
    close_system(model,0);
end
end
