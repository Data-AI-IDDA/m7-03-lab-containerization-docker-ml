# Dockerfile Notes

## Baseline build
- Image size: 350 MB
- Output of `docker run --rm aysuanar/m7-03-cat-detection:v1`:
  ```
  ONNX model loaded OK: /home/app/model.onnx
    inputs:  1
    outputs: 1
  ```

## Stage 1 (builder) — why it exists
The `builder` stage acts as a clean, isolated environment designed to download the ONNX Runtime release, compile the C verifier application (`check_model.c`) from source, and run basic verification gates on the local model artifact. Because compiling C applications requires heavy build utilities (such as `gcc`, `make`, `build-essential`, and headers), placing these operations in a dedicated stage ensures that bulky compiler packages, intermediate object files, and source code do not contaminate the final production image.

## Stage 2 (runtime) — why it exists
The `runtime` stage is the actual lightweight production container that ships only the compiled verifier binary, the minimal required ONNX Runtime shared library, the model itself, and a non-root execution context. By copying only the compilation results from the `builder` stage, it discards all development tools and raw source files, achieving a slim production image footprint (~350 MB compared to ~600 MB+) while minimizing security vulnerability vectors by excluding compilers from the final environment.

## Three architectural decisions in this Dockerfile
1. **Multi-stage build split**: Without it, the final production container would be forced to include bulky build tools like `gcc` and `build-essential`, bloating the image by over 250 MB and introducing unnecessary binaries that increase the potential container attack surface.
2. **Setting `LD_LIBRARY_PATH=/usr/local/lib`**: Without it, the dynamic linker would fail to find `libonnxruntime.so` when starting the C-based verifier, causing the application to crash immediately on startup with a library loading error.
3. **Dedicated non-root user configuration (`app` user with UID 1001)**: Without it, the main container application would run with root privileges, violating the principle of least privilege and making any potential container escape or runtime exploit extremely dangerous to the host system.

## Final build
- Image size: 123 MB (after stripping debug symbols from `libonnxruntime.so`)
- Output of `docker run --rm aysuanar/m7-03-cat-detection:v2`:
  ```
  ONNX model loaded OK: /home/app/model.onnx
    inputs:  1
    outputs: 1
  ```
- **Provenance Labels**:
  ```json
  {
    "maintainer": "AysuAnar",
    "model.framework": "ultralytics-yolo26",
    "model.source": "m6-09-assessment",
    "ort.version": "1.20.1"
  }
  ```
- **HEALTHCHECK Specification**:
  ```dockerfile
  HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD check_model /home/app/model.onnx || exit 1
  ```
