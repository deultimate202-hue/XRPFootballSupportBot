FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app ./app
COPY data/seed_faq.json ./data/seed_faq.json

# Run as an unprivileged user; /app/data is where SQLite lives if you use it.
RUN useradd --create-home --uid 10001 bot && mkdir -p /app/data && chown -R bot /app
USER bot

CMD ["python", "-m", "app"]
