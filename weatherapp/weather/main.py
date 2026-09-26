from flask import Flask, jsonify
from flask_cors import CORS
import requests
import os

app = Flask(__name__)
CORS(app)

# WeatherAPI.com, called directly (2021 went through the RapidAPI resale endpoint).
WEATHER_API_URL = "https://api.weatherapi.com/v1/current.json"


@app.route("/")
def health():
    return "The service is running", 200


@app.route('/<city>')
def hello(city):
    api_key = os.getenv("WEATHER_API_KEY", "")
    if not api_key:
        return jsonify(error="The weather service has no API key (WEATHER_API_KEY is not set)"), 503
    try:
        response = requests.get(WEATHER_API_URL, params={"key": api_key, "q": city}, timeout=10)
    except requests.RequestException as exc:
        app.logger.warning("WeatherAPI.com request failed: %s", exc)
        return jsonify(error="The weather provider could not be reached"), 504
    if response.ok:
        return jsonify(response.json())
    # WeatherAPI.com answers errors as {"error": {"code": ..., "message": ...}}
    try:
        detail = response.json().get("error", {})
    except ValueError:
        detail = {}
    app.logger.warning("WeatherAPI.com returned %s: %s", response.status_code, detail)
    if response.status_code in (401, 403):
        return jsonify(error="The weather provider rejected the API key"), 502
    if response.status_code == 400:
        return jsonify(error=detail.get("message", "No matching location found")), 404
    return jsonify(error="The weather provider returned an error"), 502


if __name__ == '__main__':
    app.run(host="0.0.0.0")
