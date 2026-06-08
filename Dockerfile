FROM python:3.11-slim

WORKDIR /app

ENV PYTHONPATH=/app

COPY requirements.txt /app/requirements.txt
RUN pip install --no-cache-dir -r requirements.txt

COPY app /app/app
COPY models /app/models
COPY STUDENT.json /app/STUDENT.json

ENV PYTHONUNBUFFERED=1

ENTRYPOINT ["python", "/app/app/cli.py"]