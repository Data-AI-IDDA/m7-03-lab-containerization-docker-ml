# DOCKERFILE_NOTES

## Baseline build

The reference Dockerfile failed on my Apple Silicon (ARM64) machine. The build initially failed because the Dockerfile downloaded the x64 version of ONNX Runtime (`onnxruntime-linux-x64`), which was incompatible with the ARM64 build environment. The linker reported that `libonnxruntime.so` was incompatible and could not be used.

To fix the issue, I modified the Dockerfile to download the ARM64 version of ONNX Runtime (`onnxruntime-linux-aarch64`) and updated the extraction directory accordingly. After rebuilding the image with `--no-cache`, the build completed successfully and the container was able to load the ONNX model.

Baseline image size: 226 MB.

Verification output:

ONNX model loaded OK: /home/app/model.onnx
inputs: 1
outputs: 1


---

## Stage 1 (builder) — why it exists

The builder stage exists to compile the C-based model verification binary and prepare ONNX Runtime dependencies. It includes heavy build tools like gcc, headers, and libraries that are required only during compilation. Keeping this stage separate ensures that these tools do not end up in the final image, reducing its size and improving security.

---

## Stage 2 (runtime) — why it exists

The runtime stage is the minimal production environment. It only contains the compiled binary, ONNX Runtime shared libraries, and the model file. This separation ensures the final container is lightweight and only includes what is necessary to execute the model verification step.

---

## Three architectural decisions in this Dockerfile

1. **Multi-stage build**  
   This keeps build tools (gcc, headers, etc.) out of the final image. Without it, the final image would be significantly larger and less secure.

2. **--no-install-recommends in apt-get**  
   This prevents installation of unnecessary packages, reducing image size and keeping the runtime minimal. Without it, Debian would pull extra dependencies.

3. **Cleaning apt cache (`rm -rf /var/lib/apt/lists/*`)**  
   This removes package metadata after installation. If omitted, the image would include unnecessary cached data, increasing image size.

   ## Final build (v2)

- Labels added: model provenance metadata included in runtime stage
- Base image pinned by digest for reproducibility
- HEALTHCHECK added to validate model verification step

Labels:
{...docker inspect output...}

Healthcheck:
{...docker inspect output...}

Final image size: XXX MB