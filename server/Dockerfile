FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
ENV AIKEYBOARD_RELAY_HOST=0.0.0.0

WORKDIR /app
COPY openai_relay.py /app/openai_relay.py

EXPOSE 8787
CMD ["python", "openai_relay.py"]
