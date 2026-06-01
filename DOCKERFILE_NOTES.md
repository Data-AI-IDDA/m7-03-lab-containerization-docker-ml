# Dockerfile Notes

## Baseline build
- Image size: 268 MB (Content size: 84.6 MB)
- Output of `docker run --rm <image>`:
  ONNX model loaded OK: /home/app/model.onnx
    inputs:  1
    outputs: 1

## Stage 1 (builder) — why it exists
This stage is responsible for installing the heavy compilation tools (like GCC/build-essential, curl, and tar) needed to download the ONNX Runtime C SDK and compile the native C verifier binary (`check_model.c`). It acts as an isolated scratchpad where compilation happens without polluting the production environment.

## Stage 2 (runtime) — why it exists
This stage defines the final, lightweight production image. It only inherits a minimal runtime environment, copies the compiled `check_model` binary and the necessary `.so` libraries from Stage 1, and drops all the compiler tools, source code, and package caches to keep the image slim, fast to pull, and secure.

## Three architectural decisions in this Dockerfile

1. **Multi-stage split**
   *If removed:* The final image would inherit all build-essential packages, downloaded tarballs, and source artifacts from the build phase, bloating the image size from ~268 MB to over 600 MB.

2. **The apt-get install --no-install-recommends flags and rm -rf /var/lib/apt/lists/* pattern**
   *If removed:* APT would install auxiliary, non-essential packages (like documentation or recommended tools), and keeping the local package repository index caches inside the container layers would unnecessarily increase the static image size.

3. **The non-root user execution (USER app)**
   *If removed:* The container process would run with full root privileges by default, which violates the principle of least privilege and would break production security policies if a vulnerability inside the ONNX Runtime or runtime container were exploited.