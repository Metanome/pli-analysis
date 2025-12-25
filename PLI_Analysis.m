%% PLI BATCH ANALYSIS TOOL
% Computes PLI/wPLI connectivity for interhemispheric electrode pairs.
% See README.md for usage instructions.

%% Initialize
clear; clc;
fprintf('========================================\n');
fprintf('PLI CONNECTIVITY ANALYSIS\n');
fprintf('========================================\n\n');

%% Load Configuration
config = config_pli();
workingDirectory = pwd;
dataDirectory = fullfile(workingDirectory, 'data');
frequencyBands = config.bands;
interhemisphericPairs = config.pairs;
supportedExtensions = {'*.edf', '*.bdf', '*.cnt', '*.set', '*.mat', '*.vhdr'};
outputFilename = config.output.filename;

fprintf('Data Directory: %s\n\n', dataDirectory);

%% Validate Environment
fprintf('Validating environment...\n');

if ~license('test', 'Signal_Toolbox')
    error('Signal Processing Toolbox required.');
end

if ~exist('pop_loadset', 'file')
    fprintf('Initializing EEGLAB...\n');
    try
        eeglab nogui;
    catch ME
        error('EEGLAB not found: %s', ME.message);
    end
end
fprintf('Environment OK.\n\n');

%% Create Output Directories
if ~exist(config.output.folder, 'dir'), mkdir(config.output.folder); end

if config.visualization.generateTopoplots
    figuresPath = fullfile(config.output.folder, config.output.figuresSubfolder);
    if ~exist(figuresPath, 'dir'), mkdir(figuresPath); end
end

if config.qc.enabled && config.qc.saveReport
    qcPath = fullfile(config.output.folder, config.output.qcSubfolder);
    if ~exist(qcPath, 'dir'), mkdir(qcPath); end
end

%% Detect EEG Files
fprintf('Scanning for EEG files...\n');

if ~exist(dataDirectory, 'dir')
    mkdir(dataDirectory);
    error('Created data folder. Place EEG files in:\n%s', dataDirectory);
end

eegFiles = [];
for i = 1:length(supportedExtensions)
    foundFiles = dir(fullfile(dataDirectory, supportedExtensions{i}));
    eegFiles = [eegFiles; foundFiles]; %#ok<AGROW>
end

numFiles = length(eegFiles);
if numFiles == 0
    error('No EEG files in data folder: %s', dataDirectory);
end
fprintf('Found %d file(s).\n\n', numFiles);

%% Main Processing Loop
fprintf('========================================\n');
fprintf('PROCESSING FILES\n');
fprintf('========================================\n\n');

bandNames = fieldnames(frequencyBands);
numBands = length(bandNames);
numPairs = size(interhemisphericPairs, 1);

% Build dynamic column headers based on config
colHeaders = {'FileName'};
if config.qc.enabled, colHeaders{end+1} = 'QC_Passed'; end
colHeaders = [colHeaders, {'Band', 'Pair'}];
if config.analysis.computePLI, colHeaders{end+1} = 'PLI'; end
if config.analysis.computeWPLI, colHeaders{end+1} = 'wPLI'; end
if config.analysis.computeSignificance
    colHeaders{end+1} = 'Significant';
    colHeaders{end+1} = 'PValue';
end
numCols = length(colHeaders);

% Initialize results table (long format)
allResults = {};
rowIdx = 0;

