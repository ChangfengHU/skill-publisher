# SOP Skill Contract v1

`sop-skill-contract.json` is a sidecar file for the SOP platform. It is not
required by the skill runtime. Agents that do not know this file should ignore
it and continue to use `SKILL.md` and bundled scripts normally.

## Contract Sections

`schema`
: Contract version. Current value is `sop-skill-contract/v1`.

`skill`
: Stable identity copied from `SKILL.md` frontmatter and the skill directory.
  It is used by Node Builder for naming and traceability.

`compatibility`
: Declares that the contract is sidecar metadata. `required_by_skill_runtime`
  must stay `false`.

`public_interface`
: The public A2A Node input model. For v1 it must be `instruction+materials`.
  Do not expose CLI-specific fields such as `source_url`, `api_token`, or
  `output_dir` as public Node inputs.

`invoke`
: Execution hints for the SOP adapter. These hints tell the platform how an
  agent should find and use the skill, but they do not replace `SKILL.md`.

`adapter_hints`
: Internal extraction hints discovered from scripts and docs. They help the
  adapter decide how to interpret `instruction` and `materials`. They must not
  be rendered to users as public Node inputs.

`outputs`
: Output discovery rules. v1 uses `manifest_artifacts`: the runtime should
  collect files from `SOP_OUTPUT_DIR`, generate or read `manifest.json`, and
  expose artifacts through A2A Task artifacts. `declared_artifacts` are static
  candidates discovered from source and documentation; they are not required
  outputs until a real probe proves them.

`probe`
: A suggested real test message. Publish tools may generate a default, but
  Node Builder should ask the user to confirm before executing it.

`security`
: Secret declarations only. Never write actual token or key values into this
  file.

## LLM Patch Prompt

Use this only after deterministic source analysis has produced a baseline
contract. The model must return a patch, not a full replacement.

```text
Return strict JSON only.

You are improving a SOP Skill sidecar contract.

Rules:
- Do not change schema, skill.id, compatibility, public_interface, outputs.mode,
  or security.secret_values_embedded.
- Do not invent files, CLI options, outputs, secrets, URLs, or required inputs.
- You may only add or refine:
  - adapter_hints.notes
  - adapter_hints.extraction[].description
  - probe.instruction
  - probe.materials
  - probe.requires_user_confirmation
  - generation.llm_notes
- Node public input must remain instruction + materials.
- CLI-specific fields are internal adapter hints only.
- Return a JSON object with keys: patch, risks, assumptions.

Baseline contract:
{{BASELINE_CONTRACT_JSON}}

Source digest:
{{SOURCE_DIGEST_JSON}}
```

## Acceptance

A generated contract passes v1 acceptance when:

- `schema` is `sop-skill-contract/v1`.
- `compatibility.required_by_skill_runtime` is `false`.
- `public_interface.input_model` is `instruction+materials`.
- Every adapter hint has `expose_to_node_user: false`.
- `outputs.mode` is `manifest_artifacts`.
- Static `declared_artifacts` are candidates only and have `required: false`.
- No secret values are embedded.
- The skill can still be installed and used without reading this file.
