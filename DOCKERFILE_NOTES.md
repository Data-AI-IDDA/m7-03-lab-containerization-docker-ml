# Dockerfile Notes

## Baseline build
- Image size: **214 MB** (the three Task-3 improvements — digest pin, four
  LABELs, one HEALTHCHECK — add only metadata, so the baseline and final image
  are the same size to the megabyte).
- Output of `docker run --rm <image>`:
  ```
  ONNX model loaded OK: /home/app/model.onnx
    inputs:  1
    outputs: 1
  ```

> NOTE: The reference Dockerfile built cleanly on the first attempt once Docker
> Desktop (WSL2 backend) was running and `model.onnx` (the m6-09 cat model,
> 9,804,957 bytes) was copied into the repo root. The validation gate
> (`file /tmp/model.onnx | grep -qi onnx`) passed — the YOLO26 ONNX export is
> recognised by `file`, so no fix was required.

## Stage 1 (builder) — why it exists

Stage 1 is the heavy, throwaway toolchain. It installs `build-essential`,
`curl`, `file`, and `ca-certificates`, downloads the official ONNX Runtime
release tarball, and uses `gcc` to compile `check_model.c` against ONNX
Runtime's headers and shared library. It also runs the validation gate that
proves the bundled `model.onnx` exists, is non-empty, and is actually an ONNX
file before anything ships. None of this — the compiler, the tarball, the apt
caches — needs to exist in the final image; it only needs to *produce* a
binary, a `.so`, and a vetted model file. Keeping it in its own stage means all
that weight is discarded at the stage boundary.

## Stage 2 (runtime) — why it exists

Stage 2 is the slim shipping image. It starts from a fresh `debian:12-slim`
and installs only what the compiled binary needs to *run*: `libstdc++6` (the
ONNX Runtime `.so` uses C++ symbols internally) and `ca-certificates`. It
creates a non-root `app` user (uid 1001), then `COPY --from=builder` pulls in
exactly three artifacts — `libonnxruntime.so*`, the `check_model` binary, and
`model.onnx` — and nothing else. No compiler, no tarball, no apt lists. This is
what gets pushed and pulled, so it stays under ~250 MB instead of the ~600 MB a
single-stage build would weigh.

## Three architectural decisions in this Dockerfile

1. **Multi-stage split (builder vs. runtime).** Remove it and the final image
   carries `build-essential`, the ONNX Runtime tarball, and apt caches — ~600 MB
   instead of <250 MB, plus a compiler in production is needless attack surface.

2. **The validation gate (`test -s` + `file | grep -qi onnx`).** Remove it and a
   missing, empty, or non-ONNX `model.onnx` would sail through the build and only
   blow up at `docker run` on a user's machine instead of failing fast at build.

3. **Non-root user (`useradd --uid 1001 app` + `USER app`).** Remove it and the
   container runs as root by default, so a process escape inherits root in the
   container — and the lab's `id` check (uid 1001) fails outright.

## Final build

- Image size: **214 MB** uncompressed on-disk (~59 MB compressed content at the
  registry), per `docker images raulito7/m7-03-cat-detection:v2`. Under the
  ~250 MB bar; a single-stage build carrying `build-essential` + the ONNX Runtime
  tarball would be ~600 MB.
- `docker run --rm raulito7/m7-03-cat-detection:v2` output:
  ```
  ONNX model loaded OK: /home/app/model.onnx
    inputs:  1
    outputs: 1
  ```
- Non-root verified: `docker run --rm --entrypoint /bin/sh <image> -c id` →
  `uid=1001(app) gid=1001(app) groups=1001(app)`.
- Validation gate passed at build: model SHA-256
  `cd244e1326c75e9990fa6961ba4b4b1b81209a1ad6a6dcdfa814ea7f4dfd5a2d`, size
  `9804957` bytes — `file | grep -qi onnx` matched the YOLO26 export.

Three improvements applied to the Dockerfile (all verified post-build):

- **Labels** (`docker image inspect <image> --format '{{json .Config.Labels}}'`):
  ```json
  {
    "maintainer": "raulibrahimov",
    "model.framework": "ultralytics-yolo26",
    "model.source": "m6-09-assessment",
    "ort.version": "1.20.1"
  }
  ```
  (`ort.version` resolves from the `ORT_VERSION` ARG default, `1.20.1`.)

- **Base pinned by digest**: both `FROM` lines pin the same digest —
  `debian:12-slim@sha256:0104b334637a5f19aa9c983a91b54c89887c0984081f2068983107a6f6c21eeb`
  (read via `docker inspect --format '{{index .RepoDigests 0}}' debian:12-slim`
  after `docker pull debian:12-slim`). Tag-based pulls can drift; the digest can't.

- **Healthcheck** (`docker inspect <image> --format '{{.Config.Healthcheck}}'` →
  `{[CMD-SHELL check_model /home/app/model.onnx || exit 1] 30s 10s 5s 0s 3}`):
  ```
  Interval:    30s
  Timeout:     10s
  StartPeriod: 5s
  Retries:     3
  Test:        CMD-SHELL check_model /home/app/model.onnx || exit 1
  ```
