function manifest = collect_environment_manifest(modelPath, timing)
%COLLECT_ENVIRONMENT_MANIFEST Read software, solver, and timing metadata.
%   The returned value contains only ordinary MATLAB structs and scalars;
%   the helper does not retain Simulink handles or modify/save the model.

if nargin < 2 || isempty(timing)
    timing = timing_contract();
elseif isfield(timing, 'timing')
    timing = timing.timing;
end
assert(isstruct(timing) && isscalar(timing), ...
    'anglelut:EnvironmentTiming', 'timing must be a scalar struct.');
requiredTiming = {'base_step_s','fpwm_Hz','T_ident_s'};
assert(all(isfield(timing, requiredTiming)), ...
    'anglelut:EnvironmentTiming', ...
    'timing must contain base_step_s, fpwm_Hz, and T_ident_s.');

assert((ischar(modelPath) && isrow(modelPath)) || ...
    (isstring(modelPath) && isscalar(modelPath)), ...
    'anglelut:EnvironmentModel', 'modelPath must be scalar text.');
modelPath = local_canonical_path(modelPath);
assert(isfile(modelPath), 'anglelut:EnvironmentModel', ...
    'Model file does not exist: %s', modelPath);

collectedAt = datetime('now', 'TimeZone', 'UTC');
collectedAt.Format = 'yyyy-MM-dd''T''HH:mm:ss.SSS''Z''';
installed = ver;
products = repmat(struct('Name','','Version','','Release',''), ...
    numel(installed), 1);
for k = 1:numel(installed)
    products(k).Name = installed(k).Name;
    products(k).Version = installed(k).Version;
    products(k).Release = installed(k).Release;
end
[~, productOrder] = sort(lower(string({products.Name})));
products = products(productOrder);

[~, modelName] = fileparts(modelPath);
loadedBeforeCall = bdIsLoaded(modelName);
if loadedBeforeCall
    loadedPath = get_param(modelName, 'FileName');
    assert(local_paths_equal(modelPath, loadedPath), ...
        'anglelut:EnvironmentModelCollision', ...
        'A different model named %s is already loaded.', modelName);
else
    load_system(modelPath);
end
cleanup = onCleanup(@() local_close_owned_model(modelName, loadedBeforeCall));

stopTimeExpression = get_param(modelName, 'StopTime');
powerguiBlocks = find_system(modelName, 'LookUnderMasks', 'all', ...
    'FollowLinks', 'on', 'MatchFilter', @Simulink.match.activeVariants, ...
    'MaskType', 'PSB option menu block');
powerguiBlocks = sort(string(powerguiBlocks));
powerguiDetails = repmat(struct( ...
    'block_path','', 'mode','', 'sample_time_expression','', ...
    'sample_time_s',NaN), numel(powerguiBlocks), 1);
for k = 1:numel(powerguiBlocks)
    block = char(powerguiBlocks(k));
    names = string(get_param(block, 'MaskNames'));
    values = string(get_param(block, 'MaskValues'));
    mode = local_mask_value(names, values, "SimulationMode");
    sampleExpression = local_mask_value(names, values, "SampleTime");
    powerguiDetails(k).block_path = block;
    powerguiDetails(k).mode = char(mode);
    powerguiDetails(k).sample_time_expression = char(sampleExpression);
    powerguiDetails(k).sample_time_s = local_resolve_numeric( ...
        sampleExpression, block);
end

manifest = struct();
manifest.schema_version = 'angle-lut-environment-v1';
manifest.collected_at_utc = char(collectedAt);
manifest.matlab = struct('Name','MATLAB', 'Version',version, ...
    'Release',version('-release'));
manifest.products = products;
manifest.model = struct( ...
    'path',modelPath, ...
    'name',modelName, ...
    'sha256',file_sha256(modelPath), ...
    'loaded_before_call',loadedBeforeCall, ...
    'solver_type',get_param(modelName, 'SolverType'), ...
    'solver',get_param(modelName, 'Solver'), ...
    'stop_time_expression',stopTimeExpression, ...
    'stop_time_s',local_resolve_numeric(stopTimeExpression, modelName));
manifest.powergui = struct( ...
    'present',~isempty(powerguiDetails), ...
    'count',numel(powerguiDetails), ...
    'blocks',powerguiDetails);
manifest.timing = struct( ...
    'Ts_base_s',double(timing.base_step_s), ...
    'fpwm_Hz',double(timing.fpwm_Hz), ...
    'T_ident_s',double(timing.T_ident_s));

% Keep the cleanup object alive until the plain-data result is complete.
clear cleanup;
end

function value = local_mask_value(names, values, requestedName)
index = find(strcmpi(names, requestedName), 1);
if isempty(index)
    value = "";
else
    value = values(index);
end
end

function value = local_resolve_numeric(expression, context)
expression = char(expression);
value = str2double(expression);
if isfinite(value)
    return;
end
try
    resolved = slResolve(expression, context);
    if isnumeric(resolved) && isscalar(resolved) && isreal(resolved) && ...
            isfinite(resolved)
        value = double(resolved);
    end
catch
    value = NaN;
end
end

function local_close_owned_model(modelName, loadedBeforeCall)
if ~loadedBeforeCall && bdIsLoaded(modelName)
    close_system(modelName, 0);
end
end

function equal = local_paths_equal(left, right)
left = local_canonical_path(left);
right = local_canonical_path(right);
if ispc
    equal = strcmpi(left, right);
else
    equal = strcmp(left, right);
end
end

function canonical = local_canonical_path(path)
canonical = char(java.io.File(char(path)).getCanonicalPath());
end
