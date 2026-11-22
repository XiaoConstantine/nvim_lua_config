// Tells Puck which pi conversation is running in which Rex pane.
//
// pi renames its process to "pi", so its session file can't be read from the
// command line. On every session start (launch, /new, /resume, fork) this writes
// ~/.local/state/puck/panes/<REX_BLOCK>.json, which `agents threads` reads.
// Installed as a symlink in ~/.pi/agent/extensions/.
import fs from "node:fs";
import os from "node:os";
import path from "node:path";

const block = process.env.REX_BLOCK;
const stateHome = process.env.XDG_STATE_HOME || path.join(os.homedir(), ".local", "state");
const dir = path.join(stateHome, "puck", "panes");

function record(ctx: any): void {
  if (!block) return;
  try {
    const file = ctx?.sessionManager?.getSessionFile?.();
    const id = ctx?.sessionManager?.getSessionId?.();
    fs.mkdirSync(dir, { recursive: true });
    const name = block.replace(/[^A-Za-z0-9_.-]/g, "_") + ".json";
    const tmp = path.join(dir, `${name}.${process.pid}.tmp`);
    fs.writeFileSync(
      tmp,
      JSON.stringify({
        block_id: block,
        agent: "pi",
        pid: process.pid,
        session_id: typeof id === "string" ? id : "",
        session_file: typeof file === "string" ? file : "",
        cwd: process.cwd(),
        source: "hook",
        at: Date.now() / 1000,
      }),
    );
    fs.renameSync(tmp, path.join(dir, name));
  } catch {
    // Never get in pi's way.
  }
}

export default function (pi: any) {
  pi.on("session_start", async (_event: any, ctx: any) => {
    if (ctx?.mode !== "tui") return;
    record(ctx);
  });
}
