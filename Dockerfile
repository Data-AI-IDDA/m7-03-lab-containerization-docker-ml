# ─────────────────────────────────────────────
# Stage 1: dependency installer
# Installs any OS-level shared libraries the
# runtime binary needs, then strips the image
# down to only those libs in the final stage.
# ─────────────────────────────────────────────
FROM debian:bookworm-slim AS deps

RUN apt-get update && apt-get install -y --no-install-recommends \
        libgomp1 \
        ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# ─────────────────────────────────────────────
# Stage 2: final runtime image
# Contains only: binary, model, required libs,
# and a non-root user.
# ─────────────────────────────────────────────
FROM debian:bookworm-slim AS runtime

# Copy shared libs installed in the deps stage
COPY --from=deps /usr/lib/x86_64-linux-gnu/libgomp.so.1 \
                 /usr/lib/x86_64-linux-gnu/libgomp.so.1
COPY --from=deps /etc/ssl/certs/ca-certificates.crt \
                 /etc/ssl/certs/ca-certificates.crt

# Create a non-root user (uid 1001)
RUN groupadd --gid 1001 appgroup \
    && useradd --uid 1001 --gid appgroup --no-create-home --shell /usr/sbin/nologin appuser

WORKDIR /app

# Copy the pre-compiled inference binary
COPY runtime/serve ./serve
RUN chmod +x ./serve

# Bake the ONNX model into the image
COPY model.onnx ./model.onnx

# Drop privileges
USER appuser

EXPOSE 8080

# Log the model filename on boot via the binary's --model flag.
# The serve binary is expected to print "Loaded model: model.onnx" as its first log line.
CMD ["./serve", "--model", "model.onnx", "--port", "8080"]
