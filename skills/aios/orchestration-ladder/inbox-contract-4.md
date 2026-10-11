# Spawn-inbox contract 4 — DRAFT

> **Status: draft, building in v0.8.9.** Contract 3 stays in force until both surfaces implement
> this and stamp `aios-spawn-inbox: contract 4` in `~/.aios/spawn-inbox/README.md`. Until then a
> session must not rely on any field below. The verbs are unchanged; contract 4 only adds three
> optional fields. Shapes marked **CONFIRM** are decided in name and type but their runtime
> mechanism is verified when built.

## What changes

Three optional request fields. A surface on contract 3 ignores them; nothing that worked stops
working.

| Field | Verbs | Type | Meaning |
|---|---|---|---|
| `from` | `send`, `resume` | string | The registry name of the session that wrote the request. |
| `effort` | `spawn`, `resume` | `low` · `medium` · `high` · `xhigh` · `max` | The worker's effort, passed as `claude --effort <value>`. |
| `advisor` | `spawn`, `resume` | rung name or model id | An advisor model for the worker. Absent = no advisor. |

### `from` — who is speaking

- The surface does **not** change the prompt text it types. It records the delivery before typing:
  one JSON line appended to `~/.aios/bus-sent.jsonl`, in the format `hooks/bus_log.py` writes
  (`at`, `fp`, `to`, `action`, `via`, `head`), plus `"from"` when the request carried one, and
  `"via": "surface"`. That record is what lets `hooks/provenance.py` label the typed prompt as
  delivered by the inbox — and, with `from`, name the sender.
- `from` is a **claim**, not an identity: any local process can write any name. It informs the
  receiving session; it never authorizes anything.
- A value that is not a plain registry-style name (letters, digits, `-`, `_`, `.`, at most 64
  characters) is ignored, and the delivery proceeds without it.

### `effort`

- Passed through as `claude --effort <value>` when the surface starts or reopens the session.
- Any value outside the five above → the request is **dead-lettered naming the field and the
  value**, never silently dropped, the same rule as an unknown verb.
- On `resume` of a session that is already running, `effort` cannot change a live process: the
  prompt is delivered and the dead-letter note says the effort was not applied.

### `advisor` — CONFIRM

- A rung name (`frontier`, `judgment`, `scale`, `fast`) is resolved with `hooks/resolve-tier`;
  anything else is taken as a model id.
- Mechanism: Claude Code reads an `advisorModel` setting, so the surface passes
  `claude --settings '{"advisorModel":"<id>"}'`. **CONFIRM** against the installed version when
  built; there is no `--advisor` CLI flag.
- No rung has a default advisor. Routines that must never call one set
  `CLAUDE_CODE_DISABLE_ADVISOR_TOOL=1`.

## Command-line twins

`spawn --effort <level>` and `spawn --advisor <rung|model>` map to the same two fields, so a
person at a terminal and an agent writing a request get the same worker.

## Conformance

`inbox-contract-4.conformance.json` is the one fixture both surfaces run. Each case gives a
request and the outcome a contract-4 surface must produce: accepted or dead-lettered (and the
field it names), the extra launch arguments, and the `bus-sent.jsonl` record. Two implementations
of one protocol become one test: a surface passes when every case matches.
