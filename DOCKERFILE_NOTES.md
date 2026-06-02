# Dockerfile Notes

## Baseline build

- Image size: ~228 MB (baseline v1)
- Output of `docker run --rm <image>`:
  ```
  ONNX model loaded OK: /home/app/model.onnx
    inputs:  1
    outputs: 1
  ```

## Stage 1 (builder) — why it exists

Stage 1 is a fully-equipped build environment that we deliberately throw away. It installs `build-essential` (gcc, make, libc headers), `curl`, and `file`, downloads the 180 MB+ ONNX Runtime tarball, compiles `check_model.c` into a native binary, and runs a validation gate that rejects a missing or malformed model artifact before the runtime layer is even created. All of these tools — the compiler, the headers, the tarball, the C source — are needed to produce the binary, but zero of them need to exist in the final image a user will pull. Without stage 1 we'd have no compiled binary; without discarding it we'd be shipping a ~600 MB image full of compilers and intermediate files that add attack surface and waste registry storage.

## Stage 2 (runtime) — why it exists

Stage 2 is the image users actually pull and run. It starts from a fresh, clean `debian:12-slim` layer — it inherits nothing from stage 1's filesystem except what we explicitly `COPY --from=builder`. The only additions are: the two minimal runtime apt packages (`ca-certificates`, `libstdc++6`), a non-root user, the compiled `check_model` binary, the ONNX Runtime shared library (just the `.so` files, not headers or the tarball), and the model file. The result is a ~228 MB image instead of ~600 MB, with no build tools, no C sources, no cached apt lists, and no root shell by default. If stage 2 didn't exist and we shipped everything from stage 1, we'd fail the <250 MB quality bar immediately and expose unnecessary tooling to anyone who exec's into the container.

## Three architectural decisions in this Dockerfile

1. **Multi-stage split** — Without the two-stage split, every tool installed in stage 1 (`build-essential`, the 180 MB ORT tarball, `curl`, header files) would land in the shipped image. The result would be ~600 MB instead of ~228 MB, and the final image would carry a compiler and a C source file that serve no purpose at runtime — pure bloat and attack surface with no upside.

2. **`apt-get … && rm -rf /var/lib/apt/lists/*` pattern** — Docker commits each `RUN` instruction as a new layer. If you split `apt-get update` into one `RUN` and the `rm -rf` into another, the cached apt index survives in an intermediate layer and gets baked into the image. Chaining them in a single `RUN` ensures the index is deleted in the same layer it was created, so it never occupies space in any shipped layer. Removing this pattern would add ~20–40 MB of stale package metadata to every image rebuild.

3. **Non-root user (`useradd --uid 1001 app`)** — Containers run as root by default, which means a vulnerability in the binary could give an attacker a root shell inside the container — and potentially host-level access if the Docker socket is mounted or namespace protections are misconfigured. The `USER app` directive drops privileges before CMD executes. Removing it means `docker run --rm --entrypoint /bin/sh <image> -c id` would return `uid=0(root)`, failing the quality bar check and violating the principle of least privilege.

## Final build (v2)

- Image size: ~228 MB (unchanged — the three improvements add only metadata)
- Labels (from `docker image inspect <image> --format '{{json .Config.Labels}}'`):
  ```json
  {
    "maintainer": "Jabrail-Atakishiyev",
    "model.framework": "ultralytics-yolo26",
    "model.source": "m6-09-assessment",
    "ort.version": "1.20.1"
  }
  ```
- Healthcheck (from `docker inspect <image> --format '{{.Config.Healthcheck}}'`):
  ```
  {Test:[CMD check_model /home/app/model.onnx || exit 1] Interval:30000000000 Timeout:10000000000 StartPeriod:5000000000 Retries:3}
  ```
- Base image pinned by digest: `debian:12-slim@sha256:346dd1cba3caf44de9467ae428a9d38573f14665408acb80a615e2a7c3f9a2a4`
