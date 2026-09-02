// Diagnostic logging, off by default. Enabled by --verbose, LB_DEBUG=1, or a
// DEBUG list containing "lb" (the node ecosystem convention).
let enabled =
  process.env.LB_DEBUG === "1" ||
  (process.env.DEBUG ?? "").split(",").some((part) => part.trim() === "lb" || part.trim() === "lb:*");

export function enableDebug(): void {
  enabled = true;
}

export function debug(message: string): void {
  if (enabled) console.error(`lb:debug ${message}`);
}
