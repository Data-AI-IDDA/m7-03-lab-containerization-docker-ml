# Dockerfile Notes

## Baseline build
- Image size: 84.6 MB
- Output of `docker run --rm aliyarlinurana/m7-03-cat-detection:v1`:
  ONNX model loaded OK: /home/app/model.onnx
    inputs:  1
    outputs: 1

## Stage 1 (builder) — why it exists
Stage 1 exists to compile the C verifier binary against the ONNX Runtime library. It needs build tools like build-essential, gcc, and curl to download the ONNX Runtime tarball and compile check_model.c. These tools are heavy and have no place in a production image — Stage 1 is a disposable workspace that produces two artifacts: the compiled binary and the validated model file.

## Stage 2 (runtime) — why it exists
Stage 2 exists to ship the smallest possible image that can actually run the verifier. It copies only what is needed from Stage 1: the compiled binary, the ONNX Runtime shared library, and the model file. No compilers, no tarballs, no build tools. The result is a ~85 MB image instead of a ~600 MB one.

## Three architectural decisions in this Dockerfile

1. **Multi-stage split** — Without the builder/runtime split, every build tool (gcc, build-essential, curl, the full ONNX Runtime tarball) would end up in the final image, bloating it from ~85 MB to ~600 MB and increasing the attack surface significantly.

2. **Validation gate (file | grep -qi onnx)** — Without this check, a missing or corrupted model.onnx would produce a broken image that passes the build but fails silently at runtime; the gate makes the build fail fast and loudly at the correct stage.

3. **Non-root user (uid 1001)** — Without running as a non-root user, any vulnerability in the binary or the ONNX Runtime library could give an attacker root access inside the container, which can lead to container escape or host compromise.

## Final build
- Image size: 84.6 MB
- Labels:
  {"maintainer":"aliyarlinurana","model.framework":"ultralytics-yolo26","model.source":"m6-09-assessment","ort.version":"1.20.1"}
- Healthcheck:
  {"Test":["CMD-SHELL","check_model /home/app/model.onnx || exit 1"],"Interval":30000000000,"Timeout":10000000000,"StartPeriod":5000000000,"Retries":3}