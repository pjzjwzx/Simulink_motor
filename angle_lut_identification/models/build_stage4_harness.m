function modelPath = build_stage4_harness()
%BUILD_STAGE4_HARNESS Copy Stage 3 without modifying any passed model.
%   The Stage-4 harness owns an independent active-enable and fixed 512-node
%   runtime LUT.  Its saved state is bypassed/zero, and the inherited raw
%   identification frame remains upstream of the control-angle correction.

modelsDir = fileparts(mfilename('fullpath'));
projectRoot = fileparts(modelsDir);
addpath(projectRoot); addpath(fullfile(projectRoot,'scripts'));
sourcePath = fullfile(fileparts(projectRoot),'FOC_fw_hifi_v1_0709backup.slx');
stage1Path = fullfile(modelsDir,'angle_lut_harness.slx');
stage2Path = fullfile(modelsDir,'angle_lut_stage2_harness.slx');
stage3Path = fullfile(modelsDir,'angle_lut_stage3_harness.slx');
modelPath = fullfile(modelsDir,'angle_lut_stage4_harness.slx');
assert(isfile(stage3Path),'anglelut:MissingStage3Harness', ...
    'A passed Stage-3 harness is required before building Stage 4.');

guardPaths = {sourcePath,stage1Path,stage2Path,stage3Path};
hashBefore = cellfun(@file_sha256,guardPaths,'UniformOutput',false);
for name = ["angle_lut_stage3_harness","angle_lut_stage4_harness"]
    if bdIsLoaded(name), close_system(name,0); end
end

load_system(stage3Path);
save_system('angle_lut_stage3_harness',modelPath);
close_system('angle_lut_stage3_harness',0);
model = 'angle_lut_stage4_harness';
load_system(modelPath);

mw = get_param(model,'ModelWorkspace');
mw.assignin('stage4_active_enable',false);
mw.assignin('stage4_runtime_lut_e_rad',zeros(512,1));
mw.assignin('stage4_runtime_nodes',512);

compensation = [model '/Stage3_Active_LUT_Compensation'];
observer = [model '/Stage3_Observer_Taps'];
assert(getSimulinkBlockHandle(compensation) >= 0 && ...
    getSimulinkBlockHandle(observer) >= 0, ...
    'anglelut:Stage4CopyContract','Stage-3 blocks are missing.');
set_param([compensation '/runtime_lut'],'Value','stage4_runtime_lut_e_rad');
set_param([compensation '/active_enable'],'Value','stage4_active_enable');
set_param(compensation,'Name','Stage4_Active_LUT_Compensation');
set_param(observer,'Name','Stage4_Observer_Taps');

observer = [model '/Stage4_Observer_Taps'];
logs = find_system(observer,'LookUnderMasks','all','FollowLinks','on', ...
    'BlockType','ToWorkspace');
assert(numel(logs) == 3,'anglelut:Stage4ObserverContract', ...
    'Stage-4 observer must retain the three Stage-3 evaluation logs.');
for k = 1:numel(logs)
    value = string(get_param(logs{k},'VariableName'));
    assert(startsWith(value,"stage3_"),'anglelut:Stage4ObserverContract', ...
        'Unexpected inherited Stage-3 log name: %s',value);
    set_param(logs{k},'VariableName',char(replace(value,"stage3_","stage4_")));
end

set_param(model,'SimulationCommand','update');
save_system(model,modelPath);
close_system(model,0);

for k = 1:numel(guardPaths)
    assert(strcmpi(hashBefore{k},file_sha256(guardPaths{k})), ...
        'anglelut:Stage4BuilderChangedPassedArtifact', ...
        'Stage-4 builder changed a passed artifact: %s',guardPaths{k});
end
end
