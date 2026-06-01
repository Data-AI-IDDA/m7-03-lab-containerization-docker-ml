# Dockerfile Notes

## Baseline build
- Image size: 214
- Output: 1
ONNX model loaded OK...

---

## Stage 1 (builder) — why it exists

Stage 1 is responsible for building the C-based model verification binary and preparing ONNX Runtime dependencies. It includes build tools (gcc, headers, etc.) that are required only during compilation. Without this stage, we would not be able to compile the check_model verifier. It is separated to avoid shipping heavy build dependencies in the final image.

---

## Stage 2 (runtime) — why it exists

Stage 2 is the lightweight runtime environment that only contains what is necessary to execute the ONNX model verification. It copies the compiled binary and ONNX Runtime libraries from the builder stage. This separation reduces image size significantly and ensures the final container is production-ready and minimal.

---

## Three architectural decisions in this Dockerfile

### 1. Multi-stage build
Without multi-stage build, the final image would include compilers, build tools, and unnecessary dependencies, making it significantly larger (~600MB+). This would violate production efficiency requirements.

### 2. Cleaning apt cache (`rm -rf /var/lib/apt/lists/*`)
If this cleanup step is removed, the image size increases unnecessarily because package metadata remains inside the image layers. This is a common Docker optimization pattern to reduce final image size.

### 3. Non-root user execution
Running the container as a non-root user improves security. If removed, the container would run as root, increasing security risks in production environments (privilege escalation, unsafe file access).


`

