# Chest X-ray Lung Segmentation & Enhancement Evaluation (MATLAB)

A classical Digital Image Processing (DIP) pipeline for chest X-rays: contrast enhancement, noise removal, automatic lung segmentation, quantitative evaluation against ground-truth masks, and a heuristic ROI analysis. No deep learning is used.

Evaluated on the **Montgomery County CXR dataset (138 images)**.

## Pipeline

1. Grayscale conversion
2. Contrast enhancement with CLAHE (`adapthisteq`)
3. Noise removal with a Wiener filter (`wiener2`, 5x5)
4. Lung segmentation (Otsu threshold, morphological closing/opening, hole filling, keep two largest regions)
5. Evaluation against reference lung masks (Dice, IoU)
6. ROI analysis from local contrast, local texture and Canny edge density, with rib-like structures suppressed

## Results

### Segmentation (138 images)

| Method | Mean Dice | Mean IoU |
|---|---|---|
| Basic (global threshold) | 0.2678 | 0.2162 |
| Improved (chest-region-restricted threshold + morphology) | 0.6690 | 0.5441 |

The improved method restricts thresholding to the central chest region, removes small objects, and applies stronger morphological closing.

### Enhancement quality (mean over 138 images)

| Method | Entropy | RMS Contrast | Edge Strength |
|---|---|---|---|
| Original | 7.092 | 0.3255 | 0.0266 |
| CLAHE | 7.181 | 0.3121 | 0.0889 |
| CLAHE + Wiener | 7.193 | 0.3118 | 0.0410 |

CLAHE increases information content (entropy) and edge detail; the Wiener filter then suppresses part of the amplified noise. Global RMS contrast changes slightly because CLAHE equalizes contrast locally rather than globally.

![Segmentation comparison](results/segmentation%20comparison.png)

## Repository structure

```
.
├── src/
│   ├── chest_xray_main.m                  # basic pipeline
│   ├── chest_xray_groundtruth.m           # segmentation + Dice/IoU on one image
│   ├── chest_xray_improved.m              # improved segmentation
│   ├── chest_xray_roi_analysis.m          # ROI analysis (v1)
│   ├── chest_xray_roi_improved.m          # ROI analysis (improved)
│   ├── enhancement_metrics.m              # single-image enhancement metrics
│   ├── evaluate_montgomery.m              # batch eval, basic method
│   ├── evaluate_montgomery_improved.m     # batch eval, improved method
│   ├── evaluate_enhancement_montgomery.m  # batch enhancement metrics
│   ├── inspect_worst_cases.m
│   ├── plot_segmentation_comparison.m
│   └── roi_analysis_figure.m
├── results/                               # .xlsx result tables and figures
└── README.md
```

## How to run

**Requirements:** MATLAB with the Image Processing Toolbox.

1. Download the [Montgomery County X-ray Set](https://www.kaggle.com/datasets/raddar/tuberculosis-chest-xrays-montgomery) (not included in this repo).
2. Open MATLAB and run any script from `src/`, for example `chest_xray_improved.m`.
3. Pick the X-ray (and the left/right lung masks) in the file dialogs. Batch scripts ask for the `CXR_png` folder.

## Notes and limitations

- The ROI analysis highlights regions with unusual local contrast/texture. It is a heuristic visualization, **not a diagnostic tool**.
- Segmentation is threshold-based, so it struggles on low-contrast images (see `inspect_worst_cases.m`).

## Author

Sangini Verma, B.Tech Electronics & Telecommunication Engineering, Symbiosis Institute of Technology, Pune
