// Shipped helper for typed interpolation params (i18next can't infer them).
// Usage: const tt = createTypedT<TranslationParams>(i18next.t); tt("k", { name }).

// Map of fully-qualified key -> its required interpolation params.
export type ParamsMap = Record<string, Record<string, unknown>>;

// i18next `t` shape. key/options are `any` on purpose: TFunction's literal-union
// key would be rejected by a stricter signature (contravariance). TypedT restores safety.
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
