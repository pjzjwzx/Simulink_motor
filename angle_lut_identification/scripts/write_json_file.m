function write_json_file(path, value)
%WRITE_JSON_FILE Write pretty JSON using UTF-8.

text = jsonencode(value, PrettyPrint=true);
fid = fopen(path, 'w', 'n', 'UTF-8');
if fid < 0, error('anglelut:IO', 'Cannot open %s for writing.', path); end
cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid, '%s\n', text);
end

