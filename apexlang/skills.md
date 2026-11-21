# APEXlang Skills

A practical skill set for building, reviewing, and operating Oracle APEX applications with **APEXlang** and an AI coding agent. These skills are distilled from a recorded conference session by members of the Oracle APEX team: a short strategy talk, a recorded end-to-end demo, and an architecture deep dive with audience Q&A.

Each skill states a capability, how to apply it, and what to watch out for. Skills reflect what the presenters showed and said; version-specific details (APEX 26.1 vs 26.2, SQL Developer releases) are noted where they matter and should be re-checked against current Oracle documentation.

> For the conceptual background on why an agent should target an application definition instead of implementation code, see [Skill 36 — APEXlang: AI Application Generator](../skills/36_apexlang_ai_application_generator.md). For reviewing what an agent produced, see [Skill 37 — Evaluating AI-Generated Enterprise Applications](../skills/37_evaluating_ai_generated_enterprise_apps.md).

---

## Skills at a Glance

| # | Skill | Capability |
| --- | --- | --- |
| 1 | Decide when APEXlang beats a hand-rolled stack | Make the build-versus-vibe-code decision with the right trade-offs |
| 2 | Assemble the APEXlang toolchain | Stand up the agent, IDE, CLI, skills, and database pieces |
| 3 | Go from data to a working app | Run the spec-to-app loop: data model, first app, compile, iterate |
| 4 | Refine with itemized prompts | Steer an agent through batches of concrete fixes |
| 5 | Let the agent verify its own work | Use browser checks, tests, and throwaway rows, then review what it added |
| 6 | Restyle from a reference application | Copy UI patterns and themes by pointing at an existing app |
| 7 | Add a tool-secured AI agent | Build an in-app agent and validate its answers |
| 8 | Translate a whole application | Localize with message-based translation and verify with session overrides |
| 9 | Review, diff, and statically analyze definitions | Treat APEXlang as reviewable source |
| 10 | Deploy and automate | Compile, ship through REST, and wire into CI/CD |
| 11 | Build tools on the published grammar | Create parsers, analyzers, and generators from the BNF |
| 12 | Keep skills and model choice current | Avoid stale skills and pick models sensibly |
| 13 | Mix AI and manual editing | Use Page Designer where it is cheaper than a prompt |
| 14 | Approach legacy migration realistically | Plan Oracle Forms and other legacy moves with AI help |

---

## Skill 1 — Decide When APEXlang Beats a Hand-Rolled Stack

**Capability:** Explain, and act on, the difference between asking an agent to generate an application on a managed runtime and asking it to generate a full custom stack.

**How**

* Frame the choice by who owns what afterward. With a custom stack (for example generated Python or Node code), the team owns authentication, session handling, dependency patching, logging, monitoring, and hundreds of generated files, and repeats that work per project.
* With APEXlang, the agent targets a higher abstraction and the managed runtime handles execution, security patches, identity-provider integration, logging, and metrics. On OCI the presenters cited identity federation and metrics/log integration working out of the box.
* Note the commercial side: APEX is included with Oracle Database at no extra cost, and Autonomous Database (on OCI, AWS, Azure, and Google Cloud) comes with APEX already provisioned and patched.
* Position AI as the way to get most of an application built quickly, while expecting some manual finishing. The presenters expected a large majority of an app to come from prompting, with the remainder done by hand.

**Watch out**

* Speed alone is no longer the differentiator, since any stack can be vibe coded. The case rests on lifecycle, security posture, and maintainability two to three years out, so argue it on those terms.
* The scale argument matters most at volume: one generated app is manageable; hundreds multiply the patching and review burden.

---

## Skill 2 — Assemble the APEXlang Toolchain

**Capability:** Set up an environment where an agent can generate APEXlang and compile it into a database.

**How**

1. Use **Oracle APEX 26.1 or later**; Oracle's getting-started guidance lists 26.1.2 or newer.
2. Install **SQL Developer for VS Code** and/or **SQLcl** (with its MCP server configured) so definitions can be compiled and managed.
3. Clone the **Oracle skills repository** (`github.com/oracle/skills`) so the agent has APEXlang skills, and keep it updated.
4. Choose a coding agent. The demo used Codex; the presenters said any agent works, including Claude.
5. Connect to a backend Oracle database or schema that the agent can read and the compile step can write to.

**Watch out**

* Compile workflow improved in SQL Developer 26.2 (as the presenter recalled it): you can keep your session when compiling APEXlang, which is much faster than reconnecting each time. Enable it once per VS Code session.
* People upgrade the APEX engine and ORDS but forget to refresh the agent skills. Add the skills refresh to the upgrade checklist.

---

## Skill 3 — Go From Data to a Working App

**Capability:** Run the spec-to-app loop from raw data and requirements to a deployed first version.

