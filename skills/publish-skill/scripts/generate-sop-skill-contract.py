#!/usr/bin/env python3
"""Generate a SOP sidecar contract for a portable skill package.

The contract is intentionally platform-facing metadata. It does not change how
the skill itself is executed by Codex, Hermes, OpenClaw, or other agents.
"""

from __future__ import annotations

import argparse
import json
import os
import pathlib
import re
from typing import Any


OUTPUT_NAME = "sop-skill-contract.json"


def read_text(path: pathlib.Path) -> str:
    try:
        return path.read_text(encoding="utf-8")
    except UnicodeDecodeError:
        return path.read_text(errors="replace")


def parse_frontmatter(markdown: str) -> dict[str, str]:
    if not markdown.startswith("---\n"):
        return {}
    end = markdown.find("\n---", 4)
    if end < 0:
        return {}
    data: dict[str, str] = {}
    lines = markdown[4:end].splitlines()
    index = 0
    while index < len(lines):
        line = lines[index]
        index += 1
        if ":" not in line:
            continue
        key, value = line.split(":", 1)
        key = key.strip()
        value = value.strip()
        if value in {">", "|"}:
            folded: list[str] = []
            while index < len(lines) and (lines[index].startswith(" ") or lines[index].startswith("\t")):
                folded.append(lines[index].strip())
                index += 1
            data[key] = (" " if value == ">" else "\n").join(part for part in folded if part)
        else:
            data[key] = value.strip('"').strip("'")
    return data


def title_from_skill_id(skill_id: str) -> str:
    return " ".join(part.capitalize() for part in re.split(r"[-_]+", skill_id) if part)


def find_entrypoint(skill_dir: pathlib.Path, skill_id: str) -> str:
    skill_md = skill_dir / "SKILL.md"
    if skill_md.exists():
        markdown = read_text(skill_md)
        skill_tokens = {part for part in re.split(r"[-_]+", skill_id.lower()) if part}
        candidates: list[tuple[int, int, str]] = []
        for match in re.finditer(r"scripts/[A-Za-z0-9_.-]+\.(?:sh|py|js|ts|mjs)", markdown):
            candidate = skill_dir / match.group(0)
            if candidate.exists():
                script_tokens = {part for part in re.split(r"[-_.]+", candidate.name.lower()) if part}
                score = len(skill_tokens & script_tokens)
                candidates.append((score, -match.start(), match.group(0)))
        if candidates:
            candidates.sort(reverse=True)
            return candidates[0][2]

    scripts_dir = skill_dir / "scripts"
    if not scripts_dir.is_dir():
        return ""
    preferred = [
        scripts_dir / f"{skill_id}.sh",
        scripts_dir / "run.sh",
        scripts_dir / f"{skill_id.replace('-', '_')}.py",
    ]
    for path in preferred:
        if path.exists():
            return str(path.relative_to(skill_dir))
    for path in sorted(scripts_dir.iterdir()):
        if path.is_file() and path.suffix in {".sh", ".py", ".js", ".ts", ".mjs"}:
            return str(path.relative_to(skill_dir))
    return ""


def referenced_script_files(skill_dir: pathlib.Path, entrypoint: str) -> list[pathlib.Path]:
    if not entrypoint:
        return []
    entry_path = skill_dir / entrypoint
    if not entry_path.exists() or not entry_path.is_file():
        return []
    files: list[pathlib.Path] = [entry_path]
    text = read_text(entry_path)
    scripts_dir = skill_dir / "scripts"
    for match in re.finditer(r"([A-Za-z0-9_-]+\.(?:py|js|ts|mjs|sh))", text):
        candidate = scripts_dir / match.group(1)
        if candidate.exists() and candidate not in files:
            files.append(candidate)
    return files


def relevant_source_files(skill_dir: pathlib.Path, entrypoint: str = "") -> list[pathlib.Path]:
    files: list[pathlib.Path] = []
    for name in ("SKILL.md", "README.md"):
        path = skill_dir / name
        if path.exists():
            files.append(path)
    if entrypoint:
        for path in referenced_script_files(skill_dir, entrypoint):
            if path not in files:
                files.append(path)
        return files
    scripts_dir = skill_dir / "scripts"
    if scripts_dir.is_dir():
        for path in sorted(scripts_dir.rglob("*")):
            if path.is_file() and path.suffix in {".sh", ".py", ".js", ".ts", ".mjs"}:
                files.append(path)
    return files


def discover_cli_options(text: str) -> dict[str, dict[str, Any]]:
    options: dict[str, dict[str, Any]] = {}
    for match in re.finditer(r"--([A-Za-z0-9][A-Za-z0-9_-]*)\)", text):
        name = match.group(1).replace("-", "_")
        options.setdefault(name, {"name": name, "flags": sorted({f"--{match.group(1)}"})})
    for match in re.finditer(r"add_argument\(\s*['\"]--([A-Za-z0-9][A-Za-z0-9_-]*)['\"]", text):
        name = match.group(1).replace("-", "_")
        options.setdefault(name, {"name": name, "flags": sorted({f"--{match.group(1)}"})})
    for match in re.finditer(r"Missing --([A-Za-z0-9][A-Za-z0-9_-]*)", text):
        name = match.group(1).replace("-", "_")
        row = options.setdefault(name, {"name": name, "flags": [f"--{match.group(1)}"]})
        row["required_for_direct_cli"] = True
    return options


