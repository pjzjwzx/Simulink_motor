function [averageData, support] = interval_average(eventData, delay_s, interval_s)
%INTERVAL_AVERAGE Average event-held data over a delayed fixed interval.
%   EVENTDATA(k,:) is the value effective from nominal boundary k to k+1.
%   The returned row k is the exact zero-order-held average over
%   [boundary_k-delay, boundary_k-delay+interval).  A fractional delay
%   therefore combines the two PWM intervals crossed by that window.

validateattributes(delay_s, {'numeric'}, ...
    {'real','finite','scalar','nonnegative'});
validateattributes(interval_s, {'numeric'}, ...
    {'real','finite','scalar','positive'});

data = double(eventData);
if isvector(data)
    data = data(:);
end
n = size(data,1);
ratio = double(delay_s) / double(interval_s);
nearestInteger = round(ratio);
ratioTolerance = 64 * eps(max(1,abs(ratio)));
if abs(ratio - nearestInteger) <= ratioTolerance
    wholeIntervals = nearestInteger;
    previousFraction = 0;
else
    wholeIntervals = floor(ratio);
    previousFraction = ratio - wholeIntervals;
end
currentFraction = 1 - previousFraction;

currentIndex = (1:n).' - wholeIntervals;
previousIndex = currentIndex - 1;
valid = currentIndex >= 1 & currentIndex <= n;
if previousFraction > 0
    valid = valid & previousIndex >= 1 & previousIndex <= n;
end

averageData = NaN(size(data));
rows = find(valid);
if previousFraction == 0
    averageData(rows,:) = data(currentIndex(rows),:);
else
    averageData(rows,:) = currentFraction .* data(currentIndex(rows),:) + ...
        previousFraction .* data(previousIndex(rows),:);
end

support.whole_intervals = wholeIntervals;
support.previous_fraction = previousFraction;
support.current_fraction = currentFraction;
support.current_index = currentIndex;
support.previous_index = previousIndex;
support.valid = valid;
end
