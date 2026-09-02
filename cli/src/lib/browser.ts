import { execFile } from "node:child_process";

// Best-effort "open this URL in the default browser". Never throws — if it
// fails, the caller has already printed the URL for the user to open manually.
export async function openBrowser(url: string): Promise<void> {
  const [command, args] =
    process.platform === "darwin"
      ? ["open", [url]]
      : process.platform === "win32"
        ? ["cmd", ["/c", "start", "", url]]
        : ["xdg-open", [url]];

  await new Promise<void>((resolve) => {
    const child = execFile(command as string, args as string[], () => resolve());
    child.on("error", () => resolve());
  });
}