def option_kind(name: str) -> str:
    lower = name.lower()
    if "url" in lower:
        return "url"
    if "token" in lower or "secret" in lower or "key" in lower:
        return "secret"
    if "dir" in lower:
        return "directory"
    if "file" in lower or "image" in lower:
        return "file"
    if "timeout" in lower or "interval" in lower or lower.startswith("max_"):
        return "number"
    if "json" in lower:
        return "json"
    return "text"


def is_internal_noise(name: str) -> bool:
    lower = name.lower()
    return lower in {"help", "h", "output_dir", "output_json", "output_name"} or lower.startswith("output_")


def discover_extraction_hints(skill_dir: pathlib.Path, entrypoint: str = "") -> list[dict[str, Any]]:
    merged: dict[str, dict[str, Any]] = {}
    for path in relevant_source_files(skill_dir, entrypoint):
        text = read_text(path)
        for name, row in discover_cli_options(text).items():
            if is_internal_noise(name):
                continue
            hint = merged.setdefault(
                name,
                {
                    "name": name,
                    "kind": option_kind(name),
                    "source": "instruction_or_materials",
                    "required_for_direct_cli": False,
                    "expose_to_node_user": False,
                    "evidence": [],
                },
            )
            if row.get("required_for_direct_cli"):
                hint["required_for_direct_cli"] = True
            evidence = str(path.relative_to(skill_dir))
            if evidence not in hint["evidence"]:
                hint["evidence"].append(evidence)
    return sorted(merged.values(), key=lambda item: (not item["required_for_direct_cli"], item["name"]))


ARTIFACT_RE = re.compile(
    r"(?<![A-Za-z0-9_./-])([A-Za-z0-9][A-Za-z0-9_.-]*\.(?:json|md|txt|csv|html|png|jpg|jpeg|webp|srt|vtt))(?![A-Za-z0-9_./-])"
)


def artifact_kind(name: str) -> str:
    suffix = pathlib.Path(name).suffix.lower()
    if suffix == ".json":
        return "json"
    if suffix in {".md", ".txt", ".srt", ".vtt"}:
        return "text"
    if suffix in {".png", ".jpg", ".jpeg", ".webp"}:
        return "image"
    if suffix == ".html":
        return "html"
    if suffix == ".csv":
        return "table"
    return "file"


def discover_declared_artifacts(skill_dir: pathlib.Path, entrypoint: str = "") -> list[dict[str, Any]]:
    artifacts: dict[str, dict[str, Any]] = {}
    for path in relevant_source_files(skill_dir, entrypoint):
        text = read_text(path)
        for match in ARTIFACT_RE.finditer(text):
            name = match.group(1)
            if name.startswith("install-"):
                continue
            row = artifacts.setdefault(
                name,
                {
                    "name": name,
                    "kind": artifact_kind(name),
                    "path_hint": name,
                    "source": "skill_source",
                    "evidence": [],
                    "required": False,
                    "validation_role": "candidate",
                    "confidence": "static_source_mention",
                    "relayable": True,
                },
            )
            evidence = str(path.relative_to(skill_dir))
            if evidence not in row["evidence"]:
                row["evidence"].append(evidence)
    return sorted(artifacts.values(), key=lambda item: item["name"])


def discover_required_env(skill_dir: pathlib.Path, entrypoint: str = "") -> list[str]:
    names: set[str] = set()
    pattern = re.compile(r"\b([A-Z][A-Z0-9_]*(?:TOKEN|SECRET|API_KEY|KEY))\b")
    for path in relevant_source_files(skill_dir, entrypoint):
        text = read_text(path)
        for match in pattern.finditer(text):
            name = match.group(1)
            if name in {"API_KEY", "API_TOKEN", "SECRET", "TOKEN", "WORKFLOW_TOKEN"}:
                continue
            names.add(name)
    return sorted(names)


def infer_probe(markdown: str, hints: list[dict[str, Any]]) -> dict[str, Any]:
    url_match = re.search(r"https?://(?:www\.)?(?:youtube\.com/watch\?v=|youtu\.be/)[A-Za-z0-9_-]+", markdown)
    if url_match:
        return {
            "instruction": f"请使用这个视频链接执行一次最小成功测试：{url_match.group(0)}",
            "materials": [],
            "requires_user_confirmation": True,
            "source": "skill_documentation",
        }
    prompt_required = any(item["name"] == "prompt" and item["required_for_direct_cli"] for item in hints)
    if prompt_required:
        return {
            "instruction": "请执行一次最小成功测试，并把结果写入标准输出目录。",
            "materials": [],
            "requires_user_confirmation": True,
            "source": "generated_default",
        }
    return {
        "instruction": "",
        "materials": [],
        "requires_user_confirmation": True,
        "source": "missing_probe_sample",
    }


