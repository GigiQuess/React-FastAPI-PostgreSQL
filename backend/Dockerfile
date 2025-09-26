FROM python:3.11-slim

WORKDIR /workspace/backend

RUN apt-get update && apt-get install -y build-essential git

COPY backend/requirements.txt /workspace/backend/
RUN pip install --no-cache-dir -r requirements.txt

COPY backend /workspace/backend

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000", "--reload"]
