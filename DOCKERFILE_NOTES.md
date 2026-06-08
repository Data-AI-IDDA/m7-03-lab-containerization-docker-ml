# Dockerfile Notes

## Baseline build

* Image size: 268 MB

Output:

```text
ONNX model loaded OK: /home/app/model.onnx
  inputs: 1
  outputs: 1
```

## Stage 1 (builder) — why it exists

The builder stage downloads ONNX Runtime, installs build tools, and compiles the check_model verifier. Without this stage the verifier binary could not be built. Keeping compilation separate prevents build tools from being included in the final runtime image.

## Stage 2 (runtime) — why it exists

The runtime stage contains only the compiled verifier, ONNX Runtime shared libraries, and the model file. This keeps the image smaller, reduces the attack surface, and avoids shipping unnecessary build dependencies.

## Three architectural decisions in this Dockerfile

1. Multi-stage build — Without it, compiler toolchains and build dependencies would remain in the final image, significantly increasing image size.

2. Non-root user — Without it, the container would run as root, increasing security risk if the container were compromised.

3. Validation gate — Without it, an invalid or missing ONNX model could pass the build process and fail only at runtime.

## Final build

* Image size: 268 MB

Labels:

```json
{"maintainer":"gonca516","model.framework":"ultralytics-yolo26","model.source":"m6-09-assessment","ort.version":"1.20.1"}
```

Healthcheck:

```json
{"Test":["CMD-SHELL","check_model /home/app/model.onnx || exit 1"],"Interval":30000000000,"Timeout":10000000000,"StartPeriod":5000000000,"Retries":3}
```


