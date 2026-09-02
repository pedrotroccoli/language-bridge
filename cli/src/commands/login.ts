import { randomBytes } from "node:crypto";
import { createServer } from "node:http";
import { hostname } from "node:os";
import { withTimeout } from "1o1-utils";
import { exchangeCode } from "../lib/api.js";
import { openBrowser } from "../lib/browser.js";
import type { ServerConfig } from "../lib/config.js";
import { saveToken } from "../lib/credentials.js";

const TIMEOUT_MS = 120_000;

// Capabilities `lb login` requests — draft-writing, never admin. The server
// clamps these to the user's role and shows them on the approval page.
const REQUESTED_SCOPES = [ "read", "read_drafts", "write" ];

export interface LoginResult {
  url: string;
  user?: string;
}

// Loopback device flow: spin up a throwaway server on 127.0.0.1, send the user
// to the platform's authorize page, and wait for it to redirect back with a
// one-time code. The code is exchanged for a token (server-side) and stored.
export async function login(server: ServerConfig, deviceName?: string): Promise<LoginResult> {
  // Browser hand-off needs a human at a terminal; in CI (or piped) fail fast
  // with the non-interactive alternative instead of hanging on the loopback.
  if (process.env.CI || !process.stderr.isTTY) {
    throw new Error("`lb login` needs an interactive terminal and a browser. In CI, set LB_TOKEN to a personal access token instead.");
  }

  const state = randomBytes(16).toString("hex");
  const name = deviceName?.trim() || hostname();
  const loopback = await startLoopback(state);

  const authorizeUrl = new URL("/cli/authorize", server.url);
  authorizeUrl.searchParams.set("redirect_uri", `http://127.0.0.1:${loopback.port}/callback`);
  authorizeUrl.searchParams.set("state", state);
  authorizeUrl.searchParams.set("name", name);
  for (const scope of REQUESTED_SCOPES) authorizeUrl.searchParams.append("scopes[]", scope);

  console.error(`Opening your browser to authorize:\n  ${authorizeUrl}\n`);
  await openBrowser(authorizeUrl.toString());

  let code: string;
  try {
    code = await withTimeout({
      promise: loopback.waitForCode,
      ms: TIMEOUT_MS,
      message: "Timed out waiting for browser authorization.",
    });
  } finally {
    loopback.close();
  }

  const { token, user } = await exchangeCode(server.url, code);
  await saveToken(server.url, { token, user: user?.email });
  return { url: server.url, user: user?.email };
}

// Self-contained styled page shown in the browser after the callback — no
// external assets, adapts to light/dark, and tries to close itself.
function resultPage(ok: boolean): string {
  const accent = ok ? "#16a34a" : "#dc2626";
  const glyph = ok ? "&#10003;" : "&#33;";
  const title = ok ? "You're all set" : "Login failed";
  const message = ok
    ? "Language Bridge CLI is authorized. Return to your terminal — you can close this tab."
    : "Something went wrong (state mismatch). Close this tab and run <code>lb login</code> again.";

  return `<!doctype html><html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${title}</title><style>
:root{color-scheme:light dark}
*{box-sizing:border-box}
body{margin:0;min-height:100vh;display:flex;align-items:center;justify-content:center;
  font:15px/1.5 -apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,sans-serif;
  background:#fafafa;color:#18181b}
@media(prefers-color-scheme:dark){body{background:#0b0b0c;color:#f4f4f5}}
.card{text-align:center;padding:40px 44px;max-width:420px}
.badge{width:56px;height:56px;border-radius:16px;display:flex;align-items:center;justify-content:center;
  margin:0 auto 20px;font-size:28px;color:#fff;background:${accent}}
h1{margin:0 0 8px;font-size:20px;font-weight:600;letter-spacing:-.01em}
p{margin:0;color:#71717a;font-size:14px}
code{font-family:ui-monospace,SFMono-Regular,Menlo,monospace;font-size:13px;
  background:rgba(120,120,130,.15);padding:1px 6px;border-radius:5px}
</style></head><body><div class="card">
<div class="badge">${glyph}</div><h1>${title}</h1><p>${message}</p>
</div><script>setTimeout(function(){window.close()},2500)</script></body></html>`;
}

interface Loopback {
  port: number;
  waitForCode: Promise<string>;
  close: () => void;
}

function startLoopback(expectedState: string): Promise<Loopback> {
  return new Promise((resolveServer, rejectServer) => {
    let resolveCode!: (code: string) => void;
    let rejectCode!: (error: Error) => void;
    const waitForCode = new Promise<string>((res, rej) => {
      resolveCode = res;
      rejectCode = rej;
    });

    const httpServer = createServer((req, res) => {
      const url = new URL(req.url ?? "/", "http://127.0.0.1");
      if (url.pathname !== "/callback") {
        res.writeHead(404).end();
        return;
      }

      const code = url.searchParams.get("code");
      const state = url.searchParams.get("state");
      if (!code || state !== expectedState) {
        res.writeHead(400, { "content-type": "text/html; charset=utf-8" }).end(resultPage(false));
        rejectCode(new Error("State mismatch on login callback."));
        return;
      }

      res.writeHead(200, { "content-type": "text/html; charset=utf-8" }).end(resultPage(true));
      resolveCode(code);
    });

    httpServer.on("error", rejectServer);
    httpServer.listen(0, "127.0.0.1", () => {
      const address = httpServer.address();
      const port = typeof address === "object" && address ? address.port : 0;
      resolveServer({ port, waitForCode, close: () => httpServer.close() });
    });
  });
}
