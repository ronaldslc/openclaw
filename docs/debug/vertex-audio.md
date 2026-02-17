---
summary: "Audio transcription via Google Vertex AI and debugging media understanding failures"
read_when:
  - Configuring Google Vertex AI for audio/video/image understanding
  - Debugging silent media understanding failures
  - Troubleshooting voice note transcription
title: "Vertex AI Audio & Media Debugging"
---

# Vertex AI Audio & Media Debugging

## Audio transcription with Google Vertex AI

OpenClaw supports audio transcription (voice notes), video description, and image
description via Google Vertex AI using Gemini models.

### How it works

When `provider: "google-vertex"` is configured for media understanding, OpenClaw
uses the [pi-ai](https://github.com/nicedoc/pi-ai) SDK's `completeSimple` function.
This sends the media as inline data to the Gemini API through Vertex AI, with
authentication handled automatically via Application Default Credentials (ADC).

The pi-ai SDK:

1. Creates a `GoogleGenAI` client with `vertexai: true`
2. Resolves project/location from `GOOGLE_CLOUD_PROJECT` and `GOOGLE_CLOUD_LOCATION`
3. Handles OAuth2 token acquisition internally (no manual token management)
4. Sends the media buffer as `inlineData` with the original MIME type

### Prerequisites

- A Google Cloud project with the Vertex AI API enabled
- A service account key or ADC configured:
  - Set `GOOGLE_APPLICATION_CREDENTIALS` to the path of your service account JSON key
  - Or run `gcloud auth application-default login` on the host
- Environment variables:
  - `GOOGLE_CLOUD_PROJECT` — your GCP project ID
  - `GOOGLE_CLOUD_LOCATION` — region (e.g., `global`, `us-central1`)

### Configuration

Add to `~/.openclaw/openclaw.json`:

```json5
{
  tools: {
    media: {
      audio: {
        enabled: true,
      },
    },
  },
}
```

If your agent's primary model is already set to `google-vertex` (e.g.,
`google-vertex/gemini-3-flash-preview`), you **do not** need to specify a
`models` array. The media pipeline auto-resolves the provider from the agent's
primary model when no explicit models are configured.

To override the auto-resolved model, you can specify one explicitly:

```json5
{
  tools: {
    media: {
      audio: {
        enabled: true,
        models: [
          { provider: "google-vertex", model: "gemini-3-flash-preview" },
        ],
      },
    },
  },
}
```

For video and image understanding, configure similarly under `tools.media.video`
and `tools.media.image`.

### Auth profile

Register the Vertex auth profile:

```json5
{
  auth: {
    profiles: {
      "google-vertex:default": {
        provider: "google-vertex",
        mode: "api_key",
      },
    },
  },
}
```

The `api_key` mode for `google-vertex` uses ADC internally — the API key value
itself is a sentinel and is not sent to Google.

### Docker setup

In `docker-compose.yml` or `docker-compose.extra.yml`, mount the service account
key and set environment variables:

```yaml
services:
  openclaw-gateway:
    environment:
      - GOOGLE_CLOUD_PROJECT=your-project-id
      - GOOGLE_CLOUD_LOCATION=us-central1
      - GOOGLE_APPLICATION_CREDENTIALS=/etc/openclaw/vertex-key.json
    volumes:
      - ./path/to/key.json:/etc/openclaw/vertex-key.json:ro
```

## Debugging media understanding

Media understanding errors (audio, video, image) are logged via `logVerbose()`.
By default these only appear when verbose logging is active. If transcription
silently fails with no output, enable debug logging to see what went wrong.

### Enable debug file logging

Set `logging.level` to `debug` in `~/.openclaw/openclaw.json`:

```json
{
  "logging": {
    "level": "debug"
  }
}
```

This writes debug-level entries to the rolling log file
(`/tmp/openclaw/openclaw-YYYY-MM-DD.log`). Tail the logs with:

```bash
openclaw logs --follow
```

Or in Docker:

```bash
docker compose exec openclaw-gateway cat /tmp/openclaw/openclaw-*.log | tail -100
```

### What gets logged at debug level

With `logging.level: "debug"`, the media understanding pipeline logs:

- **Provider selection**: which providers are tried and in what order
- **Skip reasons**: why a provider was skipped (missing key, size limit, timeout)
- **Failures**: the full error message when a provider call fails (HTTP errors,
  auth failures, timeouts)
- **Preflight transcription**: audio-preflight results for mention detection
- **Concurrency tasks**: parallel media task failures

### Logging levels reference

| Level    | File logs | Console (`--verbose`) | Description              |
| -------- | --------- | --------------------- | ------------------------ |
| `silent` | Nothing   | Nothing               | Disable all logging      |
| `fatal`  | Fatal     | No                    | Unrecoverable errors     |
| `error`  | Errors+   | No                    | Errors and above         |
| `warn`   | Warnings+ | No                    | Warnings and above       |
| `info`   | Info+     | No                    | Default level            |
| `debug`  | Debug+    | Yes (if `--verbose`)  | Verbose pipeline details |
| `trace`  | All       | Yes (if `--verbose`)  | Maximum detail           |

**Key distinction**: `logging.level` controls what goes to the **file log**.
The CLI `--verbose` flag controls what prints to **console**. Setting
`logging.level: "debug"` captures media errors in log files without flooding
the console.

### Common failure patterns

| Symptom                    | Likely cause                        | Fix                                                         |
| -------------------------- | ----------------------------------- | ----------------------------------------------------------- |
| No transcription, no error | `logging.level` is `info` (default) | Set to `debug` to see errors                                |
| `HTTP 401` in debug logs   | Invalid or expired credentials      | Check `GOOGLE_APPLICATION_CREDENTIALS` path and permissions |
| `HTTP 403`                 | Vertex AI API not enabled           | Enable the API in Google Cloud Console                      |
| `timeout` in debug logs    | Model or network too slow           | Increase `timeoutSeconds` in model config                   |
| `maxBytes` skip            | Audio file too large                | Increase `tools.media.audio.maxBytes`                       |
