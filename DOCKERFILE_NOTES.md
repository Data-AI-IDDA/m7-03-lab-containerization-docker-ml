\# Dockerfile Notes



\## Baseline build

\- Image size: 268 MB (disk), 84.6 MB (content)

\- Output of `docker run --rm gasimova51/m7-03-cat-detection:v1`:

&#x20; ONNX model loaded OK: /home/app/model.onnx

&#x20;   inputs:  1

&#x20;   outputs: 1



\## Stage 1 (builder) — why it exists

Stage 1 exists to compile the C verifier and validate the model in an

environment that has all the build tools (gcc, curl, build-essential).

These tools are large and unnecessary at runtime — they are only needed

once to produce the binary. Without a separate builder stage, the final

image would contain gcc, curl, and the full ONNX Runtime tarball, making

it hundreds of megabytes larger and introducing unnecessary attack surface.



\## Stage 2 (runtime) — why it exists

Stage 2 exists to produce a minimal, secure runtime image that contains

only what is needed to run the verifier: the compiled binary, the ONNX

Runtime shared library, and the model file. It runs as a non-root user

(uid 1001) which reduces security risk. By starting from a fresh

debian:12-slim, none of the build tools from Stage 1 leak into the

final image, keeping it lean and production-ready.



\## Three architectural decisions in this Dockerfile



1\. \*\*Multi-stage split\*\* — if you removed the two-stage structure and

&#x20;  used a single stage, the final image would include gcc, curl,

&#x20;  build-essential, and the full ONNX Runtime tarball (\~150MB extra),

&#x20;  making it significantly larger and less secure.



2\. \*\*Validation gate (`file | grep -qi onnx`)\*\* — if you removed this

&#x20;  check, a missing, empty, or corrupted model.onnx would silently

&#x20;  produce a broken image that only fails at runtime on the instructor's

&#x20;  machine, not at build time where it is easy to catch and fix.



3\. \*\*Non-root user (uid 1001)\*\* — if you removed the `useradd` and

&#x20;  `USER app` instructions, the container would run as root, which is

&#x20;  a security risk in production and violates container best practices,

&#x20;  as a compromised container running as root has far more system access.


## Final build (v4)
- Disk usage: 268 MB
- Content size: 84.6 MB
- Same size as baseline (labels and healthcheck are metadata only)

### Labels
{"maintainer":"khavar-analytics","model.framework":"ultralytics-yolo26","model.source":"m6-09-assessment","ort.version":"1.20.1"}

### Healthcheck
{"Test":["CMD-SHELL","check_model /home/app/model.onnx || exit 1"],"Interval":30000000000,"Timeout":10000000000,"StartPeriod":5000000000,"Retries":3}

## Changes made in Task 3
- 3a: Added 4 provenance LABELs to Stage 2
- 3b: Pinned debian:12-slim to digest sha256:0104b334...
- 3c: Added HEALTHCHECK using check_model binary

