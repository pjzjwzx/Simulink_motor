function modelPath = build_stage2_harness()
%BUILD_STAGE2_HARNESS Copy Stage 1 and add a disabled-by-default active LUT.
%   The Stage-1 harness and preserved source model are hash-guarded and are
%   never saved by this builder.

modelsDir = fileparts(mfilename('fullpath'));
projectRoot = fileparts(modelsDir);
addpath(projectRoot);
addpath(fullfile(projectRoot,'scripts'));
stage1Path = fullfile(modelsDir,'angle_lut_harness.slx');
modelPath = fullfile(modelsDir,'angle_lut_stage2_harness.slx');
sourcePath = fullfile(fileparts(projectRoot),'FOC_fw_hifi_v1_0709backup.slx');
assert(isfile(stage1Path),'anglelut:MissingStage1Harness', ...
    'The passed Stage-1 harness is required before Stage 2.');

sourceHashBefore = file_sha256(sourcePath);
stage1HashBefore = file_sha256(stage1Path);
stage1Model = 'angle_lut_harness';
stage2Model = 'angle_lut_stage2_harness';
if bdIsLoaded(stage1Model), close_system(stage1Model,0); end
if bdIsLoaded(stage2Model), close_system(stage2Model,0); end

load_system(stage1Path);
save_system(stage1Model,modelPath);
close_system(stage1Model,0);
load_system(modelPath);
assert(strcmp(get_param(stage2Model,'Dirty'),'off'), ...
    'anglelut:Stage2CopyDirty','The copied Stage-2 model opened dirty.');

local_suppress_inherited_display(stage2Model);
local_install_workspace(stage2Model);
[compensation,controlTheta,correction] = ...
    local_install_active_compensation(stage2Model);
local_install_stage2_observer(stage2Model,controlTheta,correction);
set_param(compensation,'TreatAsAtomicUnit','on');
Simulink.BlockDiagram.arrangeSystem(compensation,'FullLayout','true');
set_param(stage2Model,'SimulationCommand','update');
save_system(stage2Model,modelPath);
close_system(stage2Model,0);

assert(strcmpi(sourceHashBefore,file_sha256(sourcePath)), ...
    'anglelut:SourceHashChanged','Stage-2 builder changed the source model.');
assert(strcmpi(stage1HashBefore,file_sha256(stage1Path)), ...
    'anglelut:Stage1HarnessHashChanged', ...
    'Stage-2 builder changed the passed Stage-1 harness.');
end

function local_suppress_inherited_display(model)
% The inherited SVPWM chart has three missing semicolons.  They do not
% affect numerics, but otherwise print three values at every base step and
% make a formal Stage-2 matrix impractical to audit.
chartPath = [model '/MATLAB Function2'];
root = sfroot;
chart = root.find('-isa','Stateflow.EMChart','Path',chartPath);
assert(isscalar(chart),'anglelut:Stage2MissingSvpwmChart', ...
    'The inherited SVPWM chart was not found.');
script = chart.Script;
for name = ["CMPA","CMPB","CMPC"]
    oldLine = sprintf('%s = 1- %s',name,name);
    newLine = sprintf('%s = 1- %s;',name,name);
    assert(contains(script,oldLine),'anglelut:Stage2SvpwmScriptChanged', ...
        'The inherited SVPWM display-suppression target changed.');
    script = replace(script,oldLine,newLine);
end
chart.Script = script;
end

function local_install_workspace(model)
mw = get_param(model,'ModelWorkspace');
mw.assignin('stage2_active_enable',false);
mw.assignin('stage2_runtime_lut_e_rad',zeros(512,1));
mw.assignin('stage2_runtime_nodes',512);
end

function [block,controlTheta,correction] = ...
        local_install_active_compensation(model)
block = [model '/Stage2_Active_LUT_Compensation'];
assert(getSimulinkBlockHandle(block) < 0, ...
    'anglelut:Stage2CompensationAlreadyExists', ...
    'Stage-2 compensation block already exists.');
add_block('simulink/Ports & Subsystems/Subsystem',block, ...
    'Position',[1120 250 1350 390]);
local_delete_template_ports(block);

add_block('simulink/Ports & Subsystems/In1',[block '/theta_raw_e'], ...
    'Port','1','Position',[25 45 55 65]);
add_block('simulink/Ports & Subsystems/In1',[block '/theta_raw_m'], ...
    'Port','2','Position',[25 125 55 145]);
add_block('simulink/Discrete/Unit Delay',[block '/theta_m_latency'], ...
    'SampleTime','Ts','InitialCondition','0', ...
    'Position',[90 115 145 155]);
add_block('simulink/Sources/Constant',[block '/runtime_lut'], ...
    'Value','stage2_runtime_lut_e_rad', ...
    'Position',[90 205 205 235]);
algorithm = [block '/periodic_interp_512'];
add_block('simulink/User-Defined Functions/MATLAB Function',algorithm, ...
    'Position',[245 105 450 230]);
root = sfroot;
chart = root.find('-isa','Stateflow.EMChart','Path',algorithm);
assert(isscalar(chart),'anglelut:Stage2InterpolatorCreationFailed', ...
    'Could not create the Stage-2 runtime interpolator.');
chart.Script = sprintf([ ...
    'function value = f(phi,lut)\n' ...
    '%%#codegen\n' ...
    'M = 512;\n' ...
    'phi = mod(phi,2*pi);\n' ...
    'u = M*phi/(2*pi);\n' ...
    'j0z = floor(u);\n' ...
    'alpha = u-j0z;\n' ...
    'j0 = j0z+1;\n' ...
    'j1 = mod(j0z+1,M)+1;\n' ...
    'value = (1-alpha)*lut(j0)+alpha*lut(j1);\n' ...
    'end\n']);
