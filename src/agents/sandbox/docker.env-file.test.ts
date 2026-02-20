import { EventEmitter } from "node:events";
import { Readable } from "node:stream";
import { beforeEach, describe, expect, it, vi } from "vitest";
import { ensureSandboxContainer } from "./docker.js";
import type {
  SandboxBrowserConfig,
  SandboxConfig,
  SandboxPruneConfig,
  SandboxToolPolicy,
} from "./types.js";

type SpawnChild = EventEmitter & {
  stdout: Readable;
  stderr: Readable;
  stdin: { end: () => void };
  kill: () => void;
};

const spawnState = vi.hoisted(() => ({
  calls: [] as { args: string[] }[],
}));

vi.mock("node:child_process", async (importOriginal) => {
  const actual = await importOriginal<typeof import("node:child_process")>();
  return {
    ...actual,
    spawn: (_command: string, args: string[]) => {
      spawnState.calls.push({ args });
      const child = new EventEmitter() as unknown as SpawnChild;
      child.stdout = new Readable({
        read() {
          this.push(null);
        },
      });
      child.stderr = new Readable({
        read() {
          this.push(null);
        },
      });
      child.stdin = { end: () => undefined };
      child.kill = () => undefined;

      // Simulate docker inspect -f {{.State.Running}} name -> false
      let stdout = "";
      if (args[0] === "inspect") {
        stdout = "false\n";
      }

      queueMicrotask(() => {
        if (stdout) {
          child.stdout.emit("data", Buffer.from(stdout));
        }
        child.emit("close", 0);
      });
      return child;
    },
  };
});

vi.mock("./registry.js", () => ({
  readRegistry: vi.fn(async () => ({ entries: [] })),
  updateRegistry: vi.fn(),
}));

vi.mock("node:fs/promises", async (_importOriginal) => {
  return {
    default: {
      readFile: vi.fn(async (path: string) => {
        if (path.includes("test.env")) {
          return "TEST_VAR=test_value\nANTHROPIC_API_KEY=secret_value\n";
        }
        throw new Error("ENOENT");
      }),
      mkdir: vi.fn(),
    },
  };
});

describe("ensureSandboxContainer with envFile", () => {
  beforeEach(() => {
    spawnState.calls = [];
    vi.clearAllMocks();
  });

  it("merges env file contents into docker env and sanitizes them for create", async () => {
    const cfg: SandboxConfig = {
      mode: "all",
      scope: "shared",
      workspaceAccess: "rw",
      workspaceRoot: "/tmp/sandboxes",
      docker: {
        image: "test-image",
        containerPrefix: "prefix-",
        workdir: "/app",
        readOnlyRoot: false,
        tmpfs: [],
        network: "none",
        capDrop: [],
        env: { LANG: "C.UTF-8" },
        envFile: "/path/to/test.env",
      },
      browser: { enabled: false } as unknown as SandboxBrowserConfig,
      tools: {} as unknown as SandboxToolPolicy,
      prune: {} as unknown as SandboxPruneConfig,
    };

    await ensureSandboxContainer({
      sessionKey: "session1",
      workspaceDir: "/tmp/ws",
      agentWorkspaceDir: "/tmp/aws",
      cfg,
    });

    const createCall = spawnState.calls.find((c) => c.args[0] === "create");
    expect(createCall).toBeDefined();
    const args = createCall!.args;

    // Check that LANG is present
    expect(args).toContain("--env");
    expect(args).toContain("LANG=C.UTF-8");

    // Check that TEST_VAR is in the args (not blocked)
    expect(args).toContain("TEST_VAR=test_value");

    // Check that ANTHROPIC_API_KEY is blocked from 'create' args by sanitizeEnvVars
    expect(args).not.toContain("ANTHROPIC_API_KEY=secret_value");

    // Important: check that ANTHROPIC_API_KEY IS in the cfg.docker.env for tool call injection
    expect(cfg.docker.env).toHaveProperty("ANTHROPIC_API_KEY", "secret_value");
    expect(cfg.docker.env).toHaveProperty("TEST_VAR", "test_value");
    expect(cfg.docker.env).toHaveProperty("LANG", "C.UTF-8");
  });
});
