# Dockerfile Notes

## Baseline build
- **Image size:** 144 MB
- **Output of `docker run --rm <image>`:**
  ```text
  ONNX model loaded OK: /home/app/model.onnx
    inputs:  1
    outputs: 1

## Stage 1 (builder) — why it exists
The builder stage acts as a heavy, disposable workbench that isolates the installation of bulky toolchains—like C compilers, `curl`, and `tar`—needed to download ONNX Runtime and compile the verifier from source. By quarantining this process, we prevent gigabytes of build-time artifacts from bloating the final production image and unnecessarily expanding its security attack surface.

## Stage 2 (runtime) — why it exists
The runtime stage serves as the ultra-lean production environment by starting fresh from a minimal base image and carrying over only the exact artifacts required to execute the job (the compiled binary, ONNX shared libraries, and the model). This ensures the final container is fast to deploy, minimal in footprint, and strictly scoped to its single verification task.

## Three architectural decisions in this Dockerfile

1. **The multi-stage split**
   *What would break if removed:* The final container image would be bloated by hundreds of megabytes and inherently less secure because it would ship with active build tools like `gcc` and `curl` permanently baked into the filesystem.

2. **The `apt-get update ... && rm -rf /var/lib/apt/lists/*` pattern**
   *What would break if removed:* The image size would needlessly inflate because the temporary package index files downloaded by `apt-get` would be permanently frozen into that specific Docker layer.

3. **The position of `COPY model.onnx` at the very end of the build (cache impact)**
   *What would break if removed (e.g., moved to the top):* Docker's layer caching would be ruined, forcing a painfully slow re-download of the ONNX Runtime and a full C recompilation every time the model weights changed.


## Final build

**Final Image Size:** 144MB

**Labels Spec:**
{"maintainer":"orkhannuriyev","model.framework":"ultralytics-yolo26","model.source":"m6-09-assessment","ort.version":"1.20.1"}

**Healthcheck Spec:**
{[CMD-SHELL check_model /home/app/model.onnx || exit 1] 30s 10s 5s 0s 3}