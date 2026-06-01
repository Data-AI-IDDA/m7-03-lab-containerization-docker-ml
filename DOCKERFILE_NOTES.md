# Dockerfile Notes

## Baseline build
- Image size: 124MB (content/compressed), ~250MB uncompressed
- Output of `docker run --rm aliguluali/m7-03-cat-detection:v1`:
ONNX model loaded OK: /home/app/model.onnx
inputs:  1
outputs: 1

## Stage 1 (builder) — why it exists
Stage 1 exists to compile the C verifier and validate the model at build time,
using tools that have no place in a production image. It installs build-essential
(gcc, make, libc headers), curl, and the file utility — collectively adding
hundreds of MB of tooling. It also downloads and extracts the full ONNX Runtime
release tarball (~150MB). None of this belongs in the final image: compilers are
a security liability, and the tarball contains headers and static libs the runtime
binary never needs. By doing all of this in a separate stage, we get the compiled
binary and the .so library as clean artifacts, and throw everything else away.

## Stage 2 (runtime) — why it exists
Stage 2 starts from a fresh Debian slim base with no knowledge of stage 1 except
what we explicitly copy in. It installs only two packages: ca-certificates (general
hygiene) and libstdc++6 (the C++ runtime that libonnxruntime.so needs internally).
It creates a non-root user, copies in exactly three artifacts from stage 1 (the
shared library, the compiled binary, and the model), and sets CMD. The result is an
image that can do exactly one thing — verify the model — with the minimum possible
attack surface and no build tooling present.

## Three architectural decisions in this Dockerfile

1. **Multi-stage split** — without this, the final image would include gcc,
   build-essential, curl, the full ONNX Runtime tarball, and all intermediate
   build artifacts, pushing the image from ~250MB to ~600MB+. The split lets us
   use heavyweight tools in stage 1 and ship none of them in stage 2.

2. **Validation gate (`file /tmp/model.onnx | grep -qi onnx`)** — without this,
   a missing, empty, or corrupted model.onnx would produce a valid image that
   exits 1 at runtime with a cryptic error. Failing the build early in stage 1
   means a bad model never becomes a pushed image. It also prints the SHA-256,
   giving you a checksum record in your build logs.

3. **Late placement of `COPY model.onnx`** — the model is copied after the
   compile step, not before. Docker layer caching means if you change the model
   but not check_model.c, all the compilation layers are reused and only the
   COPY and validation steps re-run. Reversing this would invalidate the compile
   cache on every model update, adding 30+ seconds to every rebuild.

## Final build (v2)
- Image size: 124MB (content/compressed)
- Labels:
```json
  {
      "maintainer": "aliguluali",
      "model.framework": "ultralytics-yolo26",
      "model.source": "m6-09-assessment",
      "ort.version": "1.20.1"
  }
```
- Healthcheck: `CMD-SHELL check_model /home/app/model.onnx || exit 1`
  - Interval: 30s | Timeout: 10s | Start-period: 5s | Retries: 3
- Base image pinned by digest: `debian:12-slim@sha256:0104b334637a5f19aa9c983a91b54c89887c0984081f2068983107a6f6c21eeb`
- Both stages pin to the same digest
