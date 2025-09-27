#!/usr/bin/env python3
"""LightRAG check template system helper.

This utility provides management and generation capabilities for the
LightRAG check templates used by the configuration verification suite.

Feature highlights (aligned with specs/check-template-system-spec.md):
- List, validate, and update template definitions
- Generate new check scripts from natural language descriptions
- Enforce GIVEN/WHEN/THEN structure and naming conventions
- Support Bash, PowerShell, and CMD script types
"""

from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, Iterable, List, Optional, Tuple

SCRIPT_DIR = Path(__file__).resolve().parent
TESTS_DIR = SCRIPT_DIR.parent
TEMPLATES_DIR = TESTS_DIR / "templates"
REGISTRY_PATH = TEMPLATES_DIR / "registry.json"
CHECKS_DIR = TESTS_DIR / "checks"

VALID_GROUPS = [
    "security",
    "storage",
    "communication",
    "environment",
    "monitoring",
    "performance",
    "wsl2",
]

SCRIPT_TYPE_EXT = {
    "bash": "sh",
    "powershell": "ps1",
    "cmd": "cmd",
}

PLACEHOLDERS_REQUIRED = {"TITLE", "GIVEN", "WHEN", "THEN", "CHECK_ID", "COMMAND_HINT"}


class TemplateError(Exception):
    """Custom error for template operations."""


@dataclass
class Template:
    template_id: str
    label: str
    description: str
    script_type: str
    extension: str
    path: Path
    categories: List[str]
    placeholders: List[str]

    @classmethod
    def from_registry(cls, base_dir: Path, data: Dict[str, object]) -> "Template":
        try:
            template_id = str(data["id"])
            label = str(data.get("label", template_id))
            description = str(data.get("description", ""))
            script_type = str(data["script_type"])
            extension = str(data["extension"])
            rel_path = Path(str(data["path"]))
            categories = [str(item) for item in data.get("categories", [])]
            placeholders = [str(item) for item in data.get("placeholders", [])]
        except KeyError as exc:  # pragma: no cover - defensive, covered via validation
            raise TemplateError(f"Template registry entry missing required field: {exc}") from exc

        return cls(
            template_id=template_id,
            label=label,
            description=description,
            script_type=script_type,
            extension=extension,
            path=(base_dir / rel_path).resolve(),
            categories=categories,
            placeholders=placeholders,
        )

    def validate(self) -> List[str]:
        problems: List[str] = []

        if self.script_type not in SCRIPT_TYPE_EXT:
            problems.append(
                f"Template {self.template_id} specifies unsupported script_type '{self.script_type}'"
            )
        elif SCRIPT_TYPE_EXT[self.script_type] != self.extension:
            problems.append(
                f"Template {self.template_id} extension mismatch: expected '{SCRIPT_TYPE_EXT[self.script_type]}', "
                f"found '{self.extension}'"
            )

        if not self.path.exists():
            problems.append(f"Template file missing: {self.path}")
        else:
            content = self.path.read_text(encoding="utf-8")
            missing_placeholders = PLACEHOLDERS_REQUIRED.difference(self.placeholders)
            if missing_placeholders:
                problems.append(
                    f"Template {self.template_id} registry placeholders missing required entries: "
                    + ", ".join(sorted(missing_placeholders))
                )

            for placeholder in PLACEHOLDERS_REQUIRED:
                if placeholder not in self.placeholders:
                    continue
                if f"{{{{{placeholder}}}}}" not in content:
                    problems.append(
                        f"Template {self.template_id} missing placeholder '{{{{{placeholder}}}}}' in file"
                    )

            # Ensure GIVEN/WHEN/THEN context is present in content for enforcement
            if "GIVEN" not in content or "WHEN" not in content or "THEN" not in content:
                problems.append(
                    f"Template {self.template_id} does not include GIVEN/WHEN/THEN guidance"
                )

        unknown_categories = [cat for cat in self.categories if cat not in VALID_GROUPS]
        if unknown_categories:
            problems.append(
                f"Template {self.template_id} lists unsupported categories: {', '.join(unknown_categories)}"
            )

        return problems


