# Dockerfile Notes

## Baseline build

- Image size: 214 MB

- Output of `docker run --rm model.onnx/m7-03-cat-detection:v1`:

```text
ONNX model loaded OK: /home/app/model.onnx
  inputs:  1
  outputs: 1
```

## Stage 1 (builder) — why it exists

The builder stage contains the tools required to compile the check_model program and download ONNX Runtime. It acts as a temporary build environment so that compilers and other development tools do not need to be included in the final image.

## Stage 2 (runtime) — why it exists

The runtime stage contains only the files needed to run the model verifier: the compiled check_model binary, the ONNX Runtime shared libraries, and model.onnx. This keeps the image smaller, cleaner, and more secure.

## Three architectural decisions in this Dockerfile

1. Multi-stage build

   Without the builder stage, the final image would contain compilers, build tools, and other unnecessary files, making the image significantly larger.

2. Non-root user

   The container runs as user `app` (UID 1001) instead of root. If the application were compromised, the attacker would have fewer permissions inside the container.

3. Model validation during build

   The Dockerfile verifies that model.onnx exists and is a valid ONNX file before the image is built. Without this validation, a broken or incorrect model could be packaged and the problem would only be discovered at runtime.

## Final build

- Image size: 214 MB

### Labels

```json
{
  "maintainer": "adilhasanov-glitch",
  "model.framework": "ultralytics-yolo26",
  "model.source": "m6-09-assessment",
  "ort.version": "1.20.1"
}
```

### Healthcheck

```json
{
  "Test": ["CMD-SHELL", "check_model /home/app/model.onnx || exit 1"],
  "Interval": 30000000000,
  "Timeout": 10000000000,
  "StartPeriod": 5000000000,
  "Retries": 3
}
```
