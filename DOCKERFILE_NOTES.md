# Dockerfile Notes

## Baseline build
- Image size: 214 MB
- Output of `docker run --rm maqa333/m7-03-cat-detection:v1`:

## Stage 1 (builder) — why it exists
Stage 1 exists to produce the compiled binary without polluting the final image.
It installs build-essential (gcc, make, libc headers) and curl, downloads the
ONNX Runtime release tarball, compiles check_model.c against its headers and
shared library, then validates model.onnx is a real ONNX artifact. None of
these tools — compiler, tarball, headers — are needed at runtime, so they are
intentionally left behind in this stage.

## Stage 2 (runtime) — why it exists
Stage 2 exists to ship the smallest possible image that can actually run the
verifier. It copies only three things from stage 1: the compiled binary, the
libonnxruntime.so shared library, and model.onnx. By starting fresh from
debian:12-slim and copying only those artifacts, the final image is ~214 MB
instead of the ~600 MB a single-stage build would produce.

## Three architectural decisions in this Dockerfile

1. **Multi-stage split** — without it the final image would include gcc,
   build-essential, the full ORT tarball, and all apt package lists, pushing
   the image past 600 MB and shipping a compiler into production unnecessarily.

2. **Validation gate (`file | grep -qi onnx`)** — without it a missing or
   corrupted model.onnx would produce a silently broken image that only fails
   at container runtime, not at build time where the error is easiest to catch.

3. **Non-root user (UID 1001)** — without it the container process runs as
   root, meaning any exploit in check_model or the ORT library would have full
   container-root privileges, violating the principle of least privilege.