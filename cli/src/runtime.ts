// Runtime helper shipped with the package so consumers get typed interpolation
// params — something i18next's own types cannot infer from string values.
//
// Usage in a consumer app:
//
//   import i18next from "i18next";
//   import { createTypedT } from "@language-bridge/cli/runtime";
//   import type { TranslationParams } from "./@types/resources";
//
//   const tt = createTypedT<TranslationParams>(i18next.t);
//   tt("common:common.welcome", { name: "Ada" }); // params required + typed
//   tt("auth:auth.signin");                        // no params -> no 2nd arg
//
// The generated `TranslationParams` interface (from `lb sync`) is the type
// argument; this helper stays generic so it has no build-time dependency on it.

// Map of fully-qualified key -> its required interpolation params.
export type ParamsMap = Record<string, Record<string, unknown>>;

// Minimal shape of i18next's `t`. The key/options params are intentionally
// `any`: i18next's real `TFunction` narrows `key` to a literal union, and a
// stricter signature here would (by parameter contravariance) reject it. Safety
// is restored on the returned TypedT, which is fully generic over M.
export type TranslateFn = (key: any, options?: any) => string;

// A key requires an argument unless its params object is empty (Record<string, never>).
type HasNoParams<P> = keyof P extends never ? true : false;

export type TypedT<M extends ParamsMap> = <K extends keyof M & string>(
  key: K,
  ...args: HasNoParams<M[K]> extends true ? [] : [params: M[K]]
) => string;

// Wrap an i18next `t` so keys are constrained to M and params are enforced.
export function createTypedT<M extends ParamsMap>(t: TranslateFn): TypedT<M> {
  return ((key, ...args) => t(key, args[0] as Record<string, unknown> | undefined)) as TypedT<M>;
}
