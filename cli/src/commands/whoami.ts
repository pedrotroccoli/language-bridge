import { fetchUser } from "../lib/api.js";
import type { ServerConfig } from "../lib/config.js";
import type { WhoamiResponse } from "../lib/types.js";

// Show who the active token belongs to and which projects it can reach.
export async function whoami(server: ServerConfig): Promise<WhoamiResponse> {
  if (!server.token) throw new Error("Not logged in. Run `lb login`.");
  return fetchUser(server.url, server.token);
}
