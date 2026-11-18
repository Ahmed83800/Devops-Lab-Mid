FROM python:3.11-slim

WORKDIR /app

# Install dependencies first (cached between builds -> fast rebuilds)
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# App code + freshly trained model produced by the Jenkins "Train" stage
COPY app.py config.json ./
COPY artifacts/ ./artifacts/

EXPOSE 8000
CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "8000"]
