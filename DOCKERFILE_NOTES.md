# Dockerfile Notes

## Baseline build

> Run these commands to fill this section before submitting your PR.

```bash
docker build -t <your-namespace>/m7-03-cat-detection:v1 .
docker images <your-namespace>/m7-03-cat-detection:v1
docker run --rm <your-namespace>/m7-03-cat-detection:v1
```

- **Image size (v1):** `<replace with output of docker images, e.g. 231 MB>`
- **Output of `docker run --rm <image>`:**
  ```
  ONNX model loaded OK: /home/app/model.onnx
    inputs:  1
    outputs: 1
  ```

---

## Stage 1 (builder) — why it exists

Stage 1 exists to compile `check_model.c` into a static binary and validate
the model artifact at **build time**, using tools that must never ship in the
final image. It needs `build-essential` (GCC, ld, libc headers) to compile the
C verifier against ONNX Runtime's C API headers; `curl` and `ca-certificates`
to download the official ONNX Runtime tarball from GitHub; and `file` for the
validation gate. After compilation and validation, the stage has done its job:
its output — the compiled binary at `/out/check_model`, the shared library at
`/opt/onnxruntime/lib/`, and the validated model at `/tmp/model.onnx` — are all
that stage 2 needs. Without this stage, those tools would have to be installed
in the final image, adding roughly 350–400 MB and a broad attack surface with
no runtime benefit.

---

## Stage 2 (runtime) — why it exists

Stage 2 exists to hold the *minimum possible* set of files required to execute
the verifier: the compiled binary (`check_model`), the ONNX Runtime shared
library (`libonnxruntime.so*`), and the model file. It starts from a fresh
`debian:12-slim` layer — meaning none of stage 1's `build-essential`, tarball
remnants, or intermediate object files are present. The only added packages are
`ca-certificates` (general hygiene) and `libstdc++6` (required because ONNX
Runtime uses C++ symbols internally even though our C code calls its C API).
The result is an image around ~230 MB. Without this stage, all of stage 1's
layers would be part of the final image, pushing it to ~600 MB and leaving
compilers accessible inside a running container — a meaningless security risk
for a model-loading workload.

---

## Three architectural decisions in this Dockerfile

### 1. Multi-stage split (builder → runtime)

**What would break if you removed it:** without the split, every layer from
stage 1 — `build-essential` (~200 MB), the extracted 430 MB ONNX Runtime
tarball, `curl`, and the C compiler chain — would be present in the final
image. The image would be ~600 MB instead of ~230 MB, and a `docker exec`
into a running container would expose GCC and linker tools, making it trivial
to compile and run arbitrary code. The split is the single change responsible
for the entire size and security difference between a "just works" image and a
production-grade one.

### 2. Build-time validation gate (`test -s … && file … | grep -qi onnx`)

**What would break if you removed it:** without this gate, a missing, empty,
or silently corrupted `model.onnx` would produce a *successfully built image*
that fails only when `docker run` is invoked — potentially after the image has
been pushed to a registry, pulled by CI, and started as a container. The gate
aborts the build immediately at `docker build` time with a non-zero exit code,
so the bad artifact never becomes a layer. `test -s` alone is insufficient: it
passes on any non-empty file (a README, a JPEG). Adding `file | grep -qi onnx`
confirms the ONNX Protocol Buffer magic bytes are actually present, catching
the case where a placeholder file was accidentally dropped into the repo root.

### 3. Glob copy of the shared library (`libonnxruntime.so*`)

**What would break if you removed it:** ONNX Runtime ships a symlink chain —
`libonnxruntime.so → libonnxruntime.so.1 → libonnxruntime.so.1.20.1`. The GCC
linker records the unversioned soname `libonnxruntime.so` in `check_model`'s
dynamic section; the runtime linker resolves it through the symlinks. Replacing
the glob with an explicit `COPY libonnxruntime.so.1.20.1` copies only the
versioned file and leaves the unversioned symlink in stage 1, never in stage 2.
The binary would build correctly (stage 1 has all three files) but fail at
`docker run` with `error while loading shared libraries: libonnxruntime.so:
cannot open shared object file`. The glob copies all three names atomically,
preserving the symlink resolution path the dynamic linker needs.

---

## Final build (v2 — three improvements applied)

```bash
docker build -t <your-namespace>/m7-03-cat-detection:v2 .
docker run --rm <your-namespace>/m7-03-cat-detection:v2
```

- **Image size (v2):** `<replace — should be within a few MB of v1>`
- **Labels:**
  ```bash
  docker inspect <your-namespace>/m7-03-cat-detection:v2 \
    --format '{{json .Config.Labels}}' | jq .
  ```
  ```json
  {
    "maintainer": "<your-github-handle>",
    "model.framework": "ultralytics-yolo26",
    "model.source": "m6-09-assessment",
    "ort.version": "1.20.1"
  }
  ```
- **HEALTHCHECK spec:**
  ```bash
  docker inspect <your-namespace>/m7-03-cat-detection:v2 \
    --format '{{.Config.Healthcheck}}'
  ```
  ```
  {Test:[CMD-SHELL check_model /home/app/model.onnx || exit 1]
   Interval:30000000000 Timeout:10000000000 StartPeriod:5000000000 Retries:3}
  ```
- **Non-root check:**
  ```bash
  docker run --rm --entrypoint /bin/sh <your-namespace>/m7-03-cat-detection:v2 \
    -c id
  # uid=1001(app) gid=1001(app) groups=1001(app)
  ```

---

## Digest pinning commands (Task 3b)

Run these **on your machine** to get the current `debian:12-slim` digest, then
replace both `sha256:...` values in the `FROM` lines of the Dockerfile:

```bash
docker pull debian:12-slim
docker inspect --format '{{index .RepoDigests 0}}' debian:12-slim
# output: debian@sha256:<hash>
# Use only the sha256:... part in the FROM line, e.g.:
# FROM debian:12-slim@sha256:<hash> AS builder
```

Both stages must use the **same digest** — they describe identical base layers.
