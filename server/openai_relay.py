#!/usr/bin/env python3
"""
Minimal development relay for AI Keyboard correction requests.

This keeps the OpenAI API key off the client. It is intentionally small and
uses only Python's standard library so it can run locally without extra
dependencies.
"""

from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from collections import defaultdict, deque
import json
import os
import threading
import time
import urllib.error
import urllib.request
from urllib.parse import urlparse


OPENAI_ENDPOINT = "https://api.openai.com/v1/responses"
MODEL = os.environ.get("AIKEYBOARD_OPENAI_MODEL", "gpt-5.4-mini")
OPENAI_API_KEY = os.environ.get("OPENAI_API_KEY", "")
RELAY_AUTH_TOKEN = os.environ.get("AIKEYBOARD_RELAY_TOKEN", "")
PORT = int(os.environ.get("AIKEYBOARD_RELAY_PORT", "8787"))
HOST = os.environ.get("AIKEYBOARD_RELAY_HOST", "127.0.0.1")
UPSTREAM_TIMEOUT_SECONDS = float(os.environ.get("AIKEYBOARD_OPENAI_TIMEOUT", "20"))
MAX_BODY_BYTES = int(os.environ.get("AIKEYBOARD_MAX_BODY_BYTES", "4096"))
MAX_SENTENCE_CHARS = int(os.environ.get("AIKEYBOARD_MAX_SENTENCE_CHARS", "800"))
RATE_LIMIT_PER_MINUTE = int(os.environ.get("AIKEYBOARD_RATE_LIMIT_PER_MINUTE", "60"))


SCHEMA = {
    "type": "object",
    "additionalProperties": False,
    "properties": {
        "corrected": {
            "anyOf": [
                {"type": "string"},
                {"type": "null"},
            ]
        },
        "confidence": {
            "type": "number",
            "minimum": 0,
            "maximum": 1,
        },
    },
    "required": ["corrected", "confidence"],
}


class RateLimiter:
    def __init__(self, limit, window_seconds=60):
        self.limit = limit
        self.window_seconds = window_seconds
        self._events = defaultdict(deque)
        self._lock = threading.Lock()

    def allow(self, key):
        if self.limit <= 0:
            return True

        now = time.monotonic()
        cutoff = now - self.window_seconds

        with self._lock:
            events = self._events[key]
            while events and events[0] < cutoff:
                events.popleft()

            if len(events) >= self.limit:
                return False

            events.append(now)
            return True


RATE_LIMITER = RateLimiter(RATE_LIMIT_PER_MINUTE)


class RelayHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        path = urlparse(self.path).path
        if path == "/healthz":
            self.respond(
                200,
                {
                    "ok": True,
                    "model": MODEL,
                    "hasOpenAIKey": bool(OPENAI_API_KEY),
                },
            )
            return

        self.respond(404, {"error": "not_found"})

    def do_POST(self):
        path = urlparse(self.path).path
        if path != "/v1/corrections":
            self.respond(404, {"error": "not_found"})
            return

        if not RATE_LIMITER.allow(self.rate_limit_key()):
            self.respond(429, {"error": "rate_limited"})
            return

        if RELAY_AUTH_TOKEN:
            auth_header = self.headers.get("Authorization", "")
            expected = f"Bearer {RELAY_AUTH_TOKEN}"
            if auth_header != expected:
                self.respond(401, {"error": "unauthorized"})
                return

        if not OPENAI_API_KEY:
            self.respond(500, {"error": "missing_openai_api_key"})
            return

        content_length = self.content_length()
        if content_length is None:
            self.respond(411, {"error": "missing_content_length"})
            return

        if content_length > MAX_BODY_BYTES:
            self.respond(413, {"error": "request_too_large"})
            return

        raw_body = self.rfile.read(content_length)

        try:
            payload = json.loads(raw_body.decode("utf-8"))
        except json.JSONDecodeError:
            self.respond(400, {"error": "invalid_json"})
            return

        sentence = sanitize_sentence(payload.get("sentence", ""))
        should_add_terminal_punctuation = bool(payload.get("shouldAddTerminalPunctuation", False))

        if not sentence:
            self.respond(400, {"error": "missing_sentence"})
            return

        if len(sentence) > MAX_SENTENCE_CHARS:
            self.respond(422, {"error": "sentence_too_long"})
            return

        upstream_payload = build_upstream_payload(
            sentence=sentence,
            should_add_terminal_punctuation=should_add_terminal_punctuation,
        )

        try:
            request = urllib.request.Request(
                OPENAI_ENDPOINT,
                data=json.dumps(upstream_payload).encode("utf-8"),
                headers={
                    "Content-Type": "application/json",
                    "Authorization": f"Bearer {OPENAI_API_KEY}",
                },
                method="POST",
            )
            with urllib.request.urlopen(request, timeout=UPSTREAM_TIMEOUT_SECONDS) as response:
                response_payload = json.loads(response.read().decode("utf-8"))
        except urllib.error.HTTPError as error:
            self.respond(error.code, {"error": "openai_request_failed"})
            return
        except urllib.error.URLError as error:
            self.respond(502, {"error": "openai_unreachable", "details": str(error)})
            return
        except TimeoutError:
            self.respond(504, {"error": "openai_timeout"})
            return

        result = parse_model_output(response_payload)
        if result is None:
            self.respond(502, {"error": "invalid_model_output"})
            return

        self.respond(
            200,
            {
                "corrected": result.get("corrected"),
                "confidence": clamp_confidence(result.get("confidence", 0.9)),
            },
        )

    def log_message(self, format, *args):
        return

    def respond(self, status_code, payload):
        body = json.dumps(payload).encode("utf-8")
        self.send_response(status_code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)

    def content_length(self):
        try:
            return int(self.headers.get("Content-Length", ""))
        except ValueError:
            return None

    def rate_limit_key(self):
        auth_header = self.headers.get("Authorization", "")
        if auth_header:
            return auth_header

        forwarded_for = self.headers.get("X-Forwarded-For", "")
        if forwarded_for:
            return forwarded_for.split(",")[0].strip()

        return self.client_address[0]


def sanitize_sentence(value):
    return str(value).replace("\x00", "").strip()


def build_upstream_payload(sentence, should_add_terminal_punctuation):
    return {
        "model": MODEL,
        "input": [
            {
                "role": "system",
                "content": [
                    {
                        "type": "input_text",
                        "text": (
                            "You are a conservative writing-correction engine for an iOS keyboard. "
                            "Only suggest spelling, grammar, and terminal punctuation fixes. "
                            "Preserve slang, tone, and phrasing whenever possible. "
                            "Return null when the sentence should be left unchanged."
                        ),
                    }
                ],
            },
            {
                "role": "user",
                "content": [
                    {
                        "type": "input_text",
                        "text": (
                            f"Sentence: {sentence}\n"
                            f"Add terminal punctuation if context says it is complete: "
                            f"{'yes' if should_add_terminal_punctuation else 'no'}"
                        ),
                    }
                ],
            },
        ],
        "text": {
            "format": {
                "type": "json_schema",
                "name": "correction_result",
                "strict": True,
                "schema": SCHEMA,
            }
        },
    }


def extract_output_text(payload):
    for item in payload.get("output", []):
        for content in item.get("content", []):
            if content.get("type") == "output_text":
                return content.get("text")
    return None


def parse_model_output(payload):
    output_text = extract_output_text(payload)
    if not output_text:
        return None

    try:
        result = json.loads(output_text)
    except json.JSONDecodeError:
        return None

    corrected = result.get("corrected")
    if corrected is not None:
        corrected = sanitize_sentence(corrected)
        result["corrected"] = corrected or None

    result["confidence"] = clamp_confidence(result.get("confidence", 0.9))
    return result


def clamp_confidence(value):
    try:
        number = float(value)
    except (TypeError, ValueError):
        return 0.9

    return min(max(number, 0.0), 1.0)


def main():
    server = ThreadingHTTPServer((HOST, PORT), RelayHandler)
    print(f"AI Keyboard relay listening on http://{HOST}:{PORT}/v1/corrections")
    server.serve_forever()


if __name__ == "__main__":
    main()