def load_registry(path: Path = REGISTRY_PATH) -> Tuple[int, List[Template]]:
    if not path.exists():
        raise TemplateError(f"Template registry not found: {path}")

    data = json.loads(path.read_text(encoding="utf-8"))
    version = int(data.get("version", 1))
    templates = [Template.from_registry(TEMPLATES_DIR, item) for item in data.get("templates", [])]
    return version, templates


def slugify(value: str) -> str:
    value = value.strip().lower()
    value = re.sub(r"[^a-z0-9]+", "-", value)
    value = re.sub(r"-+", "-", value)
    return value.strip("-")


def title_case(*parts: str) -> str:
    clean_parts = [part for part in parts if part]
    return " ".join(segment.capitalize() for segment in clean_parts)


def parse_tdd_sections(description: str) -> Dict[str, str]:
    pattern = re.compile(r"\b(GIVEN|WHEN|THEN)\b", re.IGNORECASE)
    parts = pattern.split(description)
    tdd: Dict[str, str] = {}

    if len(parts) <= 1:
        return tdd

    # parts will look like ['', 'GIVEN', ' ... ', 'WHEN', ' ...']
    iterator = iter(parts)
    first = next(iterator)
    for keyword, text in zip(iterator, iterator):
        key = keyword.strip().upper()
        value = text.strip().strip(" :.-")
        if value:
            tdd[key] = value

    return tdd


def infer_group(description: str) -> Optional[str]:
    for group in VALID_GROUPS:
        if re.search(rf"\b{re.escape(group)}\b", description, re.IGNORECASE):
            return group
    return None


def infer_service_and_test(description: str, *, group: Optional[str]) -> Tuple[Optional[str], Optional[str]]:
    # Remove TDD guidance to focus on summary statement
    summary = description.split("Given", 1)[0]
    summary = summary.split("GIVEN", 1)[0]

    service: Optional[str] = None
    test_name: Optional[str] = None

    # Pattern 1: "for redis authentication"
    match = re.search(
        r"\bfor\s+([a-z0-9][a-z0-9-_/ ]+?)\s+(?:check|test|validation|integration|script)\b",
        summary,
        re.IGNORECASE,
    )
    if match:
        words = match.group(1).strip().split()
        if words:
            service = slugify(words[0])
        if len(words) > 1:
            test_name = slugify(" ".join(words[1:]))

    if not service:
        # Pattern 2: group + service ("security redis authentication")
        if group:
            match = re.search(
                rf"\b{re.escape(group)}\s+([a-z0-9][a-z0-9-_/]+)(?:\s+([a-z0-9][a-z0-9-_/]+))?",
                summary,
                re.IGNORECASE,
            )
            if match:
                service = slugify(match.group(1))
                if match.group(2):
                    test_name = slugify(match.group(2))

    if not service:
        # Fallback: word after "for"
        match = re.search(r"\bfor\s+([a-z0-9][a-z0-9-_/]+)", summary, re.IGNORECASE)
        if match:
            service = slugify(match.group(1))

    if not test_name:
        # Look for verbs like "ensure", "verify" to derive test name
        match = re.search(
            r"\b(ensure|verify|validate|confirm|check)\s+([a-z0-9][a-z0-9-_/ ]+)",
            summary,
            re.IGNORECASE,
        )
        if match:
            test_name = slugify(match.group(2))

    if service and not test_name:
        # Use first distinctive word after service
        pattern = re.compile(rf"\b{re.escape(service)}\b\s+([a-z0-9][a-z0-9-_/]+)", re.IGNORECASE)
        match = pattern.search(summary)
        if match:
            candidate = slugify(match.group(1))
            if candidate and candidate != service:
                test_name = candidate

    return service, test_name


def ensure_group(value: Optional[str], *, interactive: bool) -> str:
    if value:
        normalized = slugify(value)
        if normalized not in VALID_GROUPS:
            raise TemplateError(
                f"Unsupported group '{value}'. Allowed values: {', '.join(VALID_GROUPS)}"
            )
        return normalized

    if not interactive:
        raise TemplateError(
            "Could not infer group from description. Provide --group or use --interactive mode."
        )

    while True:
        entered = input(f"Select group ({', '.join(VALID_GROUPS)}): ").strip().lower()
        if entered in VALID_GROUPS:
            return entered
        print("Invalid group. Please choose one of the supported categories.")


