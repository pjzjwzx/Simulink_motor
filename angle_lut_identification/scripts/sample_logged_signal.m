function values = sample_logged_signal(signal, queryTime, method)
%SAMPLE_LOGGED_SIGNAL Sample timeseries/structure/numeric logging data.

if nargin < 3, method = 'linear'; end
if isa(signal, 'timeseries')
    time = double(signal.Time(:));
    data = signal.Data;
elseif isstruct(signal) && isfield(signal,'time') && isfield(signal,'signals')
    time = double(signal.time(:));
    data = signal.signals.values;
elseif istimetable(signal)
    time = seconds(signal.Properties.RowTimes - signal.Properties.RowTimes(1));
    data = signal.Variables;
else
    error('anglelut:LogFormat','Unsupported logged signal class %s.',class(signal));
end

data = squeeze(data);
if isvector(data)
    data = data(:);
elseif size(data,1) ~= numel(time) && size(data,2) == numel(time)
    data = data.';
elseif size(data,1) ~= numel(time) && ndims(data) > 2 && size(data,ndims(data)) == numel(time)
    order = [ndims(data), 1:ndims(data)-1];
    data = reshape(permute(data,order), numel(time), []);
end
if size(data,1) ~= numel(time)
    error('anglelut:LogShape','Logged data length does not match its time vector.');
end

% INTERP1 does not accept logical or fixed-width integer sample arrays.
% Stage-1 validity/flag logs are boolean, so promote all numeric samples to
% double here and restore logical semantics at the caller.
if isnumeric(data) || islogical(data)
    data = double(data);
end

[time, uniqueIndex] = unique(time, 'stable');
data = data(uniqueIndex,:);
if strcmpi(method,'previous')
    values = interp1(time,data,double(queryTime(:)),'previous','extrap');
else
    values = interp1(time,data,double(queryTime(:)),'linear','extrap');
end
end
