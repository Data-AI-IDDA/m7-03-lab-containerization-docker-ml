# Reference Dockerfile — m7-03 lab (Containerization with Docker for ML).
#
# Multi-stage build that:
#   * Stage 1 (builder)  — fetches the ONNX Runtime release, compiles the
#                          provided C verifier against it, and validates
#                          the bundled model.onnx artifact.
#   * Stage 2 (runtime)  — ships only the compiled binary, the ONNX
#                          Runtime shared library, the model file, and
#                          a non-root user. No compilers, no tarballs.

ARG ORT_VERSION=1.20.1

# ──────────────────────────────────────────────────────────────
# Stage 1 — builder
# ──────────────────────────────────────────────────────────────
FROM debian@sha256:0104b334637a5f19aa9c983a91b54c89887c0984081f2068983107a6f6c21eeb AS builder
ARG ORT_VERSION

RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential ca-certificates curl file \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /opt
RUN curl -sSL -o ort.tgz \
        "https://github.com/microsoft/onnxruntime/releases/download/v${ORT_VERSION}/onnxruntime-linux-x64-${ORT_VERSION}.tgz" \
    && tar -xzf ort.tgz \
    && mv "onnxruntime-linux-x64-${ORT_VERSION}" onnxruntime \
    && rm ort.tgz

WORKDIR /build
COPY src/check_model.c .
RUN mkdir -p /out \
    && gcc -O2 -o /out/check_model check_model.c \
        -I/opt/onnxruntime/include \
        -L/opt/onnxruntime/lib \
        -lonnxruntime

COPY model.onnx /tmp/model.onnx
RUN test -s /tmp/model.onnx \
    && file /tmp/model.onnx | grep -qi onnx \
    && echo "Model SHA-256: $(sha256sum /tmp/model.onnx | awk '{print $1}')" \
    && echo "Model size:    $(stat -c%s /tmp/model.onnx) bytes"

# ──────────────────────────────────────────────────────────────
# Stage 2 — runtime
# ──────────────────────────────────────────────────────────────
FROM debian@sha256:0104b334637a5f19aa9c983a91b54c89887c0984081f2068983107a6f6c21eeb AS runtime
ARG ORT_VERSION

RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates libstdc++6 \
    && rm -rf /var/lib/apt/lists/*

RUN useradd --create-home --uid 1001 app

COPY --from=builder /opt/onnxruntime/lib/libonnxruntime.so* /usr/local/lib/
COPY --from=builder /out/check_model /usr/local/bin/check_model
COPY --from=builder --chown=app:app /tmp/model.onnx /home/app/model.onnx

ENV LD_LIBRARY_PATH=/usr/local/lib

LABEL model.source="m6-09-assessment"
LABEL model.framework="ultralytics-yolo26"
LABEL ort.version="${ORT_VERSION}"
LABEL maintainer="ibrahim-suleymanov"

HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD check_model /home/app/model.onnx || exit 1

USER app
WORKDIR /home/app

CMD ["check_model", "/home/app/model.onnx"]