# Dockerfile Notes

## Baseline build
- Image size: 123 MB
- Output of `docker run --rm <image>`:
 ```
  ONNX model loaded OK: /home/app/model.onnx
  inputs:  1
  outputs: 1
 ```


## Stage 1 (builder) — why it exists
The primary purpose of the builder stage is to keep the final container image as small and efficient as possible. To compile the check_model C utility, we require heavy tools like gcc and build-essential, which consume hundreds of megabytes of space. By separating this into a dedicated builder stage, we perform all the "heavy lifting" (compilation) in an isolated environment. Once the source code is compiled into a lightweight binary, we copy only the final artifact into the runtime stage and discard the bulky build tools, resulting in a significantly smaller and more secure production image.

## Stage 2 (runtime) — why it exists
The runtime stage represents the lean, production-ready environment that serves as the final image. Its purpose is to provide the minimum necessary execution context for the application, stripped of all build-time dependencies. By copying only the pre-compiled binary (check_model) and the required shared libraries from the builder stage, we ensure that the image is secure and highly optimized in size. This separation of concerns ensures that the end-user or production server does not need to store, manage, or run any unnecessary development tools, keeping the attack surface small and the footprint minimal.

## Three architectural decisions in this Dockerfile
1. Multi-stage split: If we removed this, our final image would include bulky build tools like gcc and build-essential, which would significantly increase the image size by hundreds of megabytes.
2. Non-root user (app): If we removed this, the application would run with root privileges, which would create a critical security vulnerability allowing an attacker to potentially compromise the host system.
3. Position of COPY model.onnx (Cache impact): If we moved this instruction to the beginning, every minor update to the model file would invalidate the Docker cache, forcing a complete and time-consuming re-installation of all system dependencies during every build.

## Final build

* **Image Size:** 123MB

* **Labels:**
  ```json
  {"maintainer":"seljankhasiyeva","model.framework":"ultralytics-yolo26","model.source":"m6-09-assessment","ort.version":"1.20.1"}

* **Healthcheck spec:**

  {[CMD-SHELL check_model /home/app/model.onnx || exit 1] 30s 10s 5s 0s 3}