def ensure_value(prompt: str, value: Optional[str], *, interactive: bool) -> str:
    if value:
        return slugify(value)
    if not interactive:
        raise TemplateError(
            f"Could not infer {prompt.lower()} from description. Provide --{prompt.lower()} or use --interactive mode."
        )
    while True:
        entered = input(f"Enter {prompt}: ").strip()
        candidate = slugify(entered)
        if candidate:
            return candidate
        print("Value cannot be empty.")


def ensure_template(
    templates: Iterable[Template],
    *,
    template_id: Optional[str],
    script_type: Optional[str],
) -> Template:
    candidates = list(templates)
    if template_id:
        for template in candidates:
            if template.template_id == template_id:
                return template
        raise TemplateError(f"Unknown template id '{template_id}'. Use the list command to inspect options.")

    if script_type:
        matching = [template for template in candidates if template.script_type == script_type]
        if not matching:
            raise TemplateError(
                f"No templates available for script type '{script_type}'. Use the list command to confirm options."
            )
        return matching[0]

    raise TemplateError("A template must be specified via --template-id or --script-type.")


def render_template(template_path: Path, context: Dict[str, str]) -> str:
    content = template_path.read_text(encoding="utf-8")
    for key, value in context.items():
        placeholder = f"{{{{{key}}}}}"
        content = content.replace(placeholder, value)
    return content


def derive_command_hint(script_type: str) -> str:
    if script_type == "bash":
        return "replace_with_command"
    if script_type == "powershell":
        return "Replace-With-Command"
    return "REPLACE_WITH_COMMAND"


def ensure_unique_path(path: Path, *, force: bool) -> None:
    if path.exists() and not force:
        raise TemplateError(
            f"Target check '{path}' already exists. Use --force to overwrite or choose a different name."
        )


def write_file(path: Path, content: str, *, executable: bool) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")
    if executable:
        mode = path.stat().st_mode
        path.chmod(mode | 0o111)


def list_templates_action() -> int:
    version, templates = load_registry()
    print(f"Template registry version: {version}")
    for template in templates:
        categories = ", ".join(template.categories) if template.categories else "(all)"
        print(f"\nID: {template.template_id}")
        print(f"  Label      : {template.label}")
        if template.description:
            print(f"  Description: {template.description}")
        print(f"  Script Type: {template.script_type} (.{template.extension})")
        try:
            path_display = template.path.relative_to(Path.cwd())
        except ValueError:
            path_display = template.path
        print(f"  Path       : {path_display}")
        print(f"  Categories : {categories}")
        print(f"  Placeholders: {', '.join(template.placeholders)}")
    return 0


def validate_templates_action() -> int:
    _, templates = load_registry()
    had_issue = False
    for template in templates:
        problems = template.validate()
        if problems:
            had_issue = True
            print(f"Template {template.template_id} issues:")
            for issue in problems:
                print(f"  - {issue}")
        else:
            print(f"Template {template.template_id}: OK")

    if had_issue:
        return 1
    print("All templates validated successfully.")
    return 0


def update_template_action(template_id: str, source: Path) -> int:
    _, templates = load_registry()
    for template in templates:
        if template.template_id == template_id:
            target = template.path
            if not source.exists():
                raise TemplateError(f"Source file not found: {source}")
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source, target)
            print(f"Updated template {template_id} from {source}.")
            return 0
    raise TemplateError(f"Template '{template_id}' not found in registry.")


