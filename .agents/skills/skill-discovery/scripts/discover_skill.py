#!/usr/bin/env python3
"""Simple local skill discovery for Sojourn project skills."""

from __future__ import annotations

import argparse
import re
from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True)
class Skill:
    name: str
    description: str
    path: Path
    content: str


def parse_frontmatter(content: str) -> tuple[str, str]:
    if not content.startswith("---"):
        return ("unknown", "")
    _, frontmatter, _ = content.split("---", 2)
    name = "unknown"
    description = ""
    for line in frontmatter.splitlines():
        if line.startswith("name:"):
            name = line.split(":", 1)[1].strip().strip("'\"")
        elif line.startswith("description:"):
            description = line.split(":", 1)[1].strip().strip("'\"")
    return (name, description)


def words(value: str) -> set[str]:
    return {token for token in re.split(r"[^a-z0-9]+", value.lower()) if len(token) >= 3}


def load_skills(root: Path) -> list[Skill]:
    skills: list[Skill] = []
    for skill_file in sorted(root.glob("*/SKILL.md")):
        content = skill_file.read_text(encoding="utf-8")
        name, description = parse_frontmatter(content)
        skills.append(Skill(name=name, description=description, path=skill_file, content=content))
    return skills


def score(query: set[str], skill: Skill) -> int:
    searchable = words(f"{skill.name} {skill.description}")
    return len(query & searchable)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("query")
    parser.add_argument("--auto-load", action="store_true")
    args = parser.parse_args()

    root = Path(__file__).resolve().parents[1]
    query_words = words(args.query)
    ranked = sorted(
        ((score(query_words, skill), skill) for skill in load_skills(root)),
        key=lambda item: (-item[0], item[1].name),
    )
    ranked = [item for item in ranked if item[0] > 0]

    if not ranked:
        print("## Skill Discovery\n\nNo matching local Sojourn skill found.")
        return 0

    best_score, best = ranked[0]
    confidence = min(95, 45 + best_score * 15)

    if args.auto_load:
        print(f"======================================")
        print(f"SKILL LOADED: {best.name}")
        print(f"Path: {best.path}")
        print(f"Confidence: {confidence}%")
        print(f"======================================")
        print(best.content)
        print(f"======================================")
        return 0

    print("## Skill Discovery")
    print()
    print(f"I found a local Sojourn skill that matches this task:")
    print(f"**{best.name}** (confidence: {confidence}%)")
    print(f"> {best.description}")
    print()
    print(f"Load it with:")
    print(f"`python3 {Path(__file__).name} \"{args.query}\" --auto-load`")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
