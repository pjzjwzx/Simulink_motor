function modelPath = build_stage3_harness()
%BUILD_STAGE3_HARNESS Copy Stage 2 without modifying any passed model.

modelsDir = fileparts(mfilename('fullpath'));
projectRoot = fileparts(modelsDir);
addpath(projectRoot); addpath(fullfile(projectRoot,'scripts'));
sourcePath = fullfile(fileparts(projectRoot),'FOC_fw_hifi_v1_0709backup.slx');
stage1Path = fullfile(modelsDir,'angle_lut_harness.slx');
stage2Path = fullfile(modelsDir,'angle_lut_stage2_harness.slx');
modelPath = fullfile(modelsDir,'angle_lut_stage3_harness.slx');
assert(isfile(stage2Path),'anglelut:MissingStage2Harness', ...
    'A passed Stage-2 harness is required before building Stage 3.');
guardPaths = {sourcePath,stage1Path,stage2Path};
hashBefore = cellfun(@file_sha256,guardPaths,'UniformOutput',false);
for name = ["angle_lut_stage2_harness","angle_lut_stage3_harness"]
    if bdIsLoaded(name), close_system(name,0); end
end

load_system(stage2Path);
save_system('angle_lut_stage2_harness',modelPath);
close_system('angle_lut_stage2_harness',0);
model = 'angle_lut_stage3_harness';
load_system(modelPath);
mw = get_param(model,'ModelWorkspace');
mw.assignin('stage3_active_enable',false);
mw.assignin('stage3_runtime_lut_e_rad',zeros(512,1));
mw.assignin('stage3_runtime_nodes',512);

compensation = [model '/Stage2_Active_LUT_Compensation'];
observer = [model '/Stage2_Observer_Taps'];
assert(getSimulinkBlockHandle(compensation) >= 0 && ...
    getSimulinkBlockHandle(observer) >= 0, ...
    'anglelut:Stage3CopyContract','Stage-2 blocks are missing.');
set_param([compensation '/runtime_lut'],'Value','stage3_runtime_lut_e_rad');
set_param([compensation '/active_enable'],'Value','stage3_active_enable');
set_param(compensation,'Name','Stage3_Active_LUT_Compensation');
set_param(observer,'Name','Stage3_Observer_Taps');
observer = [model '/Stage3_Observer_Taps'];
logs = find_system(observer,'LookUnderMasks','all','FollowLinks','on', ...
    'BlockType','ToWorkspace');
for k = 1:numel(logs)
    value = string(get_param(logs{k},'VariableName'));
    set_param(logs{k},'VariableName',char(replace(value,"stage2_","stage3_")));
end
set_param(model,'SimulationCommand','update');
save_system(model,modelPath);
close_system(model,0);

for k = 1:numel(guardPaths)
    assert(strcmpi(hashBefore{k},file_sha256(guardPaths{k})), ...
        'anglelut:Stage3BuilderChangedPassedArtifact', ...
        'Stage-3 builder changed a passed artifact: %s',guardPaths{k});
end
end
