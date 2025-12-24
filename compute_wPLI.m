function wpli = compute_wPLI(phase1, phase2)
% COMPUTE_WPLI Weighted Phase Lag Index
%   wpli = compute_wPLI(phase1, phase2)
%   Inputs: phase1, phase2 - phase time series (radians)
%   Output: wpli - value in [0, 1]
%   Reference: Vinck et al. (2011), NeuroImage

phaseDiff = phase1 - phase2;
imagComponent = sin(phaseDiff);

numerator = abs(mean(abs(imagComponent) .* sign(imagComponent)));
denominator = mean(abs(imagComponent));

if denominator == 0
    wpli = 0;
else
    wpli = numerator / denominator;
end

wpli = max(0, min(1, wpli));
end
