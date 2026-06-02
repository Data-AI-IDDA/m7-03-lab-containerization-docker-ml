# Dockerfile Notes

## Baseline build
- Image size: 134.2 MB
- Output of `docker run --rm alexiiiiiiiii/m7-03-cat-detection:v1`:
```
ONNX model loaded OK: /home/app/model.onnx
  inputs:  1
  outputs: 1
```

## Stage 1 (builder) — why it exists
Stage 1 exists to compile the C model verifier code (`check_model.c`) against the ONNX Runtime dynamic library and header files, and to validate the integrity of the `model.onnx` file before finalizing the deployment. It requires build tools like `gcc`, `build-essential`, `curl`, and `file`, which are heavy dependencies (adding hundreds of megabytes to the footprint). By running this compilation and validation in a separate builder stage, these development tools and intermediate tarball files are completely discarded and never make it into the final production image.

## Stage 2 (runtime) — why it exists
Stage 2 exists as the lean, secure, and minimal production artifact that is actually deployed to production. It only inherits the absolute bare-minimum files required to execute the compiled `check_model` binary: the `libonnxruntime.so` shared library, `libstdc++` runtime dependencies, SSL certificates, the validated `model.onnx` file, and a dedicated non-root user account (`app`). This ensures the final container is fast to pull, has a significantly smaller attack surface, and executes with limited privileges.

## Three architectural decisions in this Dockerfile
1. Multi-stage build split: Without the separation of the builder and runtime stages, the final image would retain heavy build tools (like `build-essential`, `gcc`, and `curl`) and temporary download archives, ballooning the image size to over 600 MB and exposing compilation tools to potential runtime exploits.
2. Dynamic linking with LD_LIBRARY_PATH: Without defining `LD_LIBRARY_PATH=/usr/local/lib` in the runtime stage, the operating system's dynamic linker would fail to locate `libonnxruntime.so` at runtime, causing the `check_model` executable to crash immediately upon launch with a shared library loading error.
3. Execution under a dedicated non-root user (uid 1001): Without switching to the `app` user, the container would run its entrypoint process as `root` (uid 0), which would violate the principle of least privilege and allow an attacker who successfully exploits a vulnerability in the ONNX runtime library or application code to gain full root execution access on the host system.

## Final build
- Image size: 134.2 MB
- Labels:
```json
{
  "maintainer": "alexiiiiiiiii",
  "model.framework": "ultralytics-yolo26",
  "model.source": "m6-09-assessment",
  "ort.version": "1.20.1"
}
```
- Healthcheck:
```json
{
  "Test": [
    "CMD-SHELL",
    "check_model /home/app/model.onnx || exit 1"
  ],
  "Interval": 30000000000,
  "Timeout": 10000000000,
  "StartPeriod": 5000000000,
  "Retries": 3
}
```