def build_contract(skill_dir: pathlib.Path) -> dict[str, Any]:
    skill_md_path = skill_dir / "SKILL.md"
    markdown = read_text(skill_md_path) if skill_md_path.exists() else ""
    frontmatter = parse_frontmatter(markdown)
    skill_id = frontmatter.get("name") or skill_dir.name
    title = title_from_skill_id(skill_id)
    description = frontmatter.get("description", "")
    entrypoint = find_entrypoint(skill_dir, skill_id)
    hints = discover_extraction_hints(skill_dir, entrypoint)
    return {
        "schema": "sop-skill-contract/v1",
        "skill": {
            "id": skill_id,
            "title": title,
            "version": "1.0.0",
            "description": description,
        },
        "compatibility": {
            "sidecar": True,
            "required_by_skill_runtime": False,
            "consumed_by": ["sop-node-builder", "sop-a2a-runtime"],
        },
        "public_interface": {
            "input_model": "instruction+materials",
            "instruction_required": True,
            "materials_required": False,
            "accepted_materials": ["text", "url", "file", "json"],
        },
        "invoke": {
            "type": "agent_skill",
            "entrypoint_hint": entrypoint,
            "execution_mode": "agent_interpreted",
            "output_dir_env": "SOP_OUTPUT_DIR",
        },
        "adapter_hints": {
            "extraction": hints,
            "notes": [
                "Hints are internal adapter facts and must not be rendered as public Node inputs.",
                "The public Node interface remains instruction + materials.",
            ],
        },
        "outputs": {
            "mode": "manifest_artifacts",
            "root_env": "SOP_OUTPUT_DIR",
            "manifest": "manifest.json",
            "minimum_success": {
                "agent_task_completed": True,
                "output_dir_scanned": True,
                "manifest_written": True,
                "declared_artifacts_required": False,
            },
            "declared_artifacts": discover_declared_artifacts(skill_dir, entrypoint),
            "discovered_outputs": [],
        },
        "probe": infer_probe(markdown, hints),
        "security": {
            "secret_values_embedded": False,
            "required_env": discover_required_env(skill_dir, entrypoint),
            "required_secrets": [],
        },
        "generation": {
            "method": "deterministic-source-analysis",
            "source_files": [str(path.relative_to(skill_dir)) for path in relevant_source_files(skill_dir, entrypoint)],
        },
    }


def validate_contract(contract: dict[str, Any]) -> list[str]:
    errors: list[str] = []
    if contract.get("schema") != "sop-skill-contract/v1":
        errors.append("schema must be sop-skill-contract/v1")
    if not contract.get("skill", {}).get("id"):
        errors.append("skill.id is required")
    if contract.get("public_interface", {}).get("input_model") != "instruction+materials":
        errors.append("public_interface.input_model must be instruction+materials")
    if contract.get("compatibility", {}).get("required_by_skill_runtime") is not False:
        errors.append("compatibility.required_by_skill_runtime must be false")
    if contract.get("outputs", {}).get("mode") != "manifest_artifacts":
        errors.append("outputs.mode must be manifest_artifacts")
    if contract.get("outputs", {}).get("minimum_success", {}).get("declared_artifacts_required") is not False:
        errors.append("outputs.minimum_success.declared_artifacts_required must be false")
    for artifact in contract.get("outputs", {}).get("declared_artifacts", []):
        if artifact.get("required") is not False:
            errors.append(f"declared artifact {artifact.get('name')} must have required=false")
    for hint in contract.get("adapter_hints", {}).get("extraction", []):
        if hint.get("expose_to_node_user") is not False:
            errors.append(f"adapter hint {hint.get('name')} must not be exposed as public Node input")
    if contract.get("security", {}).get("secret_values_embedded") is not False:
        errors.append("security.secret_values_embedded must be false")
    return errors


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("skill_dir")
    parser.add_argument("--write", action="store_true")
    parser.add_argument("--output")
    parser.add_argument("--validate-only", action="store_true")
    args = parser.parse_args()

    skill_dir = pathlib.Path(args.skill_dir).expanduser().resolve()
    if not skill_dir.is_dir():
        raise SystemExit(f"skill directory not found: {skill_dir}")

    contract_path = pathlib.Path(args.output) if args.output else skill_dir / OUTPUT_NAME
    if args.validate_only:
        contract = json.loads(read_text(contract_path))
    else:
        contract = build_contract(skill_dir)

    errors = validate_contract(contract)
    if errors:
        raise SystemExit("contract validation failed:\n- " + "\n- ".join(errors))

    if args.validate_only:
        print(f"SOP_SKILL_CONTRACT_VALID={contract_path}")
        return

    encoded = json.dumps(contract, ensure_ascii=False, indent=2) + "\n"
    if args.write or args.output:
        contract_path.parent.mkdir(parents=True, exist_ok=True)
        contract_path.write_text(encoded, encoding="utf-8")
        print(f"SOP_SKILL_CONTRACT={contract_path}")
    else:
        print(encoded, end="")


if __name__ == "__main__":
    main()
