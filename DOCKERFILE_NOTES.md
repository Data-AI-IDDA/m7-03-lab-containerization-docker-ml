# Dockerfile Notes

## Baseline build
- Image size: 268 MB
- Output of `docker run --rm <image>`:
  ```
  ONNX model loaded OK: /home/app/model.onnx
    inputs:  1
    outputs: 1
  ```

## Stage 1 (builder) — why it exists
The builder stage handles all the resource-intensive tasks required to prepare the application, such as installing build-essential (gcc, make), downloading the large ONNX Runtime tarball, and compiling the C verifier source code. By isolating these tools in a separate stage, we ensure that compilers and intermediate object files do not bloat the final production image, keeping it focused and secure.

## Stage 2 (runtime) — why it exists
The runtime stage serves as the final, slimmed-down image that actually ships to production. It only contains the bare essentials: the compiled binary, the necessary shared libraries, the model file, and a non-root user for security. This separation significantly reduces the attack surface and the image size, making it faster to pull and more secure to run.

## Three architectural decisions in this Dockerfile
1. **Multi-stage build**: Without this, the final image would include build tools and the original ONNX Runtime source/tarball, likely exceeding 600 MB and increasing the security risk.
2. **`apt-get ... && rm -rf /var/lib/apt/lists/*`**: If we didn't remove the package lists, the image would retain megabytes of temporary metadata that are useless after the packages are installed.
3. **Non-root user (app)**: Without the `useradd` and `USER` commands, the application would run as root, meaning any vulnerability in the code or ONNX Runtime could lead to a full container escape or host-level compromise.

## Final build
- Image size: 268 MB (Disk Usage) / 84.6 MB (Content Size)
- Labels:
  ```json
  {
    "maintainer": "nigarrustamova",
    "model.framework": "ultralytics-yolo26",
    "model.source": "m6-09-assessment",
    "ort.version": "1.20.1"
  }
  ```
- Healthcheck:
  ```
  {[CMD-SHELL check_model /home/app/model.onnx || exit 1] 30s 10s 5s 0s 3}
  ```
