#!/usr/bin/env python3
"""Validate the curated saint quiz catalogue against the bundled saints data."""

from __future__ import annotations

import json
import sys
import unicodedata
from pathlib import Path
from urllib.parse import urlparse


ROOT = Path(__file__).resolve().parents[1]
QUIZZES_PATH = ROOT / "Klimax" / "saint-quizzes.json"
SAINTS_PATH = ROOT / "Klimax" / "saints.json"


def search_key(value: str) -> str:
    decomposed = unicodedata.normalize("NFKD", value.casefold().replace("ς", "σ"))
    return "".join(character for character in decomposed if not unicodedata.combining(character))


def fail(message: str, errors: list[str]) -> None:
    errors.append(message)


def main() -> int:
    quizzes_document = json.loads(QUIZZES_PATH.read_text(encoding="utf-8"))
    saints_document = json.loads(SAINTS_PATH.read_text(encoding="utf-8"))
    errors: list[str] = []

    if quizzes_document.get("schemaVersion") != 1:
        fail("schemaVersion must be 1", errors)

    saints = {
        saint["id"]: saint
        for rank in saints_document.get("ranks", [])
        for saint in rank.get("saints", [])
    }
    portrait_saint_ids = {
        saint_id for saint_id, saint in saints.items() if (saint.get("icon") or "").strip()
    }

    quizzes = quizzes_document.get("quizzes")
    if not isinstance(quizzes, list):
        fail("quizzes must be an array", errors)
        quizzes = []

    seen_saint_ids: set[str] = set()
    seen_prompts: dict[str, str] = {}

    for quiz in quizzes:
        saint_id = quiz.get("saintID", "")
        label = saint_id or "<missing saintID>"

        if saint_id in seen_saint_ids:
            fail(f"{label}: duplicate quiz", errors)
        seen_saint_ids.add(saint_id)

        if saint_id not in saints:
            fail(f"{label}: saintID does not exist in saints.json", errors)

        source_urls = quiz.get("sourceUrls")
        if not isinstance(source_urls, list) or len(source_urls) < 2:
            fail(f"{label}: sourceUrls must contain at least two references", errors)
        else:
            if len(set(source_urls)) != len(source_urls):
                fail(f"{label}: sourceUrls must not contain duplicates", errors)
            for source_url in source_urls:
                parsed = urlparse(source_url) if isinstance(source_url, str) else None
                if parsed is None or parsed.scheme != "https" or not parsed.netloc:
                    fail(f"{label}: invalid HTTPS source URL {source_url!r}", errors)
                elif parsed.path in ("", "/"):
                    fail(f"{label}: source URL must link to a specific page {source_url!r}", errors)

        questions = quiz.get("questions")
        if not isinstance(questions, list) or len(questions) != 10:
            count = len(questions) if isinstance(questions, list) else "not an array"
            fail(f"{label}: expected 10 questions, found {count}", errors)
            continue

        if questions[0].get("topic") != "feast":
            fail(f"{label}: the first question must use the feast topic", errors)

        topics = [question.get("topic", "") for question in questions]
        if len(set(topics)) != len(topics):
            fail(f"{label}: question topics must be unique", errors)

        for index, question in enumerate(questions, start=1):
            prefix = f"{label} question {index}"
            for field in ("topic", "prompt", "correctAnswer", "explanation"):
                value = question.get(field)
                if not isinstance(value, str) or not value.strip():
                    fail(f"{prefix}: {field} must be non-empty text", errors)

            distractors = question.get("distractors")
            if not isinstance(distractors, list) or len(distractors) != 2:
                fail(f"{prefix}: expected exactly two distractors", errors)
                continue
            if not all(isinstance(value, str) and value.strip() for value in distractors):
                fail(f"{prefix}: distractors must be non-empty text", errors)

            answers = [question.get("correctAnswer", ""), *distractors]
            if len({search_key(answer.strip()) for answer in answers}) != 3:
                fail(f"{prefix}: correct answer and distractors must be distinct", errors)

            prompt = question.get("prompt", "").strip()
            prompt_key = search_key(prompt)
            if prompt_key in seen_prompts:
                fail(
                    f"{prefix}: duplicates a prompt from {seen_prompts[prompt_key]}",
                    errors,
                )
            else:
                seen_prompts[prompt_key] = prefix

    missing_portrait_quizzes = sorted(portrait_saint_ids - seen_saint_ids)
    unexpected_quizzes = sorted(seen_saint_ids - set(saints))
    if missing_portrait_quizzes:
        fail(
            "portrait saints missing quizzes: " + ", ".join(missing_portrait_quizzes),
            errors,
        )
    if unexpected_quizzes:
        fail("unknown saint quizzes: " + ", ".join(unexpected_quizzes), errors)

    if errors:
        print("Saint quiz validation failed:", file=sys.stderr)
        for error in errors:
            print(f"- {error}", file=sys.stderr)
        return 1

    question_count = sum(len(quiz["questions"]) for quiz in quizzes)
    print(
        f"Validated {len(quizzes)} saint quizzes and {question_count} questions; "
        f"all {len(portrait_saint_ids)} portrait saints are covered."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
