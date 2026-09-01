import { describe, expect, it } from "vitest";
import { collectParams, emit } from "../src/lib/emit.js";
import type { Namespaces } from "../src/lib/types.js";

const namespaces: Namespaces = {
  common: {
    common: {
      welcome: "Welcome {{name}}",
      save: "Save",
    },
  },
  auth: {
    auth: {
      signin: "Sign in",
    },
  },
};

describe("collectParams", () => {
  it("maps each fully-qualified key to its params", () => {
    const params = collectParams(namespaces);
    expect([...params.get("common:common.welcome")!]).toEqual(["name"]);
    expect([...params.get("common:common.save")!]).toEqual([]);
    expect([...params.get("auth:auth.signin")!]).toEqual([]);
  });

  it("collapses plural variants and adds count", () => {
    const params = collectParams({
      common: { item_one: "{{count}} item from {{store}}", item_other: "{{count}} items" },
    });
    expect(params.has("common:item")).toBe(true);
    expect(params.has("common:item_one")).toBe(false);
    expect([...params.get("common:item")!].sort()).toEqual(["count", "store"]);
  });
});

describe("emit", () => {
  const dts = emit(namespaces, { locale: "en" });

  it("declares a Resources interface with string leaves", () => {
    expect(dts).toContain("export interface Resources {");
    expect(dts).toContain('"welcome": string;');
    expect(dts).toContain('"common": {');
    expect(dts).toContain('"auth": {');
  });

  it("types interpolation params and empty keys as {}", () => {
    expect(dts).toContain('"common:common.welcome": { "name": string | number };');
    expect(dts).toContain('"auth:auth.signin": {};');
    expect(dts).toContain("export type TranslationParams = {");
  });

  it("augments i18next with defaultNS and Resources", () => {
    expect(dts).toContain('declare module "i18next"');
    expect(dts).toContain('defaultNS: "auth";'); // first namespace alphabetically
    expect(dts).toContain("resources: Resources;");
  });

  it("types plural count as a number", () => {
    const pluralDts = emit({ common: { item_one: "{{count}}", item_other: "{{count}}" } });
    expect(pluralDts).toContain('"common:item": { "count": number };');
  });

  it("omits TranslationParams when params is false", () => {
    const keysOnly = emit(namespaces, { params: false });
    expect(keysOnly).not.toContain("TranslationParams");
    expect(keysOnly).toContain("export interface Resources {");
  });
});
