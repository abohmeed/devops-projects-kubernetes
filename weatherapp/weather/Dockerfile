FROM python:3.13.15-slim-trixie
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1
WORKDIR /app
COPY requirements.txt requirements.txt
RUN pip install --no-cache-dir -r requirements.txt && pip check
COPY main.py symbols.py cities.csv ./
RUN useradd --uid 10001 --no-create-home app
USER 10001
EXPOSE 5000
# gunicorn replaces the Flask development server the 2021 image ran
CMD ["gunicorn", "--bind", "0.0.0.0:5000", "--workers", "2", "--access-logfile", "-", "--no-control-socket", "main:app"]
