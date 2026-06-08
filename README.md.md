# Cat Detection v2 — ONNX Export & Containerised Inference

> A fully reproducible, framework-independent containerised inference system for YOLO26-based cat detection.

---

## Overview

This project implements a containerised inference pipeline for a YOLO26-based cat detection model exported to ONNX format. The system is designed to run consistently across any machine using Docker, with no PyTorch dependency at runtime.

**Capabilities:**

- ONNX model inference via `onnxruntime`
- Batch image processing with recursive directory support
- Standardised CLI interface (`info` / `predict`)
- CSV-based prediction output

---

## Project Structure

```
container/
├── Dockerfile
├── STUDENT.json
├── requirements.txt
└── app/
    ├── __init__.py
    ├── cli.py
    └── detector.py
    models/
    └── best.onnx

test_in/
test_out/
README.md
```

---

## CLI Usage

The container exposes exactly two commands:

### `info`

Prints student metadata from `STUDENT.json`.

```bash
docker run --rm <image> info
```

**Expected output:**
- Contents of `STUDENT.json`
- Valid JSON format
- Exit code: `0`

---

### `predict`

Runs inference on all images found under `/data/input/` and writes predictions to `/data/output/predictions.csv`.

```bash
docker run --rm \
  -v /absolute/path/to/input:/data/input:ro \
  -v /absolute/path/to/output:/data/output \
  <image> predict
```

---

## Input Format

| Property | Detail |
|---|---|
| Directory | `/data/input/` |
| Supported formats | `.jpg`, `.jpeg`, `.png` |
| Subdirectories | ✅ Supported (recursive) |

---

## Output Format

**File location:** `/data/output/predictions.csv`

**CSV schema:**

```
image_path,xmin,ymin,xmax,ymax,confidence,class
```

| Field | Description |
|---|---|
| `image_path` | Relative path from the input folder |
| `xmin, ymin, xmax, ymax` | Bounding box coordinates (pixels, original image scale) |
| `confidence` | Prediction confidence score (0–1) |
| `class` | Predicted class name (e.g. `cat`) |

**Multiple detections** — each detection is a separate row:

```
img_001.jpg,123,55,478,401,0.91,cat
img_001.jpg,512,200,640,330,0.74,cat
```

**No detection** — empty fields are used:

```
empty_img.jpg,,,,,,
```

---

## Model Details

| Property | Value |
|---|---|
| Model type | YOLO26 |
| Export format | ONNX |
| Runtime | `onnxruntime` (CPU) |
| Input size | 640×640 |
| Output format | `[x1, y1, x2, y2, score, class]` |

---

## Docker Instructions

### Build

```bash
docker build -t <username>/cat-detector:final -f container/Dockerfile .
```

### Run `info`

```bash
docker run --rm <username>/cat-detector:final info
```

### Run `predict`

```bash
mkdir -p /tmp/in /tmp/out

docker run --rm \
  -v /tmp/in:/data/input:ro \
  -v /tmp/out:/data/output \
  <username>/cat-detector:final predict
```

---

## Requirements

```
onnxruntime==1.18.0
numpy
pillow
opencv-python-headless
```

---

## Notes

- The system is fully containerised and reproducible across environments
- All inference is performed using ONNX — no PyTorch dependency at runtime
- Output format is strictly enforced for automated evaluation

---

## Submission Checklist

- [x] ONNX model exported and included in container
- [x] Docker container builds successfully
- [x] `info` command returns valid JSON
- [x] `predict` command generates correct CSV
- [x] Works on unseen images via volume mounting
- [x] Reproducible inference pipeline

---

## Pipeline Summary

```
Training → Export → ONNX → Docker → Reproducible Inference
```

This project demonstrates a complete end-to-end ML deployment pipeline, from model training through to containerised, framework-independent production inference.
