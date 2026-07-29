// Interpolation-variable extraction, mirroring the server's QA regex
// (app/models/translation/qa.rb PLACEHOLDER). Three dialects coexist in
// Language Bridge values:
//
//   i18next double-brace : "Hi {{name}}"        -> name
//   single-brace         : "Hi {name}"          -> name
//   Rails percent-brace  : "Hi %{name}"         -> name
//
// i18next extras we normalise away so the variable name is clean:
//   formatting  : "{{count, number}}"           -> count
//   unescaped   : "{{- html}}"                  -> html
//   nesting/ctx : "{{val, currency}}"           -> val   (never "$t(...)" — see below)
const PLACEHOLDER = /\{\{[^}]+\}\}|\{[^}]+\}|%\{[^}]+\}/g;

// Strip the surrounding delimiters of a single matched token.
function unwrap(token: string): string {
  if (token.startsWith("{{")) return token.slice(2, -2);
  if (token.startsWith("%{")) return token.slice(2, -1);
  return token.slice(1, -1); // {x}
}

// Reduce a raw token body to its variable name, dropping i18next formatting
// (`, number`), the unescape marker (`- `), and surrounding whitespace.
function variableName(body: string): string {
  return body
    .split(/[,|]/)[0]! // formatting / options after a comma or pipe
    .replace(/\s+/g, "")
    .replace(/^-/, ""); // "{{- name}}" unescaped marker
}

// i18next nesting references another key rather than a caller-supplied param
// (e.g. "$t(common:foo)"); those must NOT become required params.
function isNestingRef(body: string): boolean {
  return body.trimStart().startsWith("$t(");
}

// Ordered, de-duplicated variable names referenced by an interpolated string.
export function extractParams(value: string): string[] {
  const names = new Set<string>();
  for (const match of value.matchAll(PLACEHOLDER)) {
    const body = unwrap(match[0]);
    if (isNestingRef(body)) continue;
    const name = variableName(body);
    if (name) names.add(name);
  }
  return [...names];
}
