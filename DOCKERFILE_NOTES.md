# Dockerfile Notes

## Baseline build

- Image size: 214 MB disk usage / 59.1 MB content size

- Output of `docker run --rm kamalmusayev/m7-03-cat-detection:v1`:

```text
ONNX model loaded OK: /home/app/model.onnx
  inputs:  1
  outputs: 1
```

## Stage 1 (builder) — why it exists

The builder stage exists because the project needs build-time tools to compile the small C verifier, but those tools should not be included in the final image. In this stage, the Dockerfile installs packages such as `build-essential`, `gcc`, `curl`, and `file`, downloads ONNX Runtime, and compiles `src/check_model.c` into the `check_model` binary. This stage is temporary: it prepares the executable and the ONNX Runtime libraries, then the final runtime image copies only the needed outputs from it.

## Stage 2 (runtime) — why it exists

The runtime stage exists to keep the shipped image small, focused, and safer to run. It does not include compilers or build tools. It only contains the compiled `check_model` binary, the ONNX Runtime shared libraries, the baked-in `model.onnx`, and the minimum OS dependencies needed to execute the verifier. This stage also creates a non-root user with uid 1001 and runs the container as that user, which is better than running the model verifier as root.

## Three architectural decisions in this Dockerfile

1. **Multi-stage split** — Without the builder/runtime split, the final image would include compilers, headers, curl, and other build-only dependencies, making the image much larger and closer to a development container instead of a slim runtime container.

2. **Validation gate for `model.onnx`** — Without the `test -s /tmp/model.onnx` and `file /tmp/model.onnx | grep -qi onnx` checks, the build could succeed even if the model file was missing, empty, or not actually an ONNX file. This would push the failure to runtime instead of catching it during the image build.

3. **Non-root runtime user** — Without the uid 1001 `app` user, the container would run the verifier as root. Root is not needed for simply loading an ONNX model, and running as root would fail the lab's non-root quality check.



## Final build

- Image size: 214 MB disk usage / 59.1 MB content size

- Output of `docker run --rm kamalmusayev/m7-03-cat-detection:v2`:

```text
ONNX model loaded OK: /home/app/model.onnx
  inputs:  1
  outputs: 1
```

- Labels from `docker inspect kamalmusayev/m7-03-cat-detection:v2 --format '{{json .Config.Labels}}'`:

```json
{"maintainer":"kamalmusayev088","model.framework":"ultralytics-yolo26","model.source":"m6-09-assessment","ort.version":"1.20.1"}
```

- Healthcheck from `docker inspect kamalmusayev/m7-03-cat-detection:v2 --format '{{.Config.Healthcheck}}'`:

```text
{[CMD-SHELL check_model /home/app/model.onnx || exit 1] 30s 10s 5s 0s 3}
```

- Non-root user check from `docker run --rm --entrypoint /bin/sh kamalmusayev/m7-03-cat-detection:v2 -c id`:

```text
uid=1001(app) gid=1001(app) groups=1001(app)
```