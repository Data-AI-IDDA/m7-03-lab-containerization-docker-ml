import numpy as np
import onnxruntime as ort
from PIL import Image


class CatDetector:

    def __init__(
        self,
        onnx_path="/app/models/best.onnx",
        imgsz=640,
        conf=0.25,
        class_names=("cat",)
    ):
        self.session = ort.InferenceSession(
            onnx_path,
            providers=["CPUExecutionProvider"]
        )

        self.imgsz = imgsz
        self.conf = conf
        self.class_names = class_names
        self.input_name = self.session.get_inputs()[0].name

    def _letterbox(self, img, new_shape=640):
        w, h = img.size

        scale = min(new_shape / w, new_shape / h)

        nw = int(round(w * scale))
        nh = int(round(h * scale))

        resized = img.resize((nw, nh))

        canvas = Image.new(
            "RGB",
            (new_shape, new_shape),
            (114, 114, 114)
        )

        pad_x = (new_shape - nw) / 2
        pad_y = (new_shape - nh) / 2

        canvas.paste(
            resized,
            (int(pad_x), int(pad_y))
        )

        return canvas, scale, (pad_x, pad_y)

    def predict(self, image_path):

        img = Image.open(image_path).convert("RGB")

        orig_w, orig_h = img.size

        x, scale, (pad_x, pad_y) = self._letterbox(
            img,
            self.imgsz
        )

        x = (
            np.array(x, dtype=np.float32)
            / 255.0
        )

        x = x.transpose(2, 0, 1)[None, ...]

        out = self.session.run(
            None,
            {self.input_name: x}
        )[0]

        out = out[0]

        results = []

        for x1, y1, x2, y2, score, cls in out:

            if score < self.conf:
                continue

            x1 = (x1 - pad_x) / scale
            y1 = (y1 - pad_y) / scale
            x2 = (x2 - pad_x) / scale
            y2 = (y2 - pad_y) / scale

            x1 = max(0.0, min(orig_w, x1))
            y1 = max(0.0, min(orig_h, y1))
            x2 = max(0.0, min(orig_w, x2))
            y2 = max(0.0, min(orig_h, y2))

            results.append(
                {
                    "xmin": float(x1),
                    "ymin": float(y1),
                    "xmax": float(x2),
                    "ymax": float(y2),
                    "confidence": float(score),
                    "class": self.class_names[int(cls)]
                }
            )

        return results