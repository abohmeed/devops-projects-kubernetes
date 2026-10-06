"""Tests for the weather service. MET Norway is never called: requests.get is replaced.

Run with: pip install -r requirements.txt -r requirements-dev.txt && pytest
"""

from unittest import mock

import pytest
import requests

import main


def met_answer(status=200, symbol="partlycloudy_day", temp=16.4, expires="Tue, 06 Oct 2026 11:33:11 GMT"):
    response = mock.Mock(status_code=status, headers={"Expires": expires})
    response.json.return_value = {
        "properties": {
            "timeseries": [
                {
                    "time": "2026-10-06T11:00:00Z",
                    "data": {
                        "instant": {"details": {"air_temperature": temp, "relative_humidity": 80.0, "wind_speed": 2.0}},
                        "next_1_hours": {"summary": {"symbol_code": symbol}},
                    },
                }
            ]
        }
    }
    if status >= 400:
        response.raise_for_status.side_effect = requests.HTTPError(response=response)
    else:
        response.raise_for_status.return_value = None
    return response


@pytest.fixture
def client(monkeypatch):
    monkeypatch.setenv("WEATHER_CONTACT", "student@example.com")
    main._cache.clear()
    return main.app.test_client()


def test_health(client):
    assert client.get("/").status_code == 200


def test_no_contact_is_503(client, monkeypatch):
    monkeypatch.delenv("WEATHER_CONTACT")
    r = client.get("/London")
    assert r.status_code == 503
    assert "WEATHER_CONTACT" in r.get_json()["error"]


def test_unknown_city_is_404(client):
    with mock.patch("main.requests.get") as get:
        r = client.get("/Atlantisville")
    assert r.status_code == 404
    get.assert_not_called()


def test_london_is_the_biggest_london(client):
    with mock.patch("main.requests.get", return_value=met_answer()) as get:
        r = client.get("/london")
    assert r.status_code == 200
    body = r.get_json()
    assert body["location"]["name"] == "London"
    assert body["location"]["country"] == "United Kingdom"
    assert body["current"]["temp_c"] == 16.4
    assert body["current"]["temp_f"] == 61.5
    assert body["current"]["condition"]["text"] == "Partly cloudy"
    assert body["current"]["condition"]["icon"] == "/weather-icons/partlycloudy_day.svg"
    assert "MET Norway" in body["source"]
    params = get.call_args.kwargs["params"]
    assert params == {"lat": "51.5085", "lon": "-0.1257"}
    assert get.call_args.kwargs["headers"]["User-Agent"] == "weatherapp/3.0.0 student@example.com"


def test_ascii_name_matches(client):
    with mock.patch("main.requests.get", return_value=met_answer()):
        r = client.get("/Sao Paulo")
    assert r.get_json()["location"]["name"] == "São Paulo"


def test_forecast_is_cached_until_expires(client):
    far_future = "Fri, 01 Jan 2100 00:00:00 GMT"
    with mock.patch("main.requests.get", return_value=met_answer(expires=far_future)) as get:
        client.get("/Cairo")
        client.get("/Cairo")
    assert get.call_count == 1


def test_provider_refusal_is_502(client):
    with mock.patch("main.requests.get", return_value=met_answer(status=403)):
        r = client.get("/Cairo")
    assert r.status_code == 502
    assert "WEATHER_CONTACT" in r.get_json()["error"]


def test_provider_unreachable_is_504(client):
    with mock.patch("main.requests.get", side_effect=requests.ConnectionError("down")):
        r = client.get("/Cairo")
    assert r.status_code == 504


def test_every_symbol_has_text():
    for code in ["clearsky_day", "clearsky_night", "rainshowers_polartwilight", "fog", "heavysnowandthunder"]:
        assert main.condition_text(code)[0].isupper()


def test_feels_like_is_plausible():
    assert 10 < main.feels_like_c(16.4, 80, 2.0) < 20
