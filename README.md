# Hermetica

**Elixir/OTP-Powered Orchestration Layer for LLM Agents**

Hermetica is a **protocol-first, deterministic, and auditable agent orchestration system** designed for organizations that have outgrown the operational complexity of LangChain. It preserves your existing Python-based LangChain tools while replacing its brittle chain/agent runtime with a robust Elixir/OTP core.

---

## Why Hermetica?

Enterprises using LangChain often run into:

* **Unpredictable behavior** — Flows break due to implicit state, silent failures, or prompt drift.
* **Operational blind spots** — Limited observability for tracing, debugging, or replaying runs.
* **Vendor lock-in** — Tightly coupled orchestration and model provider code.
* **Compliance headaches** — Hard to guarantee auditability, masking, and RBAC.

Hermetica addresses these pain points by:

* Providing **typed, replayable flows** instead of ad-hoc callback chains.
* Adding **first-class observability** (OpenTelemetry, structured logs, replay tools).
* Offering a **migration path** off LangChain via a bridging adapter.
* Embedding **compliance and governance** into the orchestration layer.

---

## Architecture Overview

```text
Clients / Systems → Triggers (Webhook, Cron, Queue, MCP Event)
      │
Orchestrator (Elixir/OTP)
• FlowSupervisor (per-flow)
• FlowServer (per-run)
• Retries, Backoff, Circuit Breakers
      │
Flow DSL → Compiled DAG → Steps
      │
Tools via MCP or Native Adapters
      │
Postgres (State & Audit) + LiveView Dashboard
      │
Observability: OpenTelemetry, Metrics, Replay
```

---

## Migration Path from LangChain

Hermetica ships with a **LangChain Adapter** to let you:

1. **Wrap existing LangChain tools** as MCP servers with JSON Schema contracts.
2. **Run them inside Hermetica flows**, keeping your current Python code.
3. **Gradually replace** LangChain orchestration with Hermetica's typed DAG flows.
4. **Remove the adapter** once all flows are migrated.

This allows a **strangler pattern** migration with zero downtime.

---

## Example: LangChain Adapter Step

```elixir
step :enrich, mcp: {"langchain_adapter", "lookup_person"}, args: fn %{parse: p} ->
  %{email: p.email}
end
```

Where `langchain_adapter` is an MCP bridge that:

* Connects to a running LangChain process.
* Calls the corresponding Python tool.
* Validates inputs/outputs against JSON Schema.

---

## Features

* **Deterministic Flows** — Typed DAG, explicit error handling.
* **First-Class Observability** — OpenTelemetry traces, structured logs, replay.
* **Compliance Ready** — PII masking, RBAC, signed webhooks, audit exports.
* **MCP-first Tooling** — Model Context Protocol integration.
* **Flexible Connectors** — HTTP, Slack/Teams, DB, S3, Kafka.
* **Migration-Friendly** — LangChain adapter for gradual cutover.

---

## Roadmap

* **MVP (6 weeks)**

  * Runtime core (FlowServer, StepRunner, retries, Postgres schema).
  * MCP client and connectors.
  * LiveView dashboard.
  * LLM gateway for multiple providers.
  * Compliance features.
  * Dual-run harness for migration.

* **Future**

  * Visual DAG editor.
  * Built-in benchmarking suite.
  * Model-agnostic caching and routing.

---

## Quick Start

```bash
# Clone
 git clone git@github.com:your-org/hermetica.git
 cd hermetica

# Install deps
 mix deps.get

# Run tests
 mix test

# Start console
 iex -S mix

# Trigger a flow
 Hermetica.FlowServer.trigger(Hermetica.Flows.Hello, %{who: "world"})
```

---

## Diagram: Strangler Pattern Migration

```mermaid
flowchart LR
  subgraph Current Stack
    LC[LangChain Runtime]
  end

  subgraph Hermetica Stack
    H[Hermetica Orchestrator]
    MCP[MCP Adapter]
  end

  Clients --> H --> MCP --> LC --> Tools
  H --> NativeTools[Native Tools]
```

---

## License

MIT
