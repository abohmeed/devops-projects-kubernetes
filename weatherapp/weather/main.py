"""The weather service: current weather for a city, with no API key.

Cities are looked up in cities.csv, which ships inside the image (GeoNames, every city with at
least 100,000 people, CC BY 4.0). The weather comes from MET Norway's free Locationforecast API
(data CC BY 4.0, commercial use allowed). MET Norway asks every app to identify itself with a
contact address in its User-Agent, so the service needs WEATHER_CONTACT: an email address or a
URL where MET Norway can reach you. Without it the service still runs and answers weather
requests with 503.

The JSON keeps the shape the UI reads: location.name, location.country, current.temp_c,
current.temp_f, current.feelslike_c, current.feelslike_f, current.condition.text and .icon.
"""

import csv
import math
import os
import threading
import time
from email.utils import parsedate_to_datetime
from pathlib import Path

import requests
from flask import Flask, jsonify
from flask_cors import CORS

from symbols import SYMBOLS

VERSION = "3.0.0"
MET_URL = "https://api.met.no/weatherapi/locationforecast/2.0/compact"
ATTRIBUTION = "Weather data from MET Norway (CC BY 4.0). Places from GeoNames (CC BY 4.0)."

app = Flask(__name__)
CORS(app)


def load_cities(path=Path(__file__).with_name("cities.csv")):
    """Index the city table by lower-case name. The file is sorted by population, so the first
    city stored under a name is the biggest one (London, United Kingdom before London, Canada)."""
    cities = {}
    with open(path, encoding="utf-8", newline="") as f:
        for row in csv.DictReader(f):
            city = {
                "name": row["name"],
                "country": row["country"],
                "lat": float(row["lat"]),
                "lon": float(row["lon"]),
            }
            for key in {row["name"].casefold(), row["ascii_name"].casefold()}:
                cities.setdefault(key, city)
    return cities


CITIES = load_cities()

# MET Norway asks clients not to fetch a forecast again before its Expires time.
_cache = {}
_cache_lock = threading.Lock()


def condition_text(symbol_code):
    base = symbol_code.split("_")[0]
    return SYMBOLS.get(base, base)


def feels_like_c(temp_c, humidity, wind_ms):
    """Apparent temperature (Steadman, as used by the Australian Bureau of Meteorology)."""
    vapour_hpa = humidity / 100 * 6.105 * math.exp(17.27 * temp_c / (237.7 + temp_c))
    return temp_c + 0.33 * vapour_hpa - 0.70 * wind_ms - 4.00


def to_f(c):
    return round(c * 9 / 5 + 32, 1)


def fetch_forecast(lat, lon, contact):
    key = (lat, lon)
    now = time.time()
    with _cache_lock:
        cached = _cache.get(key)
        if cached and cached[0] > now:
            return cached[1]
    response = requests.get(
        MET_URL,
        params={"lat": f"{lat:.4f}", "lon": f"{lon:.4f}"},
        headers={"User-Agent": f"weatherapp/{VERSION} {contact}"},
        timeout=10,
    )
    if response.status_code == 203:
        app.logger.warning("MET Norway marks this API version as deprecated (HTTP 203)")
    response.raise_for_status()
    data = response.json()
    expires = now + 600
    if "Expires" in response.headers:
        try:
            expires = parsedate_to_datetime(response.headers["Expires"]).timestamp()
        except (TypeError, ValueError):
            pass
    with _cache_lock:
        _cache[key] = (expires, data)
    return data


@app.route("/")
def health():
    return "The service is running", 200


@app.route("/<city>")
def weather(city):
    contact = os.getenv("WEATHER_CONTACT", "").strip()
    if not contact:
        return jsonify(error="The weather service has no contact address (WEATHER_CONTACT is not set)"), 503
    place = CITIES.get(city.strip().casefold())
    if place is None:
        return jsonify(error="No matching location found"), 404
    try:
        forecast = fetch_forecast(place["lat"], place["lon"], contact)
    except requests.HTTPError as exc:
        status = exc.response.status_code if exc.response is not None else None
        app.logger.warning("MET Norway returned %s", status)
        if status == 403:
            return jsonify(error="The weather provider refused the request (check WEATHER_CONTACT)"), 502
        return jsonify(error="The weather provider returned an error"), 502
    except requests.RequestException as exc:
        app.logger.warning("MET Norway request failed: %s", exc)
        return jsonify(error="The weather provider could not be reached"), 504

    try:
        now = forecast["properties"]["timeseries"][0]
        details = now["data"]["instant"]["details"]
        symbol = now["data"]["next_1_hours"]["summary"]["symbol_code"]
    except (KeyError, IndexError, TypeError):
        return jsonify(error="The weather provider returned an unexpected answer"), 502

    temp_c = details["air_temperature"]
    feels_c = feels_like_c(temp_c, details["relative_humidity"], details["wind_speed"])
    return jsonify(
        location={"name": place["name"], "country": place["country"], "lat": place["lat"], "lon": place["lon"]},
        current={
            "time": now["time"],
            "temp_c": round(temp_c, 1),
            "temp_f": to_f(temp_c),
            "feelslike_c": round(feels_c, 1),
            "feelslike_f": to_f(feels_c),
            "humidity": round(details["relative_humidity"]),
            "wind_kph": round(details["wind_speed"] * 3.6, 1),
            "condition": {"text": condition_text(symbol), "code": symbol, "icon": f"/weather-icons/{symbol}.svg"},
        },
        source=ATTRIBUTION,
    )


if __name__ == '__main__':
    app.run(host="0.0.0.0")
