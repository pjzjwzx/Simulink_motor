function cfg = setup_project()
%SETUP_PROJECT Configure deterministic paths and temporary build folders.

root = fileparts(mfilename('fullpath'));
addpath(root);
addpath(fullfile(root, 'config'));
addpath(fullfile(root, 'scripts'));
addpath(fullfile(root, 'src'));
addpath(fullfile(root, 'tests'));

cacheFolder = fullfile(tempdir, 'angle_lut_stage1_cache');
codegenFolder = fullfile(tempdir, 'angle_lut_stage1_codegen');
if ~exist(cacheFolder, 'dir'), mkdir(cacheFolder); end
if ~exist(codegenFolder, 'dir'), mkdir(codegenFolder); end
Simulink.fileGenControl('set', 'CacheFolder', cacheFolder, ...
    'CodeGenFolder', codegenFolder, 'createDir', true);

cfg = default_config();
% Stable aliases used by the automation layer.
cfg.project_root = root;
cfg.source_model = cfg.project.baseline_model;
cfg.harness_model = cfg.project.harness_model;
cfg.theory_pdf = fullfile(fileparts(root), '..', '..', '..', '..', ...
    'Download', 'Angle_LUT_Theory_Review_v1.1.pdf');
cfg.implementation_doc = fullfile(fileparts(root), '..', '..', '..', '..', ...
    'Download', 'Codex_Simulink_Angle_LUT_Implementation_Spec.docx');

% The workspace layout is Windows-specific in this project; resolve the
% authoritative attached sources directly when the generic relative form
% above does not point at them.
if ~exist(cfg.theory_pdf,'file')
    cfg.theory_pdf = 'D:\Download\Angle_LUT_Theory_Review_v1.1.pdf';
end
if ~exist(cfg.implementation_doc,'file')
    cfg.implementation_doc = 'D:\Download\Codex_Simulink_Angle_LUT_Implementation_Spec.docx';
end
end
