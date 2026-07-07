# SOP Skill Service Acceptance

Use this checklist after publishing a skill intended for SOP A2A Node Builder.

## Package Acceptance

- The install command downloads and installs the skill into the selected agent
  skill directory.
- Installed package contains `SKILL.md`.
- Installed package contains `sop-skill-contract.json`.
- `sop-skill-contract.json` validates against `sop-skill-contract/v1`.
- Normal skill execution does not require reading the sidecar contract.

## Contract Acceptance

- Public input model is `instruction+materials`.
- Adapter hints are internal only and have `expose_to_node_user: false`.
- Secret values are not embedded in the contract.
- Outputs use `manifest_artifacts` discovery.
- Static `declared_artifacts` are candidates only. Missing static candidates
  must not fail Node Builder or A2A runtime validation.
- Probe instruction is either present or explicitly requires user confirmation.

## Execution Acceptance

- Fast deterministic skills should run a real CLI smoke and write files to an
  output directory.
- Long-running or external-worker skills may use package + CLI/help smoke first,
  then require a real Node Builder Probe before publish.
- Skills requiring private APIs must declare required env names, but values must
  come from runtime/instance secret configuration or a private installer layer.

## Current Validated Install Commands

```bash
bash <(curl -fsSL 'https://skill.vyibc.com/install-youtube-metadata-fetch.sh?ts=20260704071100')
bash <(curl -fsSL 'https://skill.vyibc.com/install-youtube-deep-research.sh?ts=20260704071050')
bash <(curl -fsSL 'https://skill.vyibc.com/install-article-writer.sh?ts=20260704071050')
bash <(curl -fsSL 'https://skill.vyibc.com/install-chatgpt-remote-image-service.sh?ts=20260704071236')
```

## Current Smoke Results

- `youtube-metadata-fetch`: install + contract validation + real CLI output
  directory passed.
- `youtube-deep-research`: install + contract validation + real workflow output
  directory passed.
- `article-writer`: install + contract validation + real CLI output directory
  passed.
- `chatgpt-remote-image-service`: install + contract validation + CLI help
  passed. Full image generation should be verified by Node Builder Probe because
  it is long-running and depends on remote browser worker state.