add_block('simulink/Math Operations/Sum',[block '/subtract_lut'], ...
    'Inputs','+-','Position',[490 40 520 100]);
add_block('simulink/Math Operations/Math Function',[block '/wrap_control'], ...
    'Operator','mod','Position',[555 40 650 80]);
add_block('simulink/Sources/Constant',[block '/two_pi'], ...
    'Value','2*pi','Position',[555 95 615 125]);
add_block('simulink/Sources/Constant',[block '/active_enable'], ...
    'Value','stage2_active_enable','OutDataTypeStr','boolean', ...
    'Position',[545 160 655 190]);
add_block('simulink/Signal Routing/Switch',[block '/active_bypass'], ...
    'Criteria','u2 ~= 0','Threshold','0.5', ...
    'Position',[700 35 750 125]);
add_block('simulink/Ports & Subsystems/Out1',[block '/theta_control_e'], ...
    'Port','1','Position',[805 55 835 75]);
add_block('simulink/Ports & Subsystems/Out1',[block '/lut_compensation_e'], ...
    'Port','2','Position',[805 185 835 205]);

add_line(block,'theta_raw_m/1','theta_m_latency/1','autorouting','on');
add_line(block,'theta_m_latency/1','periodic_interp_512/1','autorouting','on');
add_line(block,'runtime_lut/1','periodic_interp_512/2','autorouting','on');
add_line(block,'theta_raw_e/1','subtract_lut/1','autorouting','on');
add_line(block,'periodic_interp_512/1','subtract_lut/2','autorouting','on');
add_line(block,'subtract_lut/1','wrap_control/1','autorouting','on');
add_line(block,'two_pi/1','wrap_control/2','autorouting','on');
add_line(block,'wrap_control/1','active_bypass/1','autorouting','on');
add_line(block,'active_enable/1','active_bypass/2','autorouting','on');
add_line(block,'theta_raw_e/1','active_bypass/3','autorouting','on');
add_line(block,'active_bypass/1','theta_control_e/1','autorouting','on');
add_line(block,'periodic_interp_512/1','lut_compensation_e/1', ...
    'autorouting','on');

rawTheta = [model '/Position_Sensing_Encoder_Latency_Theta'];
encoder = [model '/Position_Sensing_Encoder'];
rawPorts = get_param(rawTheta,'PortHandles');
encoderPorts = get_param(encoder,'PortHandles');
blockPorts = get_param(block,'PortHandles');
add_line(model,rawPorts.Outport(1),blockPorts.Inport(1),'autorouting','on');
add_line(model,encoderPorts.Outport(3),blockPorts.Inport(2),'autorouting','on');

controllerBlocks = {[model '/MATLAB Function4'],[model '/MATLAB Function5']};
for k = 1:numel(controllerBlocks)
    ports = get_param(controllerBlocks{k},'PortHandles');
    local_delete_input_line(ports.Inport(3));
    add_line(model,blockPorts.Outport(1),ports.Inport(3),'autorouting','on');
end
controlTheta = blockPorts.Outport(1);
correction = blockPorts.Outport(2);
end

function local_install_stage2_observer(model,controlTheta,correction)
observer = [model '/Stage2_Observer_Taps'];
add_block('simulink/Ports & Subsystems/Subsystem',observer, ...
    'Position',[2190 820 2390 1010]);
local_delete_template_ports(observer);
names = {'control_theta_e','lut_compensation_e','torque_true_Nm'};
for k = 1:numel(names)
    y = 30+(k-1)*70;
    add_block('simulink/Ports & Subsystems/In1',[observer '/' names{k}], ...
        'Port',num2str(k),'Position',[25 y 55 y+20]);
    add_block('simulink/Discrete/Zero-Order Hold', ...
        [observer '/' names{k} '_sample'], ...
        'SampleTime','[T_ident stage1_ident_phase_s]', ...
        'Position',[95 y-5 190 y+25]);
    add_block('simulink/Sinks/To Workspace', ...
        [observer '/' names{k} '_log'], ...
        'VariableName',['stage2_' names{k}], ...
        'SaveFormat','Timeseries','Position',[235 y-5 355 y+25]);
    add_line(observer,[names{k} '/1'],[names{k} '_sample/1'], ...
        'autorouting','on');
    add_line(observer,[names{k} '_sample/1'],[names{k} '_log/1'], ...
        'autorouting','on');
end
observerPorts = get_param(observer,'PortHandles');
add_line(model,controlTheta,observerPorts.Inport(1),'autorouting','on');
add_line(model,correction,observerPorts.Inport(2),'autorouting','on');

busSelector = find_system(model,'SearchDepth',1,'BlockType','BusSelector');
assert(isscalar(busSelector),'anglelut:Stage2AmbiguousMotorBus', ...
    'Expected one top-level motor Bus Selector.');
busPorts = get_param(busSelector{1},'PortHandles');
assert(numel(busPorts.Outport) >= 2,'anglelut:Stage2MissingTorque', ...
    'MtrTrq output is unavailable.');
add_line(model,busPorts.Outport(2),observerPorts.Inport(3),'autorouting','on');
Simulink.BlockDiagram.arrangeSystem(observer,'FullLayout','true');
end

function local_delete_template_ports(subsystem)
ports = find_system(subsystem,'SearchDepth',1,'LookUnderMasks','all', ...
    'FollowLinks','on','BlockType','Inport');
ports = [ports; find_system(subsystem,'SearchDepth',1, ...
    'LookUnderMasks','all','FollowLinks','on','BlockType','Outport')];
for k = 1:numel(ports)
    delete_block(ports{k});
end
end

function local_delete_input_line(portHandle)
lineHandle = get_param(portHandle,'Line');
if lineHandle ~= -1
    delete_line(lineHandle);
end
end
