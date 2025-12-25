function generate_topoplots(fileResults, EEG, config, filename)
% GENERATE_TOPOPLOTS Create topographic maps of PLI connectivity
%   generate_topoplots(fileResults, EEG, config, filename)
%   Saves figure to: output/figures/topoplot_[filename].png

if ~config.visualization.generateTopoplots, return; end

% Check if channel locations have coordinates, if not try to add them
if isempty(EEG.chanlocs) || ~isfield(EEG.chanlocs, 'theta') || ...
        all(cellfun(@isempty, {EEG.chanlocs.theta}))
    % Try to lookup standard 10-20 coordinates
    EEG = addStandardLocations(EEG);

    % Check again
    if all(cellfun(@isempty, {EEG.chanlocs.theta}))
        warning('generate_topoplots:noCoords', 'Could not assign channel coordinates. Skipping topoplot.');
        return;
    end
end

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
    'Position', [100, 100, 1200, 800], 'Color', 'white', 'Visible', 'off');

% Plot each band
for bandIdx = 1:numBands
    bandName = bandNames{bandIdx};
    freqRange = config.bands.(bandName);
    subplot(2, 3, bandIdx);

    % Initialize PLI values for each channel
    pliValues = nan(EEG.nbchan, 1);

    for pairIdx = 1:size(config.pairs, 1)
        leftLabel = config.pairs{pairIdx, 1};
        rightLabel = config.pairs{pairIdx, 2};
        columnName = sprintf('%s_%s_%s%s', bandName, leftLabel, rightLabel, metricSuffix);

        if isfield(fileResults, columnName)
            pliValue = fileResults.(columnName);

            % Find channel indices
            leftIdx = findChannelIdx(EEG.chanlocs, leftLabel);
            rightIdx = findChannelIdx(EEG.chanlocs, rightLabel);

            % Only assign if valid
            if leftIdx > 0 && rightIdx > 0 && isnumeric(pliValue) && isscalar(pliValue)
                if ~isnan(pliValue)
                    pliValues(leftIdx) = pliValue;
                    pliValues(rightIdx) = pliValue;
                end
            end
        end
    end

    % Create topoplot
    try
        topoplot(pliValues, EEG.chanlocs, 'maplimits', [0 1], 'style', 'map');
        title(sprintf('%s [%.1f-%.1f Hz]', bandName, freqRange(1), freqRange(2)));
        colorbar;
    catch
        axis off;
        text(0.5, 0.5, 'Topoplot error', 'HorizontalAlignment', 'center', 'Color', 'red');
        title(sprintf('%s (N/A)', bandName));
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
    catch
        warning('generate_topoplots:saveFailed', 'Failed to save topoplot.');
    end
end

if config.advanced.closeAllFigures, close(fig); end
end

function idx = findChannelIdx(chanlocs, label)
% Simple channel lookup by exact label match
labels = {chanlocs.labels};
idx = find(strcmpi(labels, label), 1);
if isempty(idx)
    idx = 0;
end
end

function EEG = addStandardLocations(EEG)
% Add standard 10-20 coordinates to channels that match known labels
% Coordinates in spherical format (theta, radius)

standard1020 = struct( ...
    'Fp1', struct('theta', -18, 'radius', 0.511), ...
    'Fp2', struct('theta', 18, 'radius', 0.511), ...
    'F7', struct('theta', -54, 'radius', 0.511), ...
    'F3', struct('theta', -39, 'radius', 0.333), ...
    'Fz', struct('theta', 0, 'radius', 0.256), ...
    'F4', struct('theta', 39, 'radius', 0.333), ...
    'F8', struct('theta', 54, 'radius', 0.511), ...
    'T3', struct('theta', -90, 'radius', 0.511), ...
    'T7', struct('theta', -90, 'radius', 0.511), ...
    'C3', struct('theta', -90, 'radius', 0.256), ...
    'Cz', struct('theta', 0, 'radius', 0), ...
    'C4', struct('theta', 90, 'radius', 0.256), ...
    'T4', struct('theta', 90, 'radius', 0.511), ...
    'T8', struct('theta', 90, 'radius', 0.511), ...
    'T5', struct('theta', -126, 'radius', 0.511), ...
    'P7', struct('theta', -126, 'radius', 0.511), ...
    'P3', struct('theta', -141, 'radius', 0.333), ...
    'Pz', struct('theta', 180, 'radius', 0.256), ...
    'P4', struct('theta', 141, 'radius', 0.333), ...
    'T6', struct('theta', 126, 'radius', 0.511), ...
    'P8', struct('theta', 126, 'radius', 0.511), ...
    'O1', struct('theta', -162, 'radius', 0.511), ...
    'O2', struct('theta', 162, 'radius', 0.511), ...
    'Oz', struct('theta', 180, 'radius', 0.511) ...
    );

knownLabels = fieldnames(standard1020);

for ch = 1:length(EEG.chanlocs)
    label = EEG.chanlocs(ch).labels;
    % Try exact match
    matchIdx = find(strcmpi(knownLabels, label), 1);
    if ~isempty(matchIdx)
        coords = standard1020.(knownLabels{matchIdx});
        EEG.chanlocs(ch).theta = coords.theta;
        EEG.chanlocs(ch).radius = coords.radius;
        % Convert to X, Y for topoplot
        EEG.chanlocs(ch).X = coords.radius * cosd(coords.theta);
        EEG.chanlocs(ch).Y = coords.radius * sind(coords.theta);
    end
end
end
