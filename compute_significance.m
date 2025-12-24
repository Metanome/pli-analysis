function [isSignificant, pValue, threshold] = compute_significance(phase1, phase2, observedPLI, numSurrogates, alphaLevel)
% COMPUTE_SIGNIFICANCE Surrogate-based significance testing for PLI
%   [isSig, pVal, thresh] = compute_significance(phase1, phase2, pli, nSurr, alpha)
%   Uses circular shift method to build null distribution.
%   Reference: Bastos & Schoffelen (2016), Frontiers in Systems Neuroscience

if nargin < 4 || isempty(numSurrogates), numSurrogates = 1000; end
if nargin < 5 || isempty(alphaLevel), alphaLevel = 0.05; end

if length(phase1) ~= length(phase2)
    error('Phase series must have same length');
end

numSamples = length(phase1);
surrogatePLI = zeros(numSurrogates, 1);

for s = 1:numSurrogates
    shift = randi([1, numSamples]);
    surrogate_phase2 = circshift(phase2(:)', [0, shift]);
    phaseDiff = phase1 - surrogate_phase2;
    surrogatePLI(s) = abs(mean(sign(sin(phaseDiff))));
end

threshold = prctile(surrogatePLI, (1 - alphaLevel) * 100);
isSignificant = observedPLI > threshold;
pValue = mean(surrogatePLI >= observedPLI);

if pValue == 0
    pValue = 1 / (numSurrogates + 1);
end
end
