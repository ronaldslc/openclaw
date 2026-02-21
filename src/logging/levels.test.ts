import { describe, expect, it } from "vitest";
import { levelToMinLevel, normalizeLogLevel } from "./levels.js";

describe("levelToMinLevel", () => {
  it("maps levels to match tslog minLevel numbering (trace=1 .. fatal=6)", () => {
    // tslog minLevel: 0=silly, 1=trace, 2=debug, 3=info, 4=warn, 5=error, 6=fatal
    expect(levelToMinLevel("trace")).toBe(1);
    expect(levelToMinLevel("debug")).toBe(2);
    expect(levelToMinLevel("info")).toBe(3);
    expect(levelToMinLevel("warn")).toBe(4);
    expect(levelToMinLevel("error")).toBe(5);
    expect(levelToMinLevel("fatal")).toBe(6);
    expect(levelToMinLevel("silent")).toBe(Number.POSITIVE_INFINITY);
  });

  it("debug < info < warn (more verbose levels have lower minLevel values)", () => {
    // A logger with minLevel=debug should pass debug, info, warn, error, fatal.
    // tslog filters out entries whose level id is BELOW minLevel.
    // So debug(2) < info(3) < warn(4) must hold for correct filtering.
    expect(levelToMinLevel("debug")).toBeLessThan(levelToMinLevel("info"));
    expect(levelToMinLevel("info")).toBeLessThan(levelToMinLevel("warn"));
    expect(levelToMinLevel("warn")).toBeLessThan(levelToMinLevel("error"));
    expect(levelToMinLevel("error")).toBeLessThan(levelToMinLevel("fatal"));
    expect(levelToMinLevel("trace")).toBeLessThan(levelToMinLevel("debug"));
  });

  it("setting minLevel=debug allows debug calls through (tslog semantics)", () => {
    // tslog passes a log entry when entry.logLevelId >= minLevel.
    // debug entry has logLevelId=2, so minLevel must be <= 2 to pass.
    const minLevel = levelToMinLevel("debug");
    const debugLogLevelId = 2; // tslog: DEBUG=2
    expect(debugLogLevelId).toBeGreaterThanOrEqual(minLevel);
  });

  it("setting minLevel=info filters out debug calls (tslog semantics)", () => {
    const minLevel = levelToMinLevel("info");
    const debugLogLevelId = 2; // tslog: DEBUG=2
    expect(debugLogLevelId).toBeLessThan(minLevel);
  });
});

describe("normalizeLogLevel", () => {
  it("returns valid levels as-is", () => {
    expect(normalizeLogLevel("debug")).toBe("debug");
    expect(normalizeLogLevel("info")).toBe("info");
    expect(normalizeLogLevel("warn")).toBe("warn");
    expect(normalizeLogLevel("error")).toBe("error");
    expect(normalizeLogLevel("trace")).toBe("trace");
    expect(normalizeLogLevel("silent")).toBe("silent");
  });

  it("falls back for unknown levels", () => {
    expect(normalizeLogLevel("banana")).toBe("info");
    expect(normalizeLogLevel("banana", "debug")).toBe("debug");
  });

  it("falls back when undefined", () => {
    expect(normalizeLogLevel(undefined)).toBe("info");
    expect(normalizeLogLevel(undefined, "warn")).toBe("warn");
  });

  it("trims whitespace", () => {
    expect(normalizeLogLevel("  debug  ")).toBe("debug");
  });
});
