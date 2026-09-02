import type { ServerConfig } from "../lib/config.js";
import { removeToken } from "../lib/credentials.js";

// Forget the stored token for this server. Returns false when none was stored.
export async function logout(server: ServerConfig): Promise<boolean> {
  return removeToken(server.url);
}
