function hash = file_sha256(path)
%FILE_SHA256 Return a lowercase SHA256 digest without modifying the file.

path = char(java.io.File(path).getCanonicalPath());
if ispc
    command = sprintf('certutil -hashfile "%s" SHA256', strrep(path, '"', '""'));
    [status, output] = system(command);
    if status ~= 0
        error('anglelut:Hash', 'certutil failed for %s: %s', path, output);
    end
    match = regexp(output, '(?im)^\s*([0-9a-f]{64})\s*$', 'tokens', 'once');
    if isempty(match)
        error('anglelut:Hash', 'Unable to parse SHA256 output for %s.', path);
    end
    hash = lower(match{1});
    return;
end

% Portable fallback. DigestInputStream performs the update inside Java;
% MATLAB only advances the stream, avoiding byte-array copy semantics.
md = java.security.MessageDigest.getInstance('SHA-256');
stream = java.security.DigestInputStream(java.io.FileInputStream(path), md);
cleanup = onCleanup(@() stream.close()); %#ok<NASGU>
while stream.read() ~= -1
end
raw = typecast(md.digest(), 'uint8');
hash = lower(reshape(dec2hex(raw, 2).', 1, []));
end
