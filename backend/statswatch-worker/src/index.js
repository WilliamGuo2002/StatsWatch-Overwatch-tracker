// StatsWatch backend: Battle.net sign-in relay and feedback mailer.
// The app only ever receives the BattleTag; secrets, tokens and the feedback address stay here.

const AUTHORIZE_URL = "https://oauth.battle.net/authorize";
const TOKEN_URL = "https://oauth.battle.net/token";
const USERINFO_URL = "https://oauth.battle.net/userinfo";
const APP_CALLBACK = "statswatch://auth";

function appRedirect(params) {
  const url = new URL(APP_CALLBACK);
  for (const [key, value] of Object.entries(params)) {
    if (value) url.searchParams.set(key, value);
  }
  return Response.redirect(url.toString(), 302);
}

async function handleLogin(request, env) {
  const state = new URL(request.url).searchParams.get("state");
  if (!state || !/^[A-Za-z0-9-]{16,64}$/.test(state)) {
    return new Response("Missing or invalid state", { status: 400 });
  }
  const url = new URL(AUTHORIZE_URL);
  url.searchParams.set("response_type", "code");
  url.searchParams.set("client_id", env.BNET_CLIENT_ID);
  url.searchParams.set("redirect_uri", env.REDIRECT_URI);
  url.searchParams.set("scope", "openid");
  url.searchParams.set("state", state);
  return Response.redirect(url.toString(), 302);
}

async function handleCallback(request, env) {
  const params = new URL(request.url).searchParams;
  const state = params.get("state");
  const code = params.get("code");
  if (params.get("error") || !code) {
    return appRedirect({ error: params.get("error") || "missing_code", state });
  }

  const tokenResponse = await fetch(TOKEN_URL, {
    method: "POST",
    headers: {
      Authorization: "Basic " + btoa(`${env.BNET_CLIENT_ID}:${env.BNET_CLIENT_SECRET}`),
      "Content-Type": "application/x-www-form-urlencoded",
    },
    body: new URLSearchParams({
      grant_type: "authorization_code",
      code,
      redirect_uri: env.REDIRECT_URI,
    }),
  });
  if (!tokenResponse.ok) {
    return appRedirect({ error: "token_exchange_failed", state });
  }
  const { access_token: accessToken } = await tokenResponse.json();

  const userResponse = await fetch(USERINFO_URL, {
    headers: { Authorization: `Bearer ${accessToken}` },
  });
  if (!userResponse.ok) {
    return appRedirect({ error: "userinfo_failed", state });
  }
  const { battletag: battleTag } = await userResponse.json();
  if (!battleTag) {
    return appRedirect({ error: "no_battletag", state });
  }
  return appRedirect({ battletag: battleTag, state });
}

const FEEDBACK_CATEGORIES = {
  general: "General Feedback",
  bug: "Bug Report",
  feature: "Feature Request",
};

function json(body, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

function clean(value, maxLength) {
  return typeof value === "string" ? value.trim().slice(0, maxLength) : "";
}

async function handleFeedback(request, env) {
  if (request.method !== "POST") return json({ error: "method_not_allowed" }, 405);

  if (env.FEEDBACK_LIMITER) {
    const ip = request.headers.get("CF-Connecting-IP") || "unknown";
    const { success } = await env.FEEDBACK_LIMITER.limit({ key: ip });
    if (!success) return json({ error: "rate_limited" }, 429);
  }

  let payload;
  try {
    payload = await request.json();
  } catch {
    return json({ error: "invalid_json" }, 400);
  }

  const categoryName = FEEDBACK_CATEGORIES[payload.category];
  const message = clean(payload.message, 4000);
  if (!categoryName || message.length < 5) return json({ error: "invalid_feedback" }, 400);

  const contact = clean(payload.contact, 200);
  const device = payload.device && typeof payload.device === "object" ? payload.device : null;
  const appVersion = clean(device?.appVersion, 40);

  // Subjects follow one fixed format per category; the client cannot set them.
  const snippet = message.split("\n")[0].slice(0, 50);
  const subject = `[StatsWatch][${categoryName}]${appVersion ? ` v${appVersion}` : ""} - ${snippet}`;

  const lines = [
    `Category: ${categoryName}`,
    `Reply to: ${contact || "(not provided)"}`,
    `Received: ${new Date().toISOString()}`,
    "",
    message,
  ];
  if (device) {
    lines.push(
      "",
      "--- Device Info ---",
      `App: ${appVersion} (${clean(device.build, 20)})`,
      `iOS: ${clean(device.iosVersion, 20)}`,
      `Device: ${clean(device.model, 40)}`,
      `Language: ${clean(device.language, 20)}`,
    );
  }

  const emailBody = {
    from: env.FEEDBACK_FROM || "StatsWatch Feedback <onboarding@resend.dev>",
    to: [env.FEEDBACK_TO],
    subject,
    text: lines.join("\n"),
  };
  if (/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(contact)) emailBody.reply_to = contact;

  const sendResponse = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${env.RESEND_API_KEY}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(emailBody),
  });
  if (!sendResponse.ok) return json({ error: "send_failed" }, 502);
  return json({ ok: true });
}

export default {
  async fetch(request, env) {
    const { pathname } = new URL(request.url);
    if (pathname === "/login") return handleLogin(request, env);
    if (pathname === "/callback") return handleCallback(request, env);
    if (pathname === "/feedback") return handleFeedback(request, env);
    return new Response("Not found", { status: 404 });
  },
};
