function qc = compute_quality_metrics(EEG, config)
% COMPUTE_QUALITY_METRICS Automated EEG quality control
%   qc = compute_quality_metrics(EEG, config)
%   Checks: channel variance, amplitude, duration, flatlines
%   Returns: struct with .passed, .status, .warnings, and metrics

qc = struct();
qc.duration = EEG.pnts / EEG.srate;
qc.samplingRate = EEG.srate;
qc.numChannels = EEG.nbchan;
qc.timestamp = datetime('now');
qc.warnings = {};

% Channel variance (detect dead channels)
channelVariance = var(EEG.data, [], 2);
qc.meanVariance = mean(channelVariance);
qc.channelVariances = channelVariance;
qc.badChannels = find(channelVariance < config.qc.minVarianceThreshold);
qc.numBadChannels = length(qc.badChannels);

if qc.numBadChannels > 0
    badNames = {EEG.chanlocs(qc.badChannels).labels};
    qc.warnings{end+1} = sprintf('Low variance (%d): %s', qc.numBadChannels, strjoin(badNames, ', '));
end

% Amplitude checks
qc.maxAmplitude = max(abs(EEG.data(:)));
qc.meanAmplitude = mean(abs(EEG.data(:)));

if qc.maxAmplitude > 500
    qc.warnings{end+1} = sprintf('High amplitude: %.1f uV', qc.maxAmplitude);
end
if qc.meanAmplitude < 0.1
    qc.warnings{end+1} = sprintf('Low amplitude: %.3f uV', qc.meanAmplitude);
end

% Duration check
if qc.duration < config.qc.minDuration
    qc.warnings{end+1} = sprintf('Short recording: %.1f s', qc.duration);
end

% Sampling rate check
if qc.samplingRate < 100
    qc.warnings{end+1} = sprintf('Low sampling rate: %.1f Hz', qc.samplingRate);
end

% Flatline check
for ch = 1:EEG.nbchan
    if std(EEG.data(ch, :)) == 0
        qc.warnings{end+1} = sprintf('Flatline: %s', EEG.chanlocs(ch).labels);
    end
end

% Pass/Fail
qc.passed = true;
if qc.numBadChannels > config.qc.maxBadChannels
    qc.passed = false;
    qc.warnings{end+1} = sprintf('CRITICAL: %d bad channels', qc.numBadChannels);
end
if qc.meanVariance < config.qc.minVarianceThreshold
    qc.passed = false;
    qc.warnings{end+1} = 'CRITICAL: Low variance';
end
if qc.duration < config.qc.minDuration
    qc.passed = false;
end

qc.numWarnings = length(qc.warnings);
if qc.passed, qc.status = 'PASS'; else, qc.status = 'FAIL'; end
end
