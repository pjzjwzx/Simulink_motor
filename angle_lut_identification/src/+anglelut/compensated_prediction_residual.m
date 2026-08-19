function residual = compensated_prediction_residual( ...
        stage1Residual,expectedAmplitude,directionSign,compensation)
%COMPENSATED_PREDICTION_RESIDUAL Full-PM frozen Stage-2 current residual.
%   Stage 1 intentionally omits the PM back-EMF term so that its residual
%   direction exposes angle error. Stage 2 subtracts the PM term predicted
%   by the frozen compensation; no truth signal is used here.

stage1Residual = double(stage1Residual);
assert(size(stage1Residual,2) == 2, ...
    'anglelut:CompensatedResidualShape','Residual must be N-by-2.');
expectedAmplitude = double(expectedAmplitude(:));
directionSign = double(directionSign(:));
compensation = double(compensation(:));
n = size(stage1Residual,1);
assert(numel(expectedAmplitude) == n && numel(directionSign) == n && ...
    numel(compensation) == n,'anglelut:CompensatedResidualSize', ...
    'All compensated-residual inputs must have N samples.');
signedAmplitude = directionSign.*expectedAmplitude;
estimatedPm = signedAmplitude.*[sin(compensation),cos(compensation)];
residual = stage1Residual-estimatedPm;
end
