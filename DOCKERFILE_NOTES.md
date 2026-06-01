# Dockerfile Notes

## Baseline build

* Image size: 119 MB

* Output of `docker run --rm <image>`:

```text
ONNX model loaded OK: /home/app/model.onnx
  inputs: 1
  outputs: 1
```

## Stage 1 (builder) — why it exists

The builder stage exists so the container can compile the `check_model.c` verifier using development tools like `gcc`, `make`, and header files without shipping those tools in the final runtime image. Without this separation, the final image would include unnecessary compilers and build dependencies, significantly increasing image size and attack surface.

## Stage 2 (runtime) — why it exists

The runtime stage contains only the compiled verifier binary, ONNX Runtime shared libraries, and the ONNX model itself. This keeps the final image lightweight, faster to distribute, and more secure because it excludes build tooling and temporary package metadata from the final container.

## Three architectural decisions in this Dockerfile

1. Multi-stage build
   Without the multi-stage split, build dependencies like `build-essential` would remain in the production image, increasing the image size from roughly ~200 MB to potentially 600+ MB.

2. `apt-get ... && rm -rf /var/lib/apt/lists/*` cleanup pattern
   Removing cached package metadata prevents unnecessary Debian package indexes from being stored in image layers. Without cleanup, the image becomes larger for no runtime benefit.

3. Non-root user execution
   Running the container as a non-root user limits the impact of a container escape or application vulnerability. Without this, any compromise inside the container would execute with root privileges.
