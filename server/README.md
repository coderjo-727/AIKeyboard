# AI Keyboard Relay

This folder contains the relay service used to keep OpenAI API keys off the iOS
client. It is intentionally dependency-light: the default relay runs on the
Python standard library and can be deployed as a small container.

## Endpoints

- `GET /healthz`
  Returns basic health and configuration status.
- `POST /v1/corrections`
  Accepts:

```json
{
  "sentence": "i has a apple",
  "shouldAddTerminalPunctuation": true
}
```

Returns:

```json
{
  "corrected": "I have an apple.",
  "confidence": 0.96
}
```

## Required Environment

- `OPENAI_API_KEY`
  OpenAI API key. Never put this in the iOS app.
- `AIKEYBOARD_RELAY_TOKEN`
  Optional bearer token expected from the iOS app.

## Optional Environment

- `AIKEYBOARD_RELAY_HOST`, default `127.0.0.1`
- `AIKEYBOARD_RELAY_PORT`, default `8787`
- `AIKEYBOARD_OPENAI_MODEL`, default `gpt-5.4-mini`
- `AIKEYBOARD_OPENAI_TIMEOUT`, default `20`
- `AIKEYBOARD_MAX_BODY_BYTES`, default `4096`
- `AIKEYBOARD_MAX_SENTENCE_CHARS`, default `800`
- `AIKEYBOARD_RATE_LIMIT_PER_MINUTE`, default `60`; set `0` to disable

## Run Locally

```bash
export OPENAI_API_KEY="your_openai_api_key"
export AIKEYBOARD_RELAY_TOKEN="choose_a_shared_secret"
python3 server/openai_relay.py
```

## Run With Docker

```bash
docker build -t ai-keyboard-relay server
docker run --rm -p 8787:8787 \
  -e OPENAI_API_KEY="your_openai_api_key" \
  -e AIKEYBOARD_RELAY_TOKEN="choose_a_shared_secret" \
  ai-keyboard-relay
```

## Deployment Notes

Use HTTPS for any deployed relay URL. Plain HTTP should be limited to local
development. The iOS runtime rejects non-local plain HTTP relay endpoints.

For a hosted deployment:

1. Build from `server/Dockerfile`.
2. Set `OPENAI_API_KEY` as a secret environment variable.
3. Set `AIKEYBOARD_RELAY_TOKEN` as a secret environment variable.
4. Point the iOS app at `https://your-relay-host/v1/corrections` using
   `AIKEYBOARD_RELAY_ENDPOINT` or `AIKeyboardRelayEndpoint`.
5. Match the iOS relay token with `AIKEYBOARD_RELAY_TOKEN` or
   `AIKeyboardRelayToken`.
