# Dockerfile Notes

## Baseline build
- Image size: 268 MB
- Output of `docker run --rm <image>`:
  ONNX model loaded OK: /home/app/model.onnx
    inputs:  1
    outputs: 1

## Stage 1 (builder) — why it exists
Stage 1 exists strictly to assemble the heavy tools required to compile our custom code. It pulls down a development environment containing the C compiler (`gcc` or `build-essential`) and downloads the heavy ONNX Runtime C development headers and libraries. This stage allows us to compile the `check_model.c` code into a self-contained binary file without worrying about polluting our final deployment environment with multi-gigabyte build tools.

## Stage 2 (runtime) — why it exists
Stage 2 acts as the ultra-lean, secure shipping box for our production deployment. Instead of keeping the compilers and download tools from Stage 1, Stage 2 starts with a fresh, bare-minimum operating system footprint. It copies only the final compiled verification binary and the required `.so` shared library files from Stage 1, alongside the `model.onnx` file. Because it strips out all the developer junk, it keeps our deployment incredibly small and lightning-fast to pull.

## Three architectural decisions in this Dockerfile
1. **Multi-Stage Split**
   Without this split, the final image would contain heavy build tools like compilers and raw archive downloads, expanding our image size to roughly 600MB+ and making deployment scaling slow.
   
2. **The Non-Root User (`useradd --uid 1001 app`)**
   Without this dedicated user switch, the container would run its processes with root system privileges by default, meaning any exploit or vulnerability inside our running application could grant an attacker full control over the host server's kernel.

3. **Combining `apt-get update && apt-get install` with file cleanup (`rm -rf /var/lib/apt/lists/*`)**
   Without chaining these commands together and deleting the package registry indices in the exact same layer, Docker would permanently cache those heavy temporary download index files into the layer history, making our image bloated with dead weight we can never recover.

## Final build
- Image size: 268 MB