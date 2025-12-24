function config = config_pli()
% CONFIG_PLI Configuration for PLI Analysis Tool
%   config = config_pli()
%   Modify values below to customize analysis.

config = struct();

%% Analysis
config.analysis.computePLI = true;
config.analysis.computeWPLI = true;
config.analysis.computeSignificance = true;

%% Frequency Bands (Hz)
config.bands.Delta = [0.5, 4];
config.bands.Theta = [4, 8];
config.bands.Alpha = [8, 13];
config.bands.Beta  = [13, 30];
config.bands.Gamma = [30, 45];

%% Electrode Pairs (10-20 System)
config.pairs = {
    'Fp1', 'Fp2';
    'F7',  'F8';
    'F3',  'F4';
    'T3',  'T4';
    'C3',  'C4';
    'T5',  'T6';
    'P3',  'P4';
    'O1',  'O2'
    };

%% Visualization
config.visualization.generateTopoplots = true;
config.visualization.saveFigures = true;
config.visualization.figureFormat = 'png';
config.visualization.figureResolution = 300;

%% Quality Control
config.qc.enabled = true;
config.qc.minVarianceThreshold = 0.1;
config.qc.maxBadChannels = 5;
config.qc.minDuration = 5;
config.qc.saveReport = true;

%% Statistics
config.stats.numSurrogates = 1000;
config.stats.alphaLevel = 0.05;
config.stats.method = 'circular_shift';

%% Output
config.output.folder = 'output';
config.output.filename = 'PLI_Results.xlsx';
config.output.figuresSubfolder = 'figures';
config.output.qcSubfolder = 'quality_control';

%% Advanced
config.advanced.suppressEEGLABOutput = true;
config.advanced.closeAllFigures = true;
end
