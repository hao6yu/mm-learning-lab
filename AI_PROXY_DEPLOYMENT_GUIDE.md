# AI Proxy Deployment Guide

This app is configured to call AI providers through a backend proxy in production.

## 1) What The Proxy Must Do

Expose these routes:

- `POST /openai/responses`
- `POST /openai/chat/completions` (optional legacy fallback)
- `POST /openai/audio/transcriptions`
- `GET /elevenlabs/voices`
- `POST /elevenlabs/text-to-speech/:voiceId`
- `POST /elevenlabs/text-to-speech/:voiceId/with-timestamps`

Forward requests to provider APIs using server-side secrets:

- OpenAI: `OPENAI_API_KEY`
- ElevenLabs: `ELEVENLABS_API_KEY`

## 2) Required Security Rules

- Never expose provider keys to the client app.
- Require proxy auth token for every request.
- Accept either:
  - `Authorization: Bearer <AI_PROXY_TOKEN>`
  - `X-Proxy-Token: <AI_PROXY_TOKEN>`
- Reject unauthorized requests with `401`.
- Add request timeout and basic rate limiting.
- Disable verbose provider error bodies in production logs.

## 2.1 Quota Context Headers (Recommended)

The app now sends per-request metadata headers that your proxy can enforce:

- `X-Child-Profile-Id`: child profile ID in app DB
- `X-User-Tier`: `free` or `premium`
- `X-AI-Feature`: feature key (examples: `chat_message`, `story_generation`, `voice_call`)
- `X-AI-Units`: consumed units for the request (count-based features)
- `X-AI-Call-Reserve-Seconds`: reserved seconds for a new voice call session

Recommended proxy behavior:

- Validate these headers server-side before calling providers.
- Reject over-limit requests with `429`.
- Keep server-side counters as source of truth in production.

## 3) Cloudflare Workers Quick Deploy (Recommended)

## 3.1 Create Worker

```bash
npm create cloudflare@latest mm-ai-proxy
cd mm-ai-proxy
```

Choose:

- Worker only
- JavaScript or TypeScript

## 3.2 Set Secrets

```bash
npx wrangler secret put AI_PROXY_TOKEN
npx wrangler secret put OPENAI_API_KEY
npx wrangler secret put ELEVENLABS_API_KEY
```

## 3.3 Worker Example (`src/index.ts`)

```ts
export interface Env {
  AI_PROXY_TOKEN: string;
  OPENAI_API_KEY: string;
  ELEVENLABS_API_KEY: string;
}

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json" },
  });

function isAuthorized(req: Request, token: string): boolean {
  const auth = req.headers.get("authorization") || "";
  const bearer = auth.startsWith("Bearer ") ? auth.slice(7) : "";
  const xToken = req.headers.get("x-proxy-token") || "";
  return bearer === token || xToken === token;
}

async function proxyJson(req: Request, url: string, apiKeyHeader: Record<string, string>) {
  const body = await req.text();
  return fetch(url, {
    method: "POST",
    headers: {
      "content-type": "application/json",
      ...apiKeyHeader,
    },
    body,
  });
}

export default {
  async fetch(req: Request, env: Env): Promise<Response> {
    if (!isAuthorized(req, env.AI_PROXY_TOKEN)) {
      return json({ error: "unauthorized" }, 401);
    }

    const url = new URL(req.url);
    const path = url.pathname;

    // OpenAI Responses API
    if (path === "/openai/responses" && req.method === "POST") {
      return proxyJson(req, "https://api.openai.com/v1/responses", {
        authorization: `Bearer ${env.OPENAI_API_KEY}`,
      });
    }

    // OpenAI transcriptions (multipart)
    if (path === "/openai/audio/transcriptions" && req.method === "POST") {
      const formData = await req.formData();
      return fetch("https://api.openai.com/v1/audio/transcriptions", {
        method: "POST",
        headers: {
          authorization: `Bearer ${env.OPENAI_API_KEY}`,
        },
        body: formData,
      });
    }

    // ElevenLabs voices
    if (path === "/elevenlabs/voices" && req.method === "GET") {
      return fetch("https://api.elevenlabs.io/v1/voices", {
        headers: {
          "xi-api-key": env.ELEVENLABS_API_KEY,
          accept: "application/json",
        },
      });
    }

    // ElevenLabs TTS + TTS with timestamps
    if (path.startsWith("/elevenlabs/text-to-speech/")) {
      const segments = path.split("/").filter(Boolean);
      // ["elevenlabs","text-to-speech",":voiceId",("with-timestamps")]
      if (segments.length >= 3 && req.method === "POST") {
        const voiceId = segments[2];
        const suffix = segments[3] === "with-timestamps" ? "/with-timestamps" : "";
        const upstream = `https://api.elevenlabs.io/v1/text-to-speech/${voiceId}${suffix}`;
        const body = await req.text();
        return fetch(upstream, {
          method: "POST",
          headers: {
            "xi-api-key": env.ELEVENLABS_API_KEY,
            "content-type": "application/json",
            accept: suffix ? "application/json" : "audio/mpeg",
          },
          body,
        });
      }
    }

    return json({ error: "not_found" }, 404);
  },
};
```

## 3.4 Deploy

```bash
npx wrangler deploy
```

Save the URL (example: `https://mm-ai-proxy.<subdomain>.workers.dev`).

## 4) Configure The App

Set app `.env`:

```env
AI_PROXY_BASE_URL=https://mm-ai-proxy.<subdomain>.workers.dev
AI_PROXY_TOKEN=your_proxy_token
AI_PROXY_REQUIRED=true
AI_ALLOW_DIRECT_FALLBACK=false
```

For local debug fallback only:

```env
AI_PROXY_REQUIRED=false
AI_ALLOW_DIRECT_FALLBACK=true
OPENAI_API_KEY=...
ELEVENLABS_API_KEY=...
```

## 5) Smoke Test Proxy Before App Release

Run these from terminal:

```bash
export BASE_URL="https://mm-ai-proxy.<subdomain>.workers.dev"
export TOKEN="your_proxy_token"
```

Responses API:

```bash
curl -sS "$BASE_URL/openai/responses" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"model":"gpt-5-nano","input":"Say hi"}'
```

Voices:

```bash
curl -sS "$BASE_URL/elevenlabs/voices" \
  -H "Authorization: Bearer $TOKEN"
```

If both return `200` with valid JSON, app integration is ready.

## 6) Release Checklist

- Deploy proxy.
- Set proxy secrets.
- Update app `.env` for release.
- Keep `AI_PROXY_REQUIRED=true`.
- Keep `AI_ALLOW_DIRECT_FALLBACK=false`.
- Rotate any previously exposed provider keys.
