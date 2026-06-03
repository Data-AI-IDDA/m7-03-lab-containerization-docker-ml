# Dockerfile Notes

## Baseline build
- Image size: 268 MB
- Output of `docker run --rm ibrahim-suleymanov/m7-03-cat-detection:v1`:
  ONNX model loaded OK: /home/app/model.onnx
    inputs:  1
    outputs: 1

## Stage 1 (builder) — why it exists
Stage 1 exists to compile the C verifier (`check_model.c`) against the ONNX Runtime library. This requires heavyweight tools — `gcc`, `build-essential`, `curl` — that have no place in a production image. Without this stage, we would either ship a 600 MB image bloated with compilers and tarballs, or have no way to produce the `check_model` binary at all. The builder is a temporary workshop: it does the heavy work and then gets discarded entirely.

## Stage 2 (runtime) — why it exists
Stage 2 exists to produce the smallest possible image that can actually run the verifier. It starts from a clean Debian 12-slim base and copies only three things from the builder: the compiled `check_model` binary, the `libonnxruntime.so` shared library, and the `model.onnx` file. No compilers, no tarballs, no build cache — just what is needed to execute. This is why the final image is ~268 MB instead of ~600 MB.

## Three architectural decisions in this Dockerfile

1. **Multi-stage split** — Without splitting into builder and runtime stages, every compiler, tarball, and build tool would remain in the final image, inflating it to ~600 MB and exposing unnecessary attack surface.

2. **Validation gate (`file | grep -qi onnx`)** — Without this check, a missing, empty, or corrupted `model.onnx` would silently pass the build and only fail at runtime inside the container, making debugging much harder.

3. **Non-root user (uid 1001)** — Without creating and switching to a non-root user, the container process would run as root, meaning any vulnerability in the verifier or runtime could give an attacker full control over the container environment.


## Final build
- Image size: 268 MB
- Same as baseline — LABEL, digest pin, and HEALTHCHECK do not affect image content size.

### Labels
{"maintainer":"ibrahim-suleymanov","model.framework":"ultralytics-yolo26","model.source":"m6-09-assessment","ort.version":"1.20.1"}

### Healthcheck
{[CMD-SHELL check_model /home/app/model.onnx || exit 1] 30s 10s 5s 0s 3}