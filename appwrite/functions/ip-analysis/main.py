from __future__ import annotations

import json
import urllib.parse
from typing import Any

CORS_HEADERS = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type",
}

MAX_CSV_BYTES = 1_000_000
MAX_UNIQUE_IPS = 100


def get_request_attr(req: Any, *names: str, default: Any = None) -> Any:
    for name in names:
        if hasattr(req, name):
            value = getattr(req, name)
            if value is not None:
                return value
    return default


def get_headers(req: Any) -> dict:
    headers = get_request_attr(req, "headers", default={})
    return headers if isinstance(headers, dict) else {}


def get_header(req: Any, name: str) -> str:
    headers = get_headers(req)
    wanted = name.lower()
    for key, value in headers.items():
        if str(key).lower() == wanted:
            return str(value)
    return ""


def get_path(req: Any) -> str:
    path = get_request_attr(req, "path", "pathInfo", default="")
    if not path:
        url = get_request_attr(req, "url", default="")
        path = urllib.parse.urlparse(str(url)).path
    path = str(path or "/")
    if not path.startswith("/"):
        path = f"/{path}"
    if len(path) > 1:
        path = path.rstrip("/")
    return path


def get_method(req: Any) -> str:
    return str(get_request_attr(req, "method", default="GET")).upper()


def read_json_body(req: Any) -> tuple[dict | None, str | None]:
    body_json = get_request_attr(req, "bodyJson", "body_json", default=None)
    if isinstance(body_json, dict):
        return body_json, None

    body_text = get_request_attr(req, "bodyText", "body", default="")
    if isinstance(body_text, bytes):
        body_text = body_text.decode("utf-8")
    body_text = str(body_text or "")
    if not body_text.strip():
        return {}, None

    try:
        payload = json.loads(body_text)
    except json.JSONDecodeError:
        return None, "Invalid JSON body."

    if not isinstance(payload, dict):
        return None, "JSON body must be an object."

    return payload, None


def json_response(context: Any, payload: dict, status_code: int = 200) -> Any:
    try:
        return context.res.json(payload, status_code, CORS_HEADERS)
    except TypeError:
        try:
            return context.res.json(payload, statusCode=status_code, headers=CORS_HEADERS)
        except TypeError:
            try:
                return context.res.json(payload, status_code=status_code, headers=CORS_HEADERS)
            except TypeError:
                payload = dict(payload)
                payload.setdefault("status_code", status_code)
                return context.res.json(payload)


def handle_health() -> tuple[int, dict]:
    return 200, {
        "ok": True,
        "service": "ip-analysis-api",
        "limits": {
            "max_csv_bytes": MAX_CSV_BYTES,
            "max_unique_ips": MAX_UNIQUE_IPS,
        },
        "endpoints": ["GET /health", "POST /analyze-ip", "POST /analyze-ips"],
    }


def handle_analyze_ip(payload: dict) -> tuple[int, dict]:
    from ip_analysis import build_api_response_for_single_ip

    ip = str(payload.get("ip", "")).strip()
    if not ip:
        return 400, {"ok": False, "error": "Field 'ip' is required."}
    return 200, build_api_response_for_single_ip(ip)


def handle_analyze_ips(payload: dict) -> tuple[int, dict]:
    from ip_analysis import build_api_response_for_multiple_ips

    ips = payload.get("ips", [])
    if ips is None:
        ips = []
    if not isinstance(ips, list):
        return 400, {"ok": False, "error": "Field 'ips' must be a list when provided."}

    csv_text = payload.get("csv")
    if csv_text is not None and not isinstance(csv_text, str):
        return 400, {"ok": False, "error": "Field 'csv' must be a string when provided."}

    response = build_api_response_for_multiple_ips(ips, csv_text=csv_text)
    return (200 if response.get("ok") else 400), response


def status_for_exception(error: Exception) -> int:
    name = error.__class__.__name__
    if name in {"PayloadTooLargeError", "TooManyIpsError"}:
        return 413
    if name == "UpstreamRateLimitError":
        return 429
    return 500


def main(context: Any) -> Any:
    req = context.req
    method = get_method(req)
    path = get_path(req)

    if method == "OPTIONS":
        return json_response(context, {"ok": True}, 200)

    try:
        if method == "GET" and path == "/health":
            status, payload = handle_health()
            return json_response(context, payload, status)

        if method != "POST":
            return json_response(context, {"ok": False, "error": "Route not found."}, 404)

        content_type = get_header(req, "content-type").lower()
        if "application/json" not in content_type:
            return json_response(context, {"ok": False, "error": "Content-Type must be application/json."}, 415)

        payload, error = read_json_body(req)
        if error:
            return json_response(context, {"ok": False, "error": error}, 400)
        payload = payload or {}

        if path == "/analyze-ip":
            status, response_payload = handle_analyze_ip(payload)
            return json_response(context, response_payload, status)

        if path == "/analyze-ips":
            status, response_payload = handle_analyze_ips(payload)
            return json_response(context, response_payload, status)

        return json_response(context, {"ok": False, "error": "Route not found."}, 404)
    except Exception as error:
        status_code = status_for_exception(error)
        if status_code != 500:
            payload = {"ok": False, "error": str(error)}
            ttl = getattr(error, "ttl", None)
            if ttl is not None:
                payload["retry_after_seconds"] = ttl
            return json_response(context, payload, status_code)

        context.error(str(error))
        return json_response(context, {"ok": False, "error": "Internal server error."}, 500)
