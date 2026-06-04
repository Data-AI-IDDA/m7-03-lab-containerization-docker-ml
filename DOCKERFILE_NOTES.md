# Dockerfile Notes

## Baseline build
- Image size: **123 MB** content/pull size, **~228 MB** uncompressed on disk (sum of
  layers), well under the ~250 MB bar. (Docker 29's `docker images` splits this into
  `CONTENT SIZE` = 123 MB — the compressed blobs you actually push/pull — and
  `DISK USAGE` = 351 MB, which double-counts the base layers shared with the
  builder stage under the containerd snapshotter. The number a reviewer pulls and
  the sum of unique layers both come in under 250 MB.)
- Layer breakdown (`docker history`): debian base 85 MB + apt runtime deps 11 MB +
  `libonnxruntime.so*` 50 MB + model.onnx 82 MB + binary 16 kB.
- Output of `docker run --rm manheim666/m7-03-cat-detection:v1`:
  ```
  ONNX model loaded OK: /home/app/model.onnx
    inputs:  1
    outputs: 1
  ```

## Stage 1 (builder) — why it exists
Stage 1 is the heavy, throwaway toolchain. It pulls `build-essential` (gcc + headers),
`curl`, `file`, and `ca-certificates`, downloads the official ONNX Runtime release
tarball, extracts the headers and `libonnxruntime.so`, and compiles `check_model.c`
into a static-enough binary linked against that lib. It also runs the validation gate
on `model.onnx`. None of this tooling belongs in the shipped image — a compiler, the
17 MB tarball, the apt cache, and the build tree would add hundreds of MB and widen
the attack surface. Stage 1 exists purely to *produce three artifacts* (the compiled
binary, the `.so`, the validated model) that stage 2 copies out.

## Stage 2 (runtime) — why it exists
Stage 2 is the minimal shippable image. It starts from the same pinned `debian:12-slim`,
installs only the two runtime libraries the binary actually dlopen's at run time
(`libstdc++6` for the C++ symbols inside ONNX Runtime, `ca-certificates` for hygiene),
creates a non-root `app` user, and `COPY --from=builder` pulls in only the binary, the
shared library, and the model. No gcc, no tarball, no apt lists. This is what keeps the
final image small and the runtime surface narrow: everything that was needed to *build*
is discarded, only what's needed to *run* survives.

## Three architectural decisions in this Dockerfile

1. **Multi-stage split.** Without it the gcc toolchain, the 17 MB ORT tarball, the
   extracted build tree, and the apt cache would all ship in the final image —
   pushing it from ~228 MB to ~600 MB and shipping a compiler into production.

2. **Validation gate (`test -s … && file … | grep -qi onnx`).** Remove it and a
   missing, empty, or garbage `model.onnx` would build cleanly and only blow up at
   `docker run` on someone else's machine; the gate fails the build at the source,
   where the person who can fix it is standing.

3. **`COPY --from=builder /opt/onnxruntime/lib/libonnxruntime.so*` (glob).** The `.so`
   ships as a versioned real file plus a `libonnxruntime.so` symlink; copying a single
   exact filename instead would either miss the symlink the linker resolves through or
   break when the ORT version (and thus the soname) changes — the glob copies the whole
   symlink chain so `LD_LIBRARY_PATH` resolution works.

## Final build
- Image size: **123 MB** content/pull, **~228 MB** uncompressed (unchanged from
  baseline — the three improvements add metadata and a healthcheck, no extra layers
  of consequence).
- Labels (`docker image inspect … --format '{{json .Config.Labels}}'`):
  ```json
  {
    "maintainer": "Manheim",
    "model.framework": "ultralytics-yolo26",
    "model.source": "m6-09-assessment",
    "ort.version": "1.20.1"
  }
  ```
- Healthcheck (`docker inspect … --format '{{json .Config.Healthcheck}}'`):
  ```json
  {
    "Test": ["CMD-SHELL", "check_model /home/app/model.onnx || exit 1"],
    "Interval": 30000000000,
    "Timeout": 10000000000,
    "StartPeriod": 5000000000,
    "Retries": 3
  }
  ```
- Base pinned by digest in **both** stages:
  `debian:12-slim@sha256:0104b334637a5f19aa9c983a91b54c89887c0984081f2068983107a6f6c21eeb`
- Non-root verified: `docker run --rm --entrypoint /bin/sh <image> -c id` →
  `uid=1001(app) gid=1001(app)`.
