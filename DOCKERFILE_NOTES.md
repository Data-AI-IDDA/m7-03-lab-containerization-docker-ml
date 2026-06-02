# Dockerfile Notes

## Baseline build

- Image tag: `elvinnasirov/m7-03-cat-detection:v1`
- Image size: **214 MB** disk usage / **59.1 MB** content size (`docker images elvinnasirov/m7-03-cat-detection`)
- Output of `docker run --rm elvinnasirov/m7-03-cat-detection:v1`:

```
ONNX model loaded OK: /home/app/model.onnx
  inputs:  1
  outputs: 1
```

Baseline v1 used the reference Dockerfile before Task 3 (no digest pin, LABELs, or HEALTHCHECK).

## Stage 1 (builder) — why it exists

Stage `builder` is a disposable compile-and-validate environment on digest-pinned Debian slim. It installs `build-essential`, `curl`, and `file`, downloads the official ONNX Runtime Linux tarball for `ORT_VERSION=1.20.1`, and compiles `check_model.c` against `libonnxruntime` with GCC. Before anything reaches the runtime image, the stage copies the local ONNX artifact into `/tmp/model.onnx` and runs a validation gate: the file must be non-empty, must look like ONNX (`file | grep -qi onnx`), and its SHA-256 is logged. This stage exists because production must not ship compilers, headers, or the full ORT SDK — only the compiled binary and validated artifact cross the stage boundary.

## Stage 2 (runtime) — why it exists

Stage `runtime` is the image consumers pull and run. It installs only `ca-certificates` and `libstdc++6`, creates non-root user `app` (uid 1001), copies `libonnxruntime.so*` and the `check_model` binary from builder, and places the validated model at `/home/app/model.onnx` with correct ownership. Provenance LABELs, `LD_LIBRARY_PATH`, HEALTHCHECK, and `CMD` live here. Everything from builder that is not required at run time — GCC, `build-essential`, ORT headers, tarball extract — is discarded, which keeps disk usage at **214 MB** (under the lab’s ~250 MB bar) instead of ~600 MB for a single-stage build.

## Three architectural decisions in this Dockerfile

1. **Multi-stage build (builder → runtime)** — Without splitting stages, `build-essential`, GCC, and the full ONNX Runtime tree would remain in the final filesystem; the image would grow toward ~600 MB and ship compilers in a production-facing verifier container.

2. **Non-root user (`useradd --uid 1001 app`, `USER app`)** — Without running as `app`, the process would execute as root inside the container; any compromise of the verifier would inherit root privileges over the container filesystem instead of a limited uid 1001 account.

3. **`COPY libonnxruntime.so*` plus `LD_LIBRARY_PATH=/usr/local/lib`** — ONNX Runtime publishes versioned shared objects and symlinks; copying one hard-coded `.so` name breaks when the soname changes, and without `LD_LIBRARY_PATH` the dynamic linker cannot resolve `libonnxruntime` even when the binary is present (`error while loading shared libraries`).

## Final build

- **Public image:** `lw1ntzy/m7-03-cat-detection:v2`
- **Local build tag (before retag):** `elvinnasirov/m7-03-cat-detection:v2`
- Image size: **214 MB** disk usage / **59.1 MB** content size (`docker images elvinnasirov/m7-03-cat-detection` — v2 matches v1)
- Output of `docker run --rm lw1ntzy/m7-03-cat-detection:v2`:

```
ONNX model loaded OK: /home/app/model.onnx
inputs:  1
outputs: 1
```

**Labels** (`docker inspect elvinnasirov/m7-03-cat-detection:v2 --format '{{json .Config.Labels}}'`):

```json
{"maintainer":"elvinnasirov","model.framework":"ultralytics-yolo26","model.source":"m6-09-assessment","ort.version":"1.20.1"}
```

**HEALTHCHECK** (`docker inspect elvinnasirov/m7-03-cat-detection:v2 --format '{{.Config.Healthcheck}}'`):

```
{[CMD-SHELL check_model /home/app/model.onnx || exit 1] 30s 10s 5s 0s 3}
```

**Non-root check** (`MSYS_NO_PATHCONV=1 docker run --rm --entrypoint /bin/sh elvinnasirov/m7-03-cat-detection:v2 -c id`):

```
uid=1001(app) gid=1001(app) groups=1001(app)
```

**Supply-chain pin:** Both stages use `debian:12-slim@sha256:0104b334637a5f19aa9c983a91b54c89887c0984081f2068983107a6f6c21eeb`.

---

## Error notes / post-mortems

**Docker Desktop / virtualization:** Docker Desktop initially could not start until CPU virtualization support was enabled in firmware/BIOS (and related Windows features). After enabling virtualization and restarting, `docker info` succeeded and builds completed.

**Non-root check in Git Bash:** `docker run --rm --entrypoint /bin/sh … -c id` initially failed because Git Bash rewrote `/bin/sh` to a Windows path before passing it to Docker. Fix: prefix the command with `MSYS_NO_PATHCONV=1` so the entrypoint stays a Linux path inside the container.

**Docker Hub namespace:** The image was built locally as `elvinnasirov/m7-03-cat-detection:v2`, verified with `docker inspect`, then retagged and pushed to the authenticated Docker Hub namespace as `lw1ntzy/m7-03-cat-detection:v2`. Pull and PR documentation use the public `lw1ntzy/` name.

**Local ONNX artifact:** The cat-detection ONNX file is required in the repo root for `docker build` only; it is listed in `.gitignore` and must not be committed to source control.
