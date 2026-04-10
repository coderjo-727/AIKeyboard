#!/usr/bin/env python3
"""
Minimal development relay for AI Keyboard correction requests.

This keeps the OpenAI API key off the client. It is intentionally small and
uses only Python's standard library so it can run locally without extra
dependencies.
"""

from http.server import BaseHTTPRequestHandler, HTTPServer
import json
import os
import urllib.error
import urllib.request


OPENAI_ENDPOINT = "https://api.openai.com/v1/responses"
MODEL = os.environ.get("AIKEYBOARD_OPENAI_MODEL", "gpt-5.4-mini")
OPENAI_API_KEY = os.environ.get("OPENAI_API_KEY", "")
RELAY_AUTH_TOKEN = os.environ.get("AIKEYBOARD_RELAY_TOKEN", "")
PORT = int(os.environ.get("AIKEYBOARD_RELAY_PORT", "8787"))


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


class RelayHandler(BaseHTTPRequestHandler):
    def do_POST(self):
        if self.path != "/v1/corrections":
            self.respond(404, {"error": "not_found"})
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

        content_length = int(self.headers.get("Content-Length", "0"))
        raw_body = self.rfile.read(content_length)

        try:
            payload = json.loads(raw_body.decode("utf-8"))
        except json.JSONDecodeError:
            self.respond(400, {"error": "invalid_json"})
            return

        sentence = str(payload.get("sentence", "")).strip()
        should_add_terminal_punctuation = bool(payload.get("shouldAddTerminalPunctuation", False))

        if not sentence:
            self.respond(400, {"error": "missing_sentence"})
            return

        upstream_payload = {
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
            with urllib.request.urlopen(request) as response:
                response_payload = json.loads(response.read().decode("utf-8"))
        except urllib.error.HTTPError as error:
            body = error.read().decode("utf-8", errors="replace")
            self.respond(error.code, {"error": "openai_request_failed", "details": body})
            return
        except urllib.error.URLError as error:
            self.respond(502, {"error": "openai_unreachable", "details": str(error)})
            return

        output_text = extract_output_text(response_payload)
        if not output_text:
            self.respond(502, {"error": "missing_output_text"})
            return

        try:
            result = json.loads(output_text)
        except json.JSONDecodeError:
            self.respond(502, {"error": "invalid_model_json", "details": output_text})
            return

        self.respond(
            200,
            {
                "corrected": result.get("corrected"),
                "confidence": result.get("confidence", 0.9),
            },
        )

    def log_message(self, format, *args):
        return

    def respond(self, status_code, payload):
        body = json.dumps(payload).encode("utf-8")
        self.send_response(status_code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)


def extract_output_text(payload):
    for item in payload.get("output", []):
        for content in item.get("content", []):
            if content.get("type") == "output_text":
                return content.get("text")
    return None


def main():
    server = HTTPServer(("127.0.0.1", PORT), RelayHandler)
    print(f"AI Keyboard relay listening on http://127.0.0.1:{PORT}/v1/corrections")
    server.serve_forever()


if __name__ == "__main__":
    main()