def generate_action(args: argparse.Namespace) -> int:
    description = (args.description or "").strip()
    if not description:
        raise TemplateError("--description is required for generate command.")

    tdd = parse_tdd_sections(description)
    missing_sections = [section for section in ("GIVEN", "WHEN", "THEN") if section not in tdd]
    if missing_sections and not args.interactive:
        raise TemplateError(
            "Description must include GIVEN, WHEN, and THEN sections. "
            "Use --interactive to provide them manually if missing."
        )

    if missing_sections and args.interactive:
        for section in missing_sections:
            value = input(f"Provide {section.title()} section: ").strip()
            if not value:
                raise TemplateError(f"{section.title()} section cannot be blank.")
            tdd[section] = value

    group = ensure_group(args.group or infer_group(description), interactive=args.interactive)

    inferred_service, inferred_test = infer_service_and_test(description, group=group)
    service = ensure_value("service", args.service or inferred_service, interactive=args.interactive)
    test_name = ensure_value("test", args.test or inferred_test, interactive=args.interactive)

    templates_version, templates = load_registry()
    template = ensure_template(templates, template_id=args.template_id, script_type=args.script_type)

    if group not in template.categories and template.categories:
        raise TemplateError(
            f"Template '{template.template_id}' does not support group '{group}'. "
            f"Supported: {', '.join(template.categories)}"
        )

    check_id = f"{group}_{service}_{test_name}"
    filename = f"{group}-{service}-{test_name}.{template.extension}"
    output_dir = Path(args.output_dir or CHECKS_DIR).resolve()
    target_path = output_dir / filename

    ensure_unique_path(target_path, force=args.force)

    title = title_case(group, service, test_name)

    context = {
        "TITLE": title,
        "GIVEN": tdd["GIVEN"],
        "WHEN": tdd["WHEN"],
        "THEN": tdd["THEN"],
        "CHECK_ID": check_id,
        "COMMAND_HINT": derive_command_hint(template.script_type),
    }

    rendered = render_template(template.path, context)

    if args.dry_run:
        print(rendered)
        return 0

    write_file(target_path, rendered, executable=(template.extension == "sh"))

    metadata = {
        "registry_version": templates_version,
        "template_id": template.template_id,
        "script_type": template.script_type,
        "group": group,
        "service": service,
        "test": test_name,
        "check_id": check_id,
        "file": str(target_path.relative_to(Path.cwd())),
    }

    if args.json:
        json.dump(metadata, sys.stdout, indent=2)
        sys.stdout.write("\n")
    else:
        print(f"Generated check: {metadata['file']}")
        print(f"  Template : {template.template_id}")
        print(f"  Group    : {group}")
        print(f"  Service  : {service}")
        print(f"  Test     : {test_name}")
        print("  Reminder : Update the placeholder logic before running the orchestrator.")

    if args.metadata:
        metadata_path = Path(args.metadata).resolve()
        metadata_path.parent.mkdir(parents=True, exist_ok=True)
        metadata_path.write_text(json.dumps(metadata, indent=2), encoding="utf-8")

    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Manage LightRAG check templates")
    subparsers = parser.add_subparsers(dest="command", required=True)

    subparsers.add_parser("list", help="List available templates")
    subparsers.add_parser("validate", help="Validate template integrity")

    update_parser = subparsers.add_parser("update", help="Update template content from a source file")
    update_parser.add_argument("template_id", help="Template identifier to update")
    update_parser.add_argument("source", help="Source file with new template content")

    generate_parser = subparsers.add_parser("generate", help="Generate a new check from a description")
    generate_parser.add_argument("--description", "-d", help="Natural language description containing GIVEN/WHEN/THEN")
    generate_parser.add_argument("--group", help="Override inferred group")
    generate_parser.add_argument("--service", help="Override inferred service name")
    generate_parser.add_argument("--test", dest="test", help="Override inferred test name")
    generate_parser.add_argument(
        "--script-type",
        choices=sorted(SCRIPT_TYPE_EXT.keys()),
        help="Preferred script type when template id is not specified",
    )
    generate_parser.add_argument("--template-id", help="Explicit template identifier to use")
    generate_parser.add_argument("--output-dir", help="Directory where the check should be created")
    generate_parser.add_argument("--interactive", action="store_true", help="Prompt for missing details")
    generate_parser.add_argument("--dry-run", action="store_true", help="Print generated script without writing")
    generate_parser.add_argument("--force", action="store_true", help="Overwrite existing check if present")
    generate_parser.add_argument("--json", action="store_true", help="Emit metadata as JSON to stdout")
    generate_parser.add_argument("--metadata", help="Optional path to store metadata JSON")

    return parser


def main(argv: Optional[List[str]] = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)

    try:
        if args.command == "list":
            return list_templates_action()
        if args.command == "validate":
            return validate_templates_action()
        if args.command == "update":
            source = Path(args.source).resolve()
            return update_template_action(args.template_id, source)
        if args.command == "generate":
            return generate_action(args)
    except TemplateError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1

    parser.error("Unhandled command")
    return 1


if __name__ == "__main__":  # pragma: no cover - script entry point
    sys.exit(main())
