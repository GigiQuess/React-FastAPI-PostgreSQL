FROM python:3.11-slim
WORKDIR /workspace/backend

# 必要な build ツールを入れてキャッシュを消す
RUN apt-get update && apt-get install -y --no-install-recommends \
      build-essential git libpq-dev \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt ./
RUN python -m pip install --upgrade pip && pip install --no-cache-dir -r requirements.txt

COPY . .

# 開発用は --reload のままで良い
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000", "--reload"]
