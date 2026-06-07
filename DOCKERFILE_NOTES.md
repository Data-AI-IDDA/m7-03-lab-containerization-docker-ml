# Dockerfile Notes

## Baseline build

- Image size: 215MB
- Output of `docker run --rm ilahes/m7-03-cat-detection:v1`:

```text
ONNX model loaded OK: /home/app/model.onnx
  inputs:  1
  outputs: 1
```

## Stage 1 (builder) — why it exists

The builder stage exists to prepare everything needed to verify the ONNX model without shipping the full build environment in the final image. It installs development tools such as gcc and downloads ONNX Runtime, then compiles the small C verifier program from `src/check_model.c`. It also copies `model.onnx` and runs an early validation gate so the Docker build fails immediately if the model is missing, empty, or not recognized as an ONNX file. Without this stage, the final runtime image would need to include compilers and build tools, making it much larger and less production-friendly.

## Stage 2 (runtime) — why it exists

The runtime stage contains only the minimal files needed to run the verifier: the ONNX Runtime shared libraries, the compiled `check_model` binary, and the `model.onnx` artifact. It also creates a non-root `app` user and runs the container from `/home/app`. This keeps the final image smaller and safer than a single-stage image because temporary build files, source code, and compiler packages are discarded before shipping.

## Three architectural decisions in this Dockerfile

1. Multi-stage split — if removed, the final image would include build tools such as gcc and downloaded build artifacts, increasing image size and shipping unnecessary software.
2. Validation gate for `model.onnx` — if removed, a missing or broken model might only fail at runtime instead of failing during the Docker build.
3. Non-root user — if removed, the verifier would run as root inside the container, which is bad security practice and may be rejected by stricter deployment platforms.

## Final build

- Image size: 215MB
- Output of `docker run --rm ilahes/m7-03-cat-detection:v2`:

```text
ONNX model loaded OK: /home/app/model.onnx
  inputs:  1
  outputs: 1
```

- Labels from `docker inspect ilahes/m7-03-cat-detection:v2 --format "{{json .Config.Labels}}"`:

```json
{"maintainer":"ilahes","model.framework":"ultralytics-yolo26","model.source":"m6-09-assessment","ort.version":"1.20.1"}
```

- Healthcheck from `docker inspect ilahes/m7-03-cat-detection:v2 --format "{{.Config.Healthcheck}}"`:

```text
{[CMD-SHELL check_model /home/app/model.onnx || exit 1] 30s 10s 5s 3}
```

- Base image digest used in both stages:

```text
debian:12-slim@sha256:0104b334637a5f19aa9c983a91b54c89887c0984081f2068983107a6f6c21eeb
```