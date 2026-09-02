import { randomBytes } from "node:crypto";
import { createServer } from "node:http";
import { hostname } from "node:os";
import { exchangeCode } from "../lib/api.js";
import { openBrowser } from "../lib/browser.js";
import type { ServerConfig } from "../lib/config.js";
import { saveToken } from "../lib/credentials.js";

const TIMEOUT_MS = 120_000;

export interface LoginResult {
  url: string;
  user?: string;
}

// Loopback device flow: spin up a throwaway server on 127.0.0.1, send the user
// to the platform's authorize page, and wait for it to redirect back with a
// one-time code. The code is exchanged for a token (server-side) and stored.
export async function login(server: ServerConfig, deviceName?: string): Promise<LoginResult> {
  const state = randomBytes(16).toString("hex");
  const name = deviceName?.trim() || hostname();
  const loopback = await startLoopback(state);

  const authorizeUrl = new URL("/cli/authorize", server.url);
  authorizeUrl.searchParams.set("redirect_uri", `http://127.0.0.1:${loopback.port}/callback`);
  authorizeUrl.searchParams.set("state", state);
  authorizeUrl.searchParams.set("name", name);

  console.error(`Opening your browser to authorize:\n  ${authorizeUrl}\n`);
  await openBrowser(authorizeUrl.toString());

  let code: string;
  try {
    code = await loopback.waitForCode;
  } finally {
    loopback.close();
  }

  const { token, user } = await exchangeCode(server.url, code);
  await saveToken(server.url, { token, user: user?.email });
  return { url: server.url, user: user?.email };
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

    const timer = setTimeout(() => rejectCode(new Error("Timed out waiting for browser authorization.")), TIMEOUT_MS);
    timer.unref?.();

    const httpServer = createServer((req, res) => {
      const url = new URL(req.url ?? "/", "http://127.0.0.1");
      if (url.pathname !== "/callback") {
        res.writeHead(404).end();
        return;
      }

      const code = url.searchParams.get("code");
      const state = url.searchParams.get("state");
      if (!code || state !== expectedState) {
        res.writeHead(400, { "content-type": "text/html" }).end("<h1>Login failed</h1><p>Bad state — close this tab and retry <code>lb login</code>.</p>");
        clearTimeout(timer);
        rejectCode(new Error("State mismatch on login callback."));
        return;
      }

      res.writeHead(200, { "content-type": "text/html" }).end("<h1>Authorized</h1><p>You can close this tab and return to the terminal.</p>");
      clearTimeout(timer);
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
