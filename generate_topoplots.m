function generate_topoplots(fileResults, EEG, config, filename)
% GENERATE_TOPOPLOTS Create topographic maps of PLI connectivity
%   generate_topoplots(fileResults, EEG, config, filename)
%   Saves figure to: output/figures/topoplot_[filename].png

if ~config.visualization.generateTopoplots, return; end

bandNames = fieldnames(config.bands);
numBands = length(bandNames);

% Determine metric (prefer wPLI)
if config.analysis.computeWPLI
    metricSuffix = '_wPLI';
    metricName = 'wPLI';
else
    metricSuffix = '';
    metricName = 'PLI';
end

% Create output directory
figuresPath = fullfile(config.output.folder, config.output.figuresSubfolder);
if ~exist(figuresPath, 'dir'), mkdir(figuresPath); end

% Create figure
fig = figure('Name', sprintf('%s - %s', metricName, filename), ...
    'Position', [100, 100, 1400, 900], 'Color', 'white', 'Visible', 'off');

% Plot each band
for bandIdx = 1:numBands
    bandName = bandNames{bandIdx};
    freqRange = config.bands.(bandName);
    subplot(2, 3, bandIdx);

    pliValues = zeros(EEG.nbchan, 1);

    for pairIdx = 1:size(config.pairs, 1)
        leftLabel = config.pairs{pairIdx, 1};
        rightLabel = config.pairs{pairIdx, 2};
        columnName = sprintf('%s_%s_%s%s', bandName, leftLabel, rightLabel, metricSuffix);

        if isfield(fileResults, columnName)
            pliValue = fileResults.(columnName);
            leftIdx = findChannelIndex({EEG.chanlocs.labels}, leftLabel);
            rightIdx = findChannelIndex({EEG.chanlocs.labels}, rightLabel);
            if ~isnan(leftIdx) && ~isnan(rightIdx) && ~isnan(pliValue)
                pliValues(leftIdx) = pliValue;
                pliValues(rightIdx) = pliValue;
            end
        end
    end

    try
        topoplot(pliValues, EEG.chanlocs, 'maplimits', [0 1], 'electrodes', 'on', ...
            'colormap', jet, 'emarker2', {1:EEG.nbchan, 'o', 'k', 4, 1});
        title(sprintf('%s [%.1f-%.1f Hz]', bandName, freqRange(1), freqRange(2)));
        c = colorbar; ylabel(c, metricName);
    catch ME
        text(0.5, 0.5, sprintf('Error: %s', ME.message), 'HorizontalAlignment', 'center', 'Color', 'red');
        title(sprintf('%s (Error)', bandName));
    end
end

[~, cleanFilename, ~] = fileparts(filename);
sgtitle(sprintf('Connectivity (%s) - %s', metricName, cleanFilename), 'Interpreter', 'none');

% Save figure
if config.visualization.saveFigures
    safeFilename = regexprep(cleanFilename, '[^\w\-]', '_');
    outputPath = fullfile(figuresPath, sprintf('topoplot_%s.%s', safeFilename, config.visualization.figureFormat));
    try
        print(fig, outputPath, sprintf('-d%s', config.visualization.figureFormat), ...
            sprintf('-r%d', config.visualization.figureResolution));
    catch ME
        warning('generate_topoplots:saveFailed', 'Save failed: %s', ME.message);
    end
end

if config.advanced.closeAllFigures, close(fig); end
end

function channelIdx = findChannelIndex(channelLabels, targetLabel)
matchIndices = find(contains(channelLabels, targetLabel, 'IgnoreCase', true));
if isempty(matchIndices)
    channelIdx = NaN;
elseif length(matchIndices) == 1
    channelIdx = matchIndices;
else
    matchedLabels = channelLabels(matchIndices);
    [~, shortestIdx] = min(cellfun(@length, matchedLabels));
    channelIdx = matchIndices(shortestIdx);
end
end
