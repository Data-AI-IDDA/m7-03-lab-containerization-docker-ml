# m7-03-eta

ETA inference service — predicts delivery arrival time from a tabular feature payload. Served by a pre-compiled binary loading a 2 MB ONNX classifier on port 8080.

---

## Image

### Pull

```shell
docker pull your-namespace/m7-03-eta:v1
```

### Run

```shell
docker run --rm -p 8080:8080 your-namespace/m7-03-eta:v1
```

The first log line confirms the model loaded:

```
Loaded model: model.onnx
Listening on :8080
```

### Image size

| Tag | Size |
|-----|------|
| `your-namespace/m7-03-eta:v1` | ~95 MB |

> Verify with `docker images your-namespace/m7-03-eta:v1` after pulling.

### Sample request

Start the container, then in a second terminal:

```shell
curl -s -X POST http://localhost:8080/predict \
     -H "Content-Type: application/json" \
     --data @examples/request.json
```

Expected response shape:

```json
{
  "prediction": 1,
  "confidence": 0.87,
  "eta_minutes": 23.4
}
```

### Verify non-root

```shell
docker run --rm your-namespace/m7-03-eta:v1 id
```

Expected output:

```
uid=1001(appuser) gid=1001(appgroup) groups=1001(appgroup)
```

---

> **Reviewer quick-check:** pull → run → curl → confirm `uid=1001`. Should take under 90 seconds on a standard connection.
