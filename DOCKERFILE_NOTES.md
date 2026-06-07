# Dockerfile Notes

## Baseline build
- Image size: 172 MB
- Output of `docker run --rm aliagabalayev/m7-03-cat-detection:v1`:
  ```
  ONNX model loaded OK: /home/app/model.onnx
    inputs:  1
    outputs: 1
  ```

## Stage 1 (builder) — why it exists

Stage 1 exists to compile the C verifier binary against the ONNX Runtime headers and shared library, which requires `build-essential` (gcc, make, libc dev headers), `curl` to download the ORT tarball, and `file` for the model validation gate. None of those tools belong in production. Without stage 1, you would either have to pre-build the binary outside Docker (breaking reproducibility) or install a full compiler toolchain into the runtime image, ballooning it from ~172 MB to ~600 MB and shipping attack surface that has no reason to be there.

## Stage 2 (runtime) — why it exists

Stage 2 starts from a clean `debian:12-slim` layer and cherry-picks only what the running container actually needs: the compiled `check_model` binary, the `libonnxruntime.so*` shared library, and the model file itself. The only extra packages installed are `ca-certificates` (general hygiene) and `libstdc++6` (the ORT shared library uses C++ symbols internally). The result is a minimal, auditable image where every byte has a known reason to be there. If stage 2 did not exist and the final image were stage 1, the Docker layer cache would include the compiler, all apt lists, the ORT tarball extraction directory, and every intermediate build artifact — producing an image roughly 3–4× larger with a proportionally larger attack surface.

## Three architectural decisions in this Dockerfile

1. **Multi-stage split** — Without the builder/runtime split, the final image would include `build-essential`, `curl`, the 150 MB ORT tarball extraction tree, and all apt package caches; removing any one of those from stage 1 would break compilation, so they cannot simply be `rm -rf`'d in the same layer and still fit in a sub-250 MB image.

2. **Validation gate (`file /tmp/model.onnx | grep -qi onnx`)** — Without this check, a truncated, empty, or accidentally wrong file (e.g. an LFS pointer) would pass through `COPY model.onnx` silently and only fail at `docker run` time on a developer's or CI machine, long after the build "succeeded"; failing the build at image-creation time catches the mistake at the cheapest possible moment.

3. **Non-root user (`useradd --uid 1001 app`)** — Without the `USER app` directive the container process runs as root (uid 0); if a vulnerability in the model-loading code allows arbitrary code execution, an attacker gains root inside the container, making container-escape exploits and host-mounted-volume writes far easier to carry out than they would be from an unprivileged uid.

## Final build
- Image size: 172 MB
- Labels:
  ```json
  {
    "maintainer": "aliagabalayev",
    "model.framework": "ultralytics-yolo26",
    "model.source": "m6-09-assessment",
    "ort.version": "1.20.1"
  }
  ```
- Healthcheck spec:
  ```
  {Test:[CMD check_model /home/app/model.onnx] Interval:30000000000 Timeout:10000000000 StartPeriod:5000000000 Retries:3}
  ```