for fileIdx = 1:numFiles
    currentFilename = eegFiles(fileIdx).name;
    currentFilepath = fullfile(dataDirectory, currentFilename);
    fprintf('[%d/%d] Processing: %s\n', fileIdx, numFiles, currentFilename);

    try
        %% Load EEG Data
        [~, ~, fileExtension] = fileparts(currentFilename);

        switch lower(fileExtension)
            case {'.edf', '.bdf'}
                EEG = pop_biosig(currentFilepath);
            case '.cnt'
                EEG = pop_loadcnt(currentFilepath, 'dataformat', 'auto');
            case '.set'
                EEG = pop_loadset('filename', currentFilename, 'filepath', dataDirectory);
            case '.mat'
                loadedData = load(currentFilepath);
                if isfield(loadedData, 'EEG')
                    EEG = loadedData.EEG;
                else
                    varNames = fieldnames(loadedData);
                    foundEEG = false;
                    for v = 1:length(varNames)
                        if isstruct(loadedData.(varNames{v})) && isfield(loadedData.(varNames{v}), 'data')
                            EEG = loadedData.(varNames{v});
                            foundEEG = true;
                            break;
                        end
                    end
                    if ~foundEEG
                        error('No EEG structure in MAT file.');
                    end
                end
            case '.vhdr'
                [filepath, basename, ~] = fileparts(currentFilepath);
                EEG = pop_loadbv(filepath, [basename '.vhdr']);
            otherwise
                error('Unsupported format: %s', fileExtension);
        end

        if isempty(EEG.data), error('No data in file.'); end
        if isempty(EEG.chanlocs), error('No channel locations.'); end

        channelLabels = {EEG.chanlocs.labels};
        fprintf('  Loaded: %d ch, %.1f s @ %.1f Hz\n', length(channelLabels), EEG.pnts/EEG.srate, EEG.srate);

        % Store file-level results for topoplots
        fileResults = struct();
        fileResults.FileName = string(currentFilename);

        %% Quality Control
        qcPassed = true;
        if config.qc.enabled
            qc = compute_quality_metrics(EEG, config);
            fprintf('  QC: %s', qc.status);
            qcPassed = qc.passed;

            if ~isempty(qc.warnings)
                fprintf('\n');
                for wIdx = 1:length(qc.warnings)
                    fprintf('    [!] %s\n', qc.warnings{wIdx});
                end
            else
                fprintf(' [OK]\n');
            end

            % Save QC report to file
            if config.qc.saveReport
                saveQCReport(qc, currentFilename, config);
            end
        end

        %% Process Each Frequency Band
        for bandIdx = 1:numBands
            currentBand = bandNames{bandIdx};
            freqRange = frequencyBands.(currentBand);
            fprintf('  Band: %s [%.1f-%.1f Hz]\n', currentBand, freqRange(1), freqRange(2));

            % Bandpass filter
            EEG_filtered = pop_eegfiltnew(EEG, 'locutoff', freqRange(1), 'hicutoff', freqRange(2));

            % Hilbert transform for phase
            analyticSignal = hilbert(EEG_filtered.data');
            phaseData = angle(analyticSignal');

            %% Calculate PLI for Each Pair
            for pairIdx = 1:numPairs
                leftElectrode = interhemisphericPairs{pairIdx, 1};
                rightElectrode = interhemisphericPairs{pairIdx, 2};
                pairName = sprintf('%s-%s', leftElectrode, rightElectrode);

                leftIdx = findChannelIndex(channelLabels, leftElectrode);
                rightIdx = findChannelIndex(channelLabels, rightElectrode);

                % Initialize row values
                pliValue = NaN;
                wpliValue = NaN;
                isSig = false;
                pVal = 1;

                if ~isnan(leftIdx) && ~isnan(rightIdx)
                    phaseDiff = phaseData(leftIdx, :) - phaseData(rightIdx, :);

                    % PLI
                    if config.analysis.computePLI
                        pliValue = abs(mean(sign(sin(phaseDiff))));
                    end

                    % wPLI
                    if config.analysis.computeWPLI
                        wpliValue = compute_wPLI(phaseData(leftIdx, :), phaseData(rightIdx, :));
                    end

                    % Significance
                    if config.analysis.computeSignificance && config.analysis.computePLI && ~isnan(pliValue)
                        [isSig, pVal, ~] = compute_significance(...
                            phaseData(leftIdx, :), phaseData(rightIdx, :), ...
                            pliValue, config.stats.numSurrogates, config.stats.alphaLevel);
                    end

                    % Store for topoplots (wide format)
                    columnName = sprintf('%s_%s_%s', currentBand, leftElectrode, rightElectrode);
                    fileResults.(columnName) = pliValue;
                    if config.analysis.computeWPLI
                        fileResults.([columnName '_wPLI']) = wpliValue;
                    end
                else
                    if isnan(leftIdx), fprintf('    Warning: %s not found\n', leftElectrode); end
                    if isnan(rightIdx), fprintf('    Warning: %s not found\n', rightElectrode); end
                end

                % Add row to results (long format, dynamic columns)
                rowIdx = rowIdx + 1;
                colIdx = 0;
                colIdx = colIdx + 1; allResults{rowIdx, colIdx} = string(currentFilename);
                if config.qc.enabled
                    colIdx = colIdx + 1; allResults{rowIdx, colIdx} = qcPassed;
                end
                colIdx = colIdx + 1; allResults{rowIdx, colIdx} = string(currentBand);
                colIdx = colIdx + 1; allResults{rowIdx, colIdx} = string(pairName);
                if config.analysis.computePLI
                    colIdx = colIdx + 1; allResults{rowIdx, colIdx} = pliValue;
                end
                if config.analysis.computeWPLI
                    colIdx = colIdx + 1; allResults{rowIdx, colIdx} = wpliValue;
                end
                if config.analysis.computeSignificance
                    colIdx = colIdx + 1; allResults{rowIdx, colIdx} = isSig;
                    colIdx = colIdx + 1; allResults{rowIdx, colIdx} = pVal;
                end
            end
        end

        fprintf('  Done (%d bands x %d pairs)\n', numBands, numPairs);

        %% Generate Topoplots
        if config.visualization.generateTopoplots
            try
                generate_topoplots(fileResults, EEG, config, currentFilename);
                fprintf('  Topoplot saved.\n');
            catch ME
                fprintf('  Topoplot failed: %s\n', ME.message);
            end
        end
        fprintf('\n');

    catch ME
        fprintf('  FAILED: %s\n', ME.message);
        fprintf('  Stack: %s (line %d)\n\n', ME.stack(1).name, ME.stack(1).line);
    end
end

%% Export Results
fprintf('========================================\n');
fprintf('EXPORTING RESULTS\n');
fprintf('========================================\n\n');

if isempty(allResults)
    fprintf('ERROR: No results to export.\n');
    return;
end

% Create table with dynamic column names
resultsTable = cell2table(allResults, 'VariableNames', colHeaders);

outputPath = fullfile(config.output.folder, outputFilename);

try
    writetable(resultsTable, outputPath);
    fprintf('Results saved to: %s\n\n', outputPath);
    fprintf('Summary:\n');
    fprintf('  Files: %d\n', numFiles);
    fprintf('  Rows: %d\n', height(resultsTable));
    fprintf('  Format: Long (tidy data)\n\n');
catch ME
    fprintf('ERROR saving results: %s\n', ME.message);
end

fprintf('========================================\n');
fprintf('ANALYSIS COMPLETE\n');
fprintf('========================================\n');

%% Helper Functions

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

function saveQCReport(qc, filename, config)
% Save QC report to text file
qcPath = fullfile(config.output.folder, config.output.qcSubfolder);
[~, baseName, ~] = fileparts(filename);
reportPath = fullfile(qcPath, sprintf('QC_%s.txt', baseName));

try
    fid = fopen(reportPath, 'w');
    fprintf(fid, 'Quality Control Report\n');
    fprintf(fid, '======================\n\n');
    fprintf(fid, 'File: %s\n', filename);
    fprintf(fid, 'Date: %s\n\n', char(qc.timestamp));
    fprintf(fid, 'Status: %s\n\n', qc.status);
    fprintf(fid, 'Metrics:\n');
    fprintf(fid, '  Duration: %.2f seconds\n', qc.duration);
    fprintf(fid, '  Sampling Rate: %.1f Hz\n', qc.samplingRate);
    fprintf(fid, '  Channels: %d\n', qc.numChannels);
    fprintf(fid, '  Bad Channels: %d\n', qc.numBadChannels);
    fprintf(fid, '  Mean Variance: %.4f\n', qc.meanVariance);
    fprintf(fid, '  Max Amplitude: %.2f uV\n', qc.maxAmplitude);

    if ~isempty(qc.warnings)
        fprintf(fid, '\nWarnings:\n');
        for w = 1:length(qc.warnings)
            fprintf(fid, '  - %s\n', qc.warnings{w});
        end
    end
    fclose(fid);
catch
    warning('Failed to save QC report for %s', filename);
end
end