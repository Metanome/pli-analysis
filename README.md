# Interhemispheric PLI Analysis Tool

## Overview

MATLAB toolbox for computing Phase Lag Index (PLI) connectivity metrics between interhemispheric electrode pairs. Features automated batch processing, quality control, statistical validation, and publication-ready visualizations.

**Key Features:**
- Standard PLI and Weighted PLI (wPLI) calculation
- Surrogate-based statistical significance testing
- Automated quality control and bad channel detection
- Topographic map generation
- Configurable frequency bands and electrode pairs

**Default Electrode Pairs (10-20 System):**
Fp1-Fp2, F7-F8, F3-F4, T3-T4, C3-C4, T5-T6, P3-P4, O1-O2

## Prerequisites

- MATLAB R2016b or later
- EEGLAB toolbox (added to MATLAB path)
- Signal Processing Toolbox

## Usage

1. Place EEG files in the `data/` folder
2. In MATLAB, navigate to the toolbox folder
3. Run:
   ```matlab
   PLI_Analysis
   ```
4. Results are saved to `output/PLI_Results.xlsx`

**Supported File Formats:**
| Format      | Extension | Notes                             |
| ----------- | --------- | --------------------------------- |
| EDF         | `.edf`    | European Data Format              |
| BDF         | `.bdf`    | BioSemi format                    |
| CNT         | `.cnt`    | Neuroscan format                  |
| SET         | `.set`    | EEGLAB native format              |
| MAT         | `.mat`    | Must contain variable named `EEG` |
| BrainVision | `.vhdr`   | Header file                       |

## Configuration

Edit `config_pli.m` to customize. All options explained below:

### Analysis Options
| Setting               | Default | Description                        |
| --------------------- | ------- | ---------------------------------- |
| `computePLI`          | `true`  | Compute standard Phase Lag Index   |
| `computeWPLI`         | `true`  | Compute Weighted PLI (more robust) |
| `computeSignificance` | `true`  | Run statistical testing (slower)   |

### Frequency Bands
| Band  | Range (Hz) | Associated With                   |
| ----- | ---------- | --------------------------------- |
| Delta | 0.5-4      | Deep sleep, unconscious processes |
| Theta | 4-8        | Memory encoding, meditation       |
| Alpha | 8-13       | Relaxed wakefulness, eyes closed  |
| Beta  | 13-30      | Active thinking, concentration    |
| Gamma | 30-45      | High-level cognitive processing   |

### Visualization
| Setting             | Default | Description                       |
| ------------------- | ------- | --------------------------------- |
| `generateTopoplots` | `true`  | Create scalp maps for each file   |
| `saveFigures`       | `true`  | Save figures to disk              |
| `figureFormat`      | `'png'` | Format: `'png'`, `'jpg'`, `'fig'` |
| `figureResolution`  | `300`   | DPI for saved figures             |

### Quality Control
| Setting                | Default | Description                                 |
| ---------------------- | ------- | ------------------------------------------- |
| `qc.enabled`           | `true`  | Run automated data quality checks           |
| `minVarianceThreshold` | `0.1`   | Min channel variance (detect dead channels) |
| `maxBadChannels`       | `5`     | Max bad channels before QC fails            |
| `minDuration`          | `5`     | Min recording length in seconds             |

### Statistics
| Setting         | Default | Description                                            |
| --------------- | ------- | ------------------------------------------------------ |
| `numSurrogates` | `1000`  | Number of surrogates (more = slower but more accurate) |
| `alphaLevel`    | `0.05`  | Significance threshold (p < 0.05)                      |

### Output
| Setting    | Default              | Description           |
| ---------- | -------------------- | --------------------- |
| `folder`   | `'output'`           | Output directory name |
| `filename` | `'PLI_Results.xlsx'` | Results file name     |

## Output

Results are saved in **long format** (tidy data) — easy to filter, pivot, and analyze.

### Excel Columns
| Column        | Description                                       |
| ------------- | ------------------------------------------------- |
| `FileName`    | Source EEG file                                   |
| `QC_Passed`   | Quality control status (TRUE/FALSE)               |
| `Band`        | Frequency band (Delta, Theta, Alpha, Beta, Gamma) |
| `Pair`        | Electrode pair (e.g., Fp1-Fp2)                    |
| `PLI`         | Phase Lag Index (0-1)                             |
| `wPLI`        | Weighted PLI (0-1)                                |
| `Significant` | Statistical significance (TRUE/FALSE)             |
| `PValue`      | P-value from surrogate testing                    |

### Example Output
| FileName  | QC_Passed | Band  | Pair    | PLI  | wPLI | Significant | PValue |
| --------- | --------- | ----- | ------- | ---- | ---- | ----------- | ------ |
| file1.edf | TRUE      | Delta | Fp1-Fp2 | 0.32 | 0.28 | TRUE        | 0.012  |
| file1.edf | TRUE      | Delta | F7-F8   | 0.18 | 0.15 | FALSE       | 0.234  |
| file1.edf | TRUE      | Theta | Fp1-Fp2 | 0.41 | 0.38 | TRUE        | 0.003  |

### Interpreting PLI Values
- **0.0-0.2**: Weak connectivity
- **0.2-0.4**: Moderate connectivity
- **0.4-0.6**: Strong connectivity
- **0.6-1.0**: Very strong (verify data quality)

## File Structure

```
PLI-Analysis/
├── PLI_Analysis.m              # Main script
├── config_pli.m                # Configuration
├── compute_wPLI.m              # wPLI function
├── compute_significance.m      # Statistical testing
├── compute_quality_metrics.m   # Quality control
├── generate_topoplots.m        # Visualization
├── data/                       # Place EEG files here
└── output/                     # Created automatically
    ├── PLI_Results.xlsx
    └── figures/
```

## Troubleshooting

**No EEG files found:** Place EEG files in the `data/` folder.

**Channel not found:** Your EEG uses different channel names. Edit `config.pairs` in `config_pli.m` to match your labels (e.g., use `T7` instead of `T3`).

**Slow analysis:** Disable significance testing (`config.analysis.computeSignificance = false`) or reduce `config.stats.numSurrogates`.

**MAT file error:** Ensure your `.mat` file contains a variable named `EEG` with standard EEGLAB structure.

## Acknowledgment

If this toolbox helped your research, a brief acknowledgment is appreciated.
