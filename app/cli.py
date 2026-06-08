import os
import sys
import json
import csv

from app.detector import CatDetector


INPUT_DIR = "/data/input"
OUTPUT_DIR = "/data/output"
OUTPUT_CSV = "/data/output/predictions.csv"

STUDENT_JSON = "/app/STUDENT.json"


def run_info():

    with open(STUDENT_JSON, "r") as f:
        data = json.load(f)

    print(
        json.dumps(
            data,
            indent=2
        )
    )


def run_predict():

    detector = CatDetector()

    os.makedirs(
        OUTPUT_DIR,
        exist_ok=True
    )

    with open(
        OUTPUT_CSV,
        "w",
        newline="",
        encoding="utf-8"
    ) as csvfile:

        writer = csv.writer(csvfile)

        writer.writerow(
            [
                "image_path",
                "xmin",
                "ymin",
                "xmax",
                "ymax",
                "confidence",
                "class"
            ]
        )

        for root, dirs, files in os.walk(INPUT_DIR):

            for file in files:

                if not file.lower().endswith(
                    (".jpg", ".jpeg", ".png")
                ):
                    continue

                full_path = os.path.join(
                    root,
                    file
                )

                rel_path = os.path.relpath(full_path, INPUT_DIR).replace("\\", "/")

                detections = detector.predict(
                    full_path
                )

                if len(detections) == 0:

                    writer.writerow(
                        [
                            rel_path,
                            "",
                            "",
                            "",
                            "",
                            "",
                            ""
                        ]
                    )

                else:

                    for d in detections:

                        writer.writerow(
                            [
                                rel_path,
                                d["xmin"],
                                d["ymin"],
                                d["xmax"],
                                d["ymax"],
                                d["confidence"],
                                d["class"]
                            ]
                        )


def main():

    if len(sys.argv) < 2:
        sys.exit(1)

    command = sys.argv[1]

    if command == "info":
        run_info()

    elif command == "predict":
        run_predict()

    else:
        sys.exit(1)


if __name__ == "__main__":
    main()