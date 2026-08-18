function inventory = collect_file_inventory(projectRoot)
%COLLECT_FILE_INVENTORY Build a deterministic, read-only project manifest.
%   INVENTORY contains project-relative paths, byte sizes, UTC modification
%   times, and lowercase SHA256 digests. Generated run/build artifacts under
%   any results or slprj directory, and Simulink cache (*.slxc) files, are
%   deliberately excluded.

assert((ischar(projectRoot) && isrow(projectRoot)) || ...
    (isstring(projectRoot) && isscalar(projectRoot)), ...
    'anglelut:InventoryRoot', 'projectRoot must be scalar text.');
projectRoot = local_canonical_path(projectRoot);
assert(isfolder(projectRoot), 'anglelut:InventoryRoot', ...
    'Project root does not exist: %s', projectRoot);

listing = dir(fullfile(projectRoot, '**', '*'));
listing = listing(~[listing.isdir]);

relativePath = strings(0,1);
sizeBytes = zeros(0,1,'uint64');
mtimeUtc = strings(0,1);
sha256 = strings(0,1);

for k = 1:numel(listing)
    absolutePath = local_canonical_path(fullfile( ...
        listing(k).folder, listing(k).name));
    relative = local_relative_path(projectRoot, absolutePath);
    relative = replace(string(relative), "\", "/");
    components = split(lower(relative), '/');
    excludedDirectory = any(components == "results" | components == "slprj");
    excludedExtension = endsWith(lower(relative), '.slxc');
    if excludedDirectory || excludedExtension
        continue;
    end

    timestamp = datetime(listing(k).datenum, 'ConvertFrom', 'datenum', ...
        'TimeZone', 'local');
    timestamp.TimeZone = 'UTC';
    timestamp.Format = 'yyyy-MM-dd''T''HH:mm:ss.SSS''Z''';

    relativePath(end+1,1) = relative; %#ok<AGROW>
    sizeBytes(end+1,1) = uint64(listing(k).bytes); %#ok<AGROW>
    mtimeUtc(end+1,1) = string(timestamp); %#ok<AGROW>
    sha256(end+1,1) = string(file_sha256(absolutePath)); %#ok<AGROW>
end

[~, order] = sort(lower(relativePath));
inventory = table(relativePath(order), sizeBytes(order), mtimeUtc(order), ...
    sha256(order), 'VariableNames', ...
    {'relative_path','size_bytes','mtime_utc','sha256'});
end

function canonical = local_canonical_path(path)
canonical = char(java.io.File(char(path)).getCanonicalPath());
end

function relative = local_relative_path(rootPath, absolutePath)
rootPrefix = [rootPath filesep];
if ispc
    isChild = startsWith(lower(absolutePath), lower(rootPrefix));
else
    isChild = startsWith(absolutePath, rootPrefix);
end
assert(isChild, 'anglelut:InventoryOutsideRoot', ...
    'Inventory path is outside the project root: %s', absolutePath);
relative = absolutePath(numel(rootPrefix)+1:end);
end
