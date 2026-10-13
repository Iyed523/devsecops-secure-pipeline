FROM docker.io/library/python:3.13-slim-bookworm@sha256:a1165e272e578941b84abc79e4ab38a0305cd12803a5c4247979ac7655f4d641

LABEL org.opencontainers.image.source="https://github.com/Iyed523/devsecops-secure-pipeline"

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app

COPY requirements.txt ./requirements.txt

RUN python -m pip install \
    --no-cache-dir \
    --require-hashes \
    -r requirements.txt \
    && python -m pip uninstall --yes pip

COPY src/ ./src/

USER 10001:10001

EXPOSE 8000

CMD ["python", "-m", "uvicorn", "devsecops_demo.main:app", "--app-dir", "/app/src", "--host", "0.0.0.0", "--port", "8000"]