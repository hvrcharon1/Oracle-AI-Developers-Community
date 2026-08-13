# Skill 36 — APEXlang: Declarative Application Definitions for AI-Generated Enterprise Apps

<!-- Author credit: Michael Hichwa, SVP, Software Development, Oracle — source article
     "Oracle APEX AI Application Generator: Bringing AI to Enterprise App Development,"
     Oracle Database Insider, August 12, 2026. Full citation in References below. -->

> **Capability:** Recognize when an AI coding agent should target a declarative **application definition** (APEXlang) instead of writing implementation code, and use that distinction to keep AI-generated enterprise applications reviewable, versionable, and governed by a managed runtime rather than by hand.

---

## What It Is

Most AI-assisted development follows the same loop regardless of language: a person writes a prompt, the agent emits source code, and a human is on the hook for reviewing, securing, testing, deploying, and maintaining whatever came out. Oracle APEX AI Application Generator, available in OCI on Autonomous AI Database Serverless as part of Oracle APEX 26.1, changes what the agent is asked to produce. Instead of implementation code, the AI generates **APEXlang** — an Application Definition Language (ADL) that expresses pages, navigation, forms, reports, dashboards, and business logic as a structured, human-readable, declarative artifact. Oracle APEX then compiles and executes that definition inside its managed runtime.

The analogy the platform draws on is SQL: a developer writes SQL to say *what* they want done with data, and the database decides *how* to do it. APEXlang applies the same split at the application layer — an agent (or a person) states intent, and the APEX runtime is responsible for execution, consistency, and enforcing operational guardrails. Because the grammar is published and constrained, the agent has fewer low-level implementation decisions to make, which narrows the attack surface and keeps every generated app inheriting the same data-layer security controls (including Deep Data Security) rather than re-implementing them per app.

For an AI agent, this distinction is the actionable part of the skill: **when the target is an Oracle APEX application, generate or edit the APEXlang application definition — not PL/SQL, JavaScript, or HTML implementation code — unless the requested change genuinely falls outside what the definition grammar covers.**

---

## The Three Ways an Agent Can Produce the Same Definition

APEXlang is the single underlying artifact regardless of which surface is used to generate it. An agent should pick the surface based on who's driving and what review step comes next, not treat the three as competing products:

| Path | How it works | Best fit |
|---|---|---|
| Low-code, AI-assisted App Builder | Drag-and-drop, wizards, and inline AI assistance inside the App Builder UI, with visual component previews | A person iterating visually, with AI filling in structure and boilerplate |
| Native AI coding agent | An external coding agent performs spec-to-app or incremental, conversational generation directly against APEXlang | An agent operating autonomously from a natural-language spec, with minimal human-in-the-loop per step |
| VS Code with the Oracle SQL Developer extension | Generative development plus code review, diffs, and merges against the definition as text | Reviewing exactly what an agent changed before it ships — the clearest audit trail of the three |

All three converge on the same application definition, so an agent should feel free to describe *what* it did in terms a reviewer can diff and approve — the third path exists specifically to make that diff-and-approve step possible.

---

## Working Conversationally: Requests Become Targeted Definition Edits

Because APEXlang is declarative, an agent doesn't need to expose its syntax to the person driving it. A request stated as business intent maps onto a scoped change to the definition, not a full regeneration. For example, a request to add a chart of assignments grouped by priority should add one chart region to the relevant page — not touch unrelated pages. A request to localize the application into another language should update text and label bindings — not application logic. A request to add an AI agent that can answer questions about customer orders should add a new agent block grounded in tools and data the application already exposes. A request to rename a button label everywhere it appears should update every matching label attribute across the definition in one pass, and nothing else.

The skill for an agent here is scoping the edit correctly: identify the smallest set of definition elements the request actually touches, change those, and leave the rest of the definition untouched so the diff a human reviews stays legible. Treat every conversational request as a targeted patch to a version-controlled artifact, not a reason to regenerate the application from scratch.

---

## Why This Changes What "Enterprise-Ready" Means for Generated Apps

An agent recommending or building on this pattern should be able to explain the trade-off it's making, not just invoke it:

- **Reviewability** — because the definition is text-based and grammar-constrained, a human can inspect, diff, and approve exactly what an agent changed before it deploys, the same way they'd review a pull request
- **Lifecycle fit** — definitions move through source control, code review, promotion between environments, and rollback using the same processes an enterprise already runs for other artifacts; nothing bespoke is needed just because the artifact was AI-generated
- **Inherited security** — apps get the foundational data-layer security of Oracle AI Database (including Deep Data Security) by virtue of running on the platform, rather than an agent having to re-derive access control per application
- **Durable against platform upgrades** — because execution lives in the managed runtime rather than in generated implementation code, an application keeps benefiting from runtime patches, performance work, and security fixes without needing to be rewritten or regenerated later

An agent should flag it as a design smell if a request would require dropping out of APEXlang into hand-written implementation code for something the grammar already covers — that's the exact pattern this architecture exists to avoid.

---

## Best Practices

- Default to editing the APEXlang application definition for anything the published grammar covers; reach for hand-written PL/SQL or JavaScript only for logic genuinely outside that grammar
- Scope every conversational edit to the smallest set of definition elements the request implies, so the resulting diff stays reviewable by a human
- When acting as the native coding agent in a spec-to-app workflow, still produce output that a person could review through the VS Code diff path — don't rely on the App Builder UI being the only review surface
- Don't hand-roll access control or row-level security logic inside a generated app; let it inherit the platform's data-layer security rather than re-implementing it per application
- Treat the definition, not the running app, as the artifact under version control — commit, diff, and roll back the APEXlang, and let the managed runtime handle re-execution
- See [Skill 06 — Oracle APEX AI Assistant](06_oracle_apex_ai_assistant.md) for the AI Assistant / SQL Workshop features that predate APEXlang and remain part of the same platform; APEXlang extends that "GenDev" foundation from page-level assistance to whole-application definitions

---

## References

- Michael Hichwa, SVP, Software Development, Oracle, ["Oracle APEX AI Application Generator: Bringing AI to Enterprise App Development"](https://blogs.oracle.com/database/oracle-apex-ai-application-generator-bringing-ai-to-enterprise-app-development), Oracle Database Insider, August 12, 2026 — source article for APEXlang, the three development paths, and the conversational-editing model described in this skill
- [Oracle APEX AI Application Generator](https://www.oracle.com/apex/ai-application-generator/)
- [APEXlang documented grammar](https://docs.oracle.com/en/database/oracle/apex/26.1/apxln/)
- [Public APEXlang skills for AI models](https://github.com/oracle/skills)
- [APEXlang examples, Oracle APEX 26.1](https://github.com/oracle/apex/tree/26.1)
- [Oracle APEX 26.1 announcement](https://blogs.oracle.com/apex/announcing-oracle-apex-261)
- [Deep Data Security](https://www.oracle.com/security/database-security/features/deep-data-security/)
- Related skills in this library: [06 — Oracle APEX AI Assistant](06_oracle_apex_ai_assistant.md), [37 — Evaluating AI-Generated Enterprise Applications](37_evaluating_ai_generated_enterprise_apps.md)
