# Dockerfile Notes

## Baseline build
- Image size: 214MB
- Output of `docker run --rm dirayeva06/m7-03-cat-detection:v1`:

ONNX model loaded OK: /home/app/model.onnx  
inputs:  1  
outputs: 1  


## Stage 1 (builder) — why it exists
The builder stage isolates the compilation environment, installing heavy build tools like `gcc`, `make`, and `curl` required to download the ONNX Runtime and compile the C verifier application. By separating this into a distinct stage, we ensure that bulky compilers and temporary download artifacts do not carry over into the final image, keeping it lightweight and secure.

## Stage 2 (runtime) — why it exists
The runtime stage defines the minimal execution environment for the application. It only includes the compiled binary (`check_model`), required shared libraries (`libonnxruntime.so*`), and the model file. This significantly reduces the image size and minimizes the attack surface, making it suitable for production deployment.

## Three architectural decisions in this Dockerfile

1. **Multi-stage build**  
If removed, the final image would include all build tools and dependencies (like `gcc` and headers), dramatically increasing image size and introducing unnecessary security risks.

2. **The `apt-get update && apt-get install ... && rm -rf /var/lib/apt/lists/*` pattern**  
If removed, package manager cache files would remain in the image layers, increasing the final image size without adding any functional value.

3. **Position of `COPY model.onnx` near the end of the build**  
If placed earlier, any change in the model file would invalidate the Docker build cache for all subsequent layers, forcing a full rebuild including dependency installation and compilation, which slows down iteration significantly.

## Final build

- Image size: 214MB

- Labels:
{
  "maintainer": "dirayeva06",
  "model.framework": "ultralytics-yolo26",
  "model.source": "m6-09-assessment",
  "ort.version": "1.20.1"
}

- Healthcheck:
{
  "Test": ["CMD-SHELL", "check_model /home/app/model.onnx || exit 1"],
  "Interval": "30s",
  "Timeout": "10s",
  "StartPeriod": "5s",
  "Retries": 3
}