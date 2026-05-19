#!/usr/bin/env python3
#
# Validate an untrusted Cobertura XML coverage report before passing it to QLTY.
#

from __future__ import annotations

import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path


SIZE_LIMIT_BYTES = 10 * 1024 * 1024
UNSUPPORTED_DECLARATION = re.compile(br"<!ENTITY\b|<!ELEMENT\b", re.IGNORECASE)
DOCTYPE = re.compile(br"<!DOCTYPE\b.*?>", re.IGNORECASE | re.DOTALL)
EXPECTED_DOCTYPE = re.compile(
    br"""<!DOCTYPE\s+coverage\s+SYSTEM\s+(['"])http://cobertura\.sourceforge\.net/xml/coverage-04\.dtd\1\s*>""",
    re.IGNORECASE,
)


def fail(message: str) -> None:
    print(message, file=sys.stderr)
    raise SystemExit(1)


def validate_xml_declarations(cov_path: Path, xml: bytes) -> None:
    if UNSUPPORTED_DECLARATION.search(xml):
        fail(f"{cov_path} contains unsupported XML declarations")

    doctype_matches = list(DOCTYPE.finditer(xml))
    if not doctype_matches:
        return

    if len(doctype_matches) != 1 or not EXPECTED_DOCTYPE.fullmatch(doctype_matches[0].group(0)):
        fail(f"{cov_path} contains unsupported XML declarations")


def parse_coverage_root(cov_path: Path, xml: bytes) -> ET.Element:
    try:
        root = ET.fromstring(xml)
    except ET.ParseError as exc:
        fail(f"{cov_path} is not valid XML: {exc}")

    if root.tag.split("}", 1)[-1] != "coverage":
        fail(f"{cov_path} is not a Cobertura coverage report: expected root element coverage, got {root.tag}")

    return root


def require_attribute(cov_path: Path, root: ET.Element, attr_name: str) -> str:
    value = root.attrib.get(attr_name)
    if value is None or value == "":
        fail(f"{cov_path} is missing required coverage XML attribute {attr_name}")
    return value


def validate_rate(attr_name: str, value: str) -> None:
    try:
        rate = float(value)
    except ValueError as exc:
        raise SystemExit(f"coverage XML attribute {attr_name} must be numeric, got {value!r}") from exc

    if not 0.0 <= rate <= 1.0:
        fail(f"coverage XML attribute {attr_name} must be between 0.0 and 1.0, got {rate}")


def validate_count(attr_name: str, value: str) -> None:
    try:
        count = int(value)
    except ValueError as exc:
        raise SystemExit(f"coverage XML attribute {attr_name} must be an integer, got {value!r}") from exc

    if count < 0:
        fail(f"coverage XML attribute {attr_name} must be zero or greater, got {count}")


def main(argv: list[str]) -> int:
    if len(argv) != 2:
        fail("usage: validate-cobertura-xml.py <path-to-cov.xml>")

    cov_path = Path(argv[1])
    try:
        size = cov_path.stat().st_size
    except OSError as exc:
        fail(f"{cov_path} is not readable: {exc}")

    if size == 0:
        fail(f"{cov_path} is empty")

    if size > SIZE_LIMIT_BYTES:
        fail(f"{cov_path} exceeds the 10 MiB size limit")

    try:
        xml = cov_path.read_bytes()
    except OSError as exc:
        fail(f"{cov_path} is not readable: {exc}")

    validate_xml_declarations(cov_path, xml)
    root = parse_coverage_root(cov_path, xml)

    validate_rate("line-rate", require_attribute(cov_path, root, "line-rate"))
    validate_rate("branch-rate", require_attribute(cov_path, root, "branch-rate"))
    validate_count("lines-covered", require_attribute(cov_path, root, "lines-covered"))
    validate_count("lines-valid", require_attribute(cov_path, root, "lines-valid"))

    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