**How**

1. Start from requirements plus real data, for example a spreadsheet export.
2. Describe the data shape you want (the demo called out two lookup tables for allocations and session types) and ask the agent to propose a data model.
3. **Review the model before accepting it.** In the demo the agent noticed repeated sessions and added a third table for occurrences on its own.
4. Instantiate the model in the database.
5. Ask for a very small first application (the demo started with two pages), generate it as APEXlang, and compile it into the database.
6. Log in, look at it, then build out larger chunks and refine them, the same pattern as any project with users who will change their minds.

**Watch out**

* Agent-added structure is not automatically wrong, but in a real project check it against your requirements and remove what you do not need.

---

## Skill 4 — Refine With Itemized Prompts

**Capability:** Drive improvements with concrete, enumerated requests rather than vague dissatisfaction.

**How**

* Name component types: dashboards with specific charts, faceted search pages, forms, content-row reports, and admin reports for each table.
* State the data you want highlighted in each chart (for example the two dimensions the demo emphasized).
* Batch small fixes in one prompt as a list: fix icons, remove the header, drop the breadcrumb logo, add reports for the remaining tables.
* Let the agent run while you review the compiled app, then send the next list.

**Watch out**

* The first pass is functional, not polished. Plan for two or three refinement rounds, and use Skill 6 for visual polish rather than describing every color and spacing choice.

---

## Skill 5 — Let the Agent Verify Its Own Work, Then Review It

**Capability:** Use the agent's own testing behavior to catch defects, while auditing what it added without being asked.

**How**

* Give the agent permission to drive the browser. In the demo it took screenshots and compared them to the request.
* Expect self-initiated tests. The agent treated a quantity as a whole number, wrote and ran a unit test for it, and added a uniqueness check so two allocations could not share a name, neither of which was requested.
* Expect temporary verification rows (the demo created rows with a throwaway prefix) that the agent inserts to prove forms work and then deletes.
* Let it fix runtime errors. It hit an Oracle error from inserting into a generated-always identity column and corrected its own approach.

**Watch out**

* Constraints and rules the agent adds are real behavior changes. Compare them with the data model and requirements, and keep or remove them deliberately.
* Confirm test rows were cleaned up, and do not point an autonomous agent at production data.
* Grant browser and database permissions deliberately; autonomy is only as safe as the access you give it.

---

## Skill 6 — Restyle From a Reference Application

**Capability:** Transfer UI patterns, layout, and theme from an existing APEX app to a new one.

**How**

