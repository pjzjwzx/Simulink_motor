function tests = testAuditCollectors
%TESTAUDITCOLLECTORS Verify deterministic audit metadata collection.
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root, 'config'));
addpath(fullfile(root, 'scripts'));
testCase.TestData.projectRoot = root;
end

function testFileInventoryHashesAndExclusions(testCase)
fixtureRoot = tempname;
mkdir(fixtureRoot);
cleanup = onCleanup(@() local_remove_fixture(fixtureRoot));

local_write_fixture(fullfile(fixtureRoot,'keep.txt'), 'abc');
local_write_fixture(fullfile(fixtureRoot,'src','algorithm.m'), 'x = 1;');
local_write_fixture(fullfile(fixtureRoot,'results','run1','ignored.txt'), 'result');
local_write_fixture(fullfile(fixtureRoot,'build','slprj','ignored.obj'), 'object');
local_write_fixture(fullfile(fixtureRoot,'cache','ignored.slxc'), 'cache');
local_write_fixture(fullfile(fixtureRoot,'cache','IGNORED.SLXC'), 'cache');

inventory = collect_file_inventory(fixtureRoot);
verifyEqual(testCase, inventory.Properties.VariableNames, ...
    {'relative_path','size_bytes','mtime_utc','sha256'});
verifyEqual(testCase, inventory.relative_path, ...
    ["keep.txt"; "src/algorithm.m"]);
verifyEqual(testCase, inventory.size_bytes, uint64([3; 6]));
verifyTrue(testCase, all(strlength(inventory.sha256) == 64));
verifyTrue(testCase, all(endsWith(inventory.mtime_utc, 'Z')));
verifyEqual(testCase, inventory.sha256(1), ...
    string(file_sha256(fullfile(fixtureRoot,'keep.txt'))));

clear cleanup;
end

function testEnvironmentManifestReadsModelWithoutRetainingIt(testCase)
sourceModel = fullfile(fileparts(testCase.TestData.projectRoot), ...
    'FOC_fw_hifi_v1_0709backup.slx');
[~, modelName] = fileparts(sourceModel);
loadedBefore = bdIsLoaded(modelName);

manifest = collect_environment_manifest(sourceModel, timing_contract());

verifyEqual(testCase, manifest.schema_version, ...
    'angle-lut-environment-v1');
verifyTrue(testCase, all(isfield(manifest.products, ...
    {'Name','Version','Release'})));
productNames = string({manifest.products.Name});
verifyTrue(testCase, any(productNames == "MATLAB"));
verifyTrue(testCase, any(productNames == "Simulink"));
verifyEqual(testCase, manifest.model.solver_type, 'Variable-step');
verifyEqual(testCase, manifest.model.solver, 'VariableStepAuto');
verifyEqual(testCase, manifest.model.stop_time_s, 10, 'AbsTol', eps);
verifyEqual(testCase, strlength(string(manifest.model.sha256)), 64);
verifyTrue(testCase, manifest.powergui.present);
verifyGreaterThanOrEqual(testCase, manifest.powergui.count, 1);
verifyEqual(testCase, manifest.powergui.blocks(1).mode, 'Discrete');
verifyEqual(testCase, manifest.powergui.blocks(1).sample_time_s, 5e-6, ...
    'AbsTol', eps);
verifyEqual(testCase, manifest.timing.Ts_base_s, 5e-6, 'AbsTol', eps);
verifyEqual(testCase, manifest.timing.fpwm_Hz, 20e3, 'AbsTol', eps);
verifyEqual(testCase, manifest.timing.T_ident_s, 50e-6, 'AbsTol', eps);
verifyEqual(testCase, bdIsLoaded(modelName), loadedBefore);
end

function local_write_fixture(path, contents)
folder = fileparts(path);
if ~isfolder(folder)
    mkdir(folder);
end
fid = fopen(path, 'w');
assert(fid >= 0, 'Unable to create fixture: %s', path);
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, '%s', contents);
clear cleanup;
end

function local_remove_fixture(path)
if isfolder(path)
    rmdir(path, 's');
end
end