1. Install a sample application that embodies the UI patterns you want (the demo used a pattern-showcase sample from Oracle's APEX team).
2. Export that application as APEXlang.
3. Prompt the agent to make your application look like the reference, and tell it which application that is.
4. The agent reads the reference's constructs and applies them. In the demo this turned a plain faceted search into a content-row layout with times, durations, and room details, and applied the reference color scheme through the theme roller.

**Watch out**

* Check that functionality survived the restyle (filters, search, forms) before accepting it.
* This works because the reference is readable text. Keep your own standard layouts as exported references for future apps.

---

## Skill 7 — Add a Tool-Secured AI Agent and Validate It

**Capability:** Add an in-app agent that answers questions about your data, constrained to developer-defined tools, and prove its answers are right.

**How**

* Ask for an agent that knows about a specific data domain. APEX agents are secured by **tools**: the agent only runs the queries the developer has defined for it.
* In the demo, the generating agent cross-checked the in-app agent, running a few dozen queries to confirm its answers matched the data.
* Test with a realistic ladder of questions: an aggregate (most common category), a topic lookup, adjacency (what comes right before and after in the same room), a nearby-rooms query, and a feasibility question combining two items.

**Watch out**

* The tools define what the agent can ever see or do. Review each tool query for scope and sensitivity.
* Compare answers with direct SQL on current data. In the demo, room assignments changed during the event, so stale assumptions would have produced wrong answers.

---

## Skill 8 — Translate a Whole Application

**Capability:** Localize an entire application, including its in-app agent, with a single request.

**How**

* Ask the agent to translate the application. In APEX 26.1 this uses message-based translation, replacing the older loop of exporting a translation file, filling it in, and re-importing it.
* Verify with the session language override in the session controls. Enabling it flipped the demo session into Spanish, including the agent's responses.

**Watch out**

* Have a speaker of the target language review domain-specific terms before release.

---

## Skill 9 — Review, Diff, and Statically Analyze Definitions

**Capability:** Treat the APEXlang file as source code that humans and tools can inspect.

**How**

* Keep definitions in source control so changes can be diffed, merged, reviewed, and signed off. The presenters pointed to compliance-style change control as a benefit of having a physical file.
* Ask a second AI pass to review the agent's changes, or read the diff yourself in VS Code.
* Use SQLcl's code scanning against the text definition for questions like "find SQL injection risks" or "find components missing help text".
* Compile to validate that the definition is accepted by the grammar.

**Watch out**

* Reviewability is a human process. Make the diff a required step before promotion, not an optional one.

---

## Skill 10 — Deploy and Automate

**Capability:** Move APEXlang from an agent session into environments and pipelines.

**How**

* Export an existing app as APEXlang from Page Designer or the command line, so legacy apps can join an AI-assisted workflow.
* Compile from SQL Developer for VS Code or SQLcl; the compile action is available in the editor.
* Use ORDS REST APIs to send an APEXlang artifact to the database for on-the-fly compilation, with no SQL*Net access required.
* Use the SQLcl `project` command to package work for CI/CD. Check current SQLcl documentation for exact syntax.

**Under the hood:** a lexer and parser (built with ANTLR in a standalone Java library shared by SQLcl, ORDS, and SQL Developer) read the text, map it to PL/SQL, and write it into the same APEX metadata that Page Designer produces. Hand-coded and AI-generated apps therefore run the same way.

---

## Skill 11 — Build Tools on the Published Grammar

**Capability:** Use the public BNF grammar to create your own parsers, analyzers, and generators.

**How**

* Download the published grammar and give it to an AI with a concrete goal: a static analyzer, a linter for naming conventions, a documentation generator, a converter, or an app generator.
* Rely on the fact that a standards-based grammar is understood by existing parser libraries. At least one community member had already built a parser from it by the time of the session.

**Why a grammar:** the team chose BNF/ANTLR over JSON or YAML because those formats would still have required an implicit grammar inside them, with worse results. A language acts as a contract that turns text into a deterministic outcome.

---

## Skill 12 — Keep Skills and Model Choice Current

**Capability:** Maintain agent skills so they help instead of capping the model.

**How**

* Prefer skills generated by the compiler pipeline. In 26.2 the skills are emitted as markdown by the compiler build, covering the full set of components, validations, and workflow definitions, rather than hand-written afterwards. Audience members who tried them reported better results than the 26.1 skills.
* Re-test your skills whenever you change models. A skill written for yesterday's model can limit a newer one, so check what is still needed.
* Track the Oracle skills repository, which also carries database, OCI, and (planned) Fusion skills, and update it on a schedule.
* Choose models by need: frontier models from Anthropic and OpenAI performed best; smaller or local models also work and land in the same execution path.

**Watch out**

* The presenters described getting APEXlang into future frontier-model training as a goal in progress, not a delivered fact. If it succeeds, expect smaller skill context and lower token cost; until then, keep skills loaded.

---

## Skill 13 — Mix AI and Manual Editing

**Capability:** Pick the cheapest tool for each change.

**How**

* Use Page Designer or a quick text edit for small changes such as renaming a heading or updating help text. Spending tokens on those is wasteful.
* Use the agent for broad changes: new pages, cross-page renames, restyling, translation.
* The language and Page Designer share the same underlying infrastructure, and both are maintained, so mixing them is supported.

---

## Skill 14 — Approach Legacy Migration Realistically

**Capability:** Use AI to speed up moving legacy systems, such as Oracle Forms, to APEX without expecting magic.

**How**

* Treat the answer to "can Forms be migrated?" as yes, with caveats: AI can greatly shorten the work but is not a silver bullet.
* Supply context. A well-commented, well-named schema helps. If yours is not, feed the agent wiki pages, design documents, and data definitions so it understands what the schema means.
* Remember the basic rule: text in, text out. Better input context produces better generated output.

---

## Pitfalls to Avoid

* Regenerating a whole app for a small edit; scope each request to what it touches.
* Accepting agent-added tables, constraints, or tests without reviewing them against requirements.
* Letting skills go stale after an APEX, ORDS, or model upgrade.
* Pointing an autonomous agent with write access at production data.
* Skipping the diff and review step because the output looks right in the browser.
* Treating in-app agent answers as correct without comparing them to direct queries.

---

## References

* [Oracle APEX AI Application Generator](https://www.oracle.com/apex/ai-application-generator/)
* [APEXlang documented grammar (APEX 26.1)](https://docs.oracle.com/en/database/oracle/apex/26.1/apxln/)
* [Oracle skills repository](https://github.com/oracle/skills)
* [APEXlang examples, Oracle APEX 26.1](https://github.com/oracle/apex/tree/26.1)
* [Introducing APEXlang (Oracle APEX blog)](https://blogs.oracle.com/apex/introducing-apexlang-the-future-of-generative-application-development-with-oracle-apex)
* Related in this repository: [Skill 36](../skills/36_apexlang_ai_application_generator.md), [Skill 37](../skills/37_evaluating_ai_generated_enterprise_apps.md), [APEXlang folder index](README.md)
