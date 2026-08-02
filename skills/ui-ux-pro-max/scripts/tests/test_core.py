#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Stdlib-only regression tests for core.py / design_system.py (unittest, not
pytest -- this project ships with zero external dependencies and the tests
shouldn't add one).

Run with:
    python -B -m unittest discover -s scripts/tests -v
or directly:
    python -B scripts/tests/test_core.py
"""

import io
import runpy
import shutil
import subprocess
import sys
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from pathlib import Path
from unittest.mock import patch

SCRIPTS_DIR = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(SCRIPTS_DIR))

import core
from core import BM25, detect_domain, search, search_stack, CSV_CONFIG, AVAILABLE_STACKS
from design_system import generate_design_system, persist_design_system, DesignSystemGenerator


class TestBytecodeHygiene(unittest.TestCase):
    def test_entrypoints_do_not_mutate_the_vendored_tree(self):
        with tempfile.TemporaryDirectory() as tmp:
            skill_root = Path(tmp) / "ui-ux-pro-max"
            shutil.copytree(SCRIPTS_DIR.parent, skill_root)

            commands = (
                [sys.executable, str(skill_root / "scripts" / "search.py"), "--help"],
                [sys.executable, str(skill_root / "scripts" / "design_system.py"), "--help"],
                [sys.executable, str(skill_root / "scripts" / "validate_data.py")],
            )
            for command in commands:
                result = subprocess.run(command, cwd=skill_root, capture_output=True, text=True)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(list(skill_root.rglob("__pycache__")), [])


class TestTokenizer(unittest.TestCase):
    def test_short_domain_terms_are_kept(self):
        bm25 = BM25()
        tokens = bm25.tokenize("UI and UX design with 3D and AI")
        self.assertIn("ui", tokens)
        self.assertIn("3d", tokens)
        self.assertIn("ai", tokens)

    def test_stopwords_removed(self):
        bm25 = BM25()
        tokens = bm25.tokenize("this is for the team to do")
        for stopword in ("is", "for", "the", "to", "do"):
            self.assertNotIn(stopword, tokens)

    def test_synonym_normalization(self):
        bm25 = BM25()
        self.assertEqual(bm25.tokenize("e-commerce store"), bm25.tokenize("ecommerce store"))
        self.assertEqual(bm25.tokenize("dark-mode toggle"), bm25.tokenize("dark toggle"))


class TestSearchDomains(unittest.TestCase):
    """Known query -> expected top-domain sanity checks (not exact-row pinning,
    since data can grow; these assert the engine still finds *something*
    relevant for each domain's core vocabulary)."""

    def test_ui_is_searchable_in_style_domain(self):
        result = search("ui minimalism", domain="style", max_results=1)
        self.assertGreater(result["count"], 0, "literal 'ui' token must be searchable, not filtered by tokenizer")

    def test_accessibility_query_hits_ux(self):
        result = search("accessibility contrast wcag keyboard", domain="ux", max_results=3)
        self.assertGreater(result["count"], 0)

    def test_zero_result_query_reports_suggestions_not_error(self):
        result = search("zzqqxx totally made up gibberish", domain="ux", max_results=2)
        self.assertEqual(result["count"], 0)
        self.assertIn("suggestions", result)
        self.assertNotIn("error", result)

    def test_every_configured_domain_file_exists_and_is_searchable(self):
        for domain, config in CSV_CONFIG.items():
            with self.subTest(domain=domain):
                result = search("design", domain=domain, max_results=1)
                self.assertNotIn("error", result, f"domain '{domain}' failed: {result.get('error')}")

    def test_every_stack_file_exists_and_is_searchable(self):
        for stack in AVAILABLE_STACKS:
            with self.subTest(stack=stack):
                result = search_stack("performance", stack, max_results=1)
                self.assertNotIn("error", result, f"stack '{stack}' failed: {result.get('error')}")

    def test_corrupt_csv_returns_an_error(self):
        with tempfile.TemporaryDirectory() as tmp:
            (Path(tmp) / CSV_CONFIG["style"]["file"]).write_bytes(b"\xff\xfe")
            with patch.object(core, "DATA_DIR", Path(tmp)):
                result = search("minimal", domain="style", max_results=1)
            self.assertIn("error", result)

    def test_non_positive_result_limits_are_rejected(self):
        for limit in (0, -1):
            with self.subTest(limit=limit):
                with self.assertRaises(ValueError):
                    search("minimal", domain="style", max_results=limit)
                with self.assertRaises(ValueError):
                    search_stack("performance", "react", max_results=limit)


class TestDomainDetection(unittest.TestCase):
    def test_style_keywords_route_to_style(self):
        self.assertEqual(detect_domain("glassmorphism dark ui"), "style")

    def test_accessibility_keywords_route_to_ux(self):
        self.assertEqual(detect_domain("accessibility contrast wcag"), "ux")

    def test_ambiguous_query_returns_runner_up(self):
        domain, runner_up = detect_domain("font pairing elegant crypto", return_scores=True)
        self.assertIsNotNone(domain)
        # runner_up may be None if the winning domain has no close second --
        # this just verifies the call shape works without raising.

    def test_empty_query_falls_back_to_style(self):
        self.assertEqual(detect_domain("...!!!???"), "style")


class TestCliErrors(unittest.TestCase):
    def test_domain_and_stack_errors_exit_nonzero(self):
        cases = (
            (["search.py", "query", "--domain", "style"], "search"),
            (["search.py", "query", "--stack", "react"], "search_stack"),
        )
        for argv, function_name in cases:
            with self.subTest(function=function_name):
                with patch.object(core, function_name, return_value={"error": "broken data"}), \
                     patch.object(sys, "argv", argv), \
                     redirect_stdout(io.StringIO()), redirect_stderr(io.StringIO()):
                    with self.assertRaises(SystemExit) as raised:
                        runpy.run_path(str(SCRIPTS_DIR / "search.py"), run_name="__main__")
                self.assertNotEqual(raised.exception.code, 0)


class TestPersistence(unittest.TestCase):
    def test_persist_then_skip_then_force(self):
        with tempfile.TemporaryDirectory() as tmp:
            result = generate_design_system("saas dashboard", "Test Project", persist=True, output_dir=tmp)
            self.assertEqual(result["persistence"]["status"], "success")
            master = Path(result["persistence"]["master_file"])
            self.assertTrue(master.exists())
            original_content = master.read_text(encoding="utf-8")

            # Second persist without force must not overwrite.
            result2 = generate_design_system("saas dashboard", "Test Project", persist=True, output_dir=tmp)
            self.assertEqual(result2["persistence"]["status"], "skipped_exists")
            self.assertEqual(master.read_text(encoding="utf-8"), original_content)

            # With force=True it must overwrite.
            result3 = generate_design_system("ecommerce luxury", "Test Project", persist=True, output_dir=tmp, force=True)
            self.assertEqual(result3["persistence"]["status"], "success")

    def test_persist_writes_only_under_output_dir(self):
        with tempfile.TemporaryDirectory() as tmp:
            generate_design_system("saas dashboard", "Scoped Project", persist=True, output_dir=tmp)
            expected = Path(tmp) / "design-system" / "scoped-project" / "MASTER.md"
            self.assertTrue(expected.exists())

    def test_persist_rejects_symlinked_page_file(self):
        with tempfile.TemporaryDirectory() as tmp:
            outside = Path(tmp) / "outside.md"
            outside.write_text("keep me", encoding="utf-8")
            pages = Path(tmp) / "design-system" / "test-project" / "pages"
            pages.mkdir(parents=True)
            (pages / "dashboard.md").symlink_to(outside)

            with self.assertRaises(ValueError):
                generate_design_system(
                    "saas dashboard",
                    "Test Project",
                    persist=True,
                    page="dashboard",
                    output_dir=tmp,
                    force=True,
                )

            self.assertEqual(outside.read_text(encoding="utf-8"), "keep me")

    def test_persist_preserves_existing_page_and_writes_missing_master(self):
        with tempfile.TemporaryDirectory() as tmp:
            page = Path(tmp) / "design-system" / "test-project" / "pages" / "dashboard.md"
            page.parent.mkdir(parents=True)
            page.write_text("keep me", encoding="utf-8")

            result = generate_design_system(
                "saas dashboard",
                "Test Project",
                persist=True,
                page="dashboard",
                output_dir=tmp,
            )

            self.assertEqual(result["persistence"]["status"], "success")
            self.assertEqual(page.read_text(encoding="utf-8"), "keep me")
            self.assertTrue((page.parent.parent / "MASTER.md").exists())

    def test_existing_master_allows_new_page_without_force(self):
        with tempfile.TemporaryDirectory() as tmp:
            first = generate_design_system(
                "saas dashboard", "Test Project", persist=True, output_dir=tmp)
            master = Path(first["persistence"]["master_file"])
            original_master = master.read_text(encoding="utf-8")

            second = generate_design_system(
                "saas dashboard",
                "Test Project",
                persist=True,
                page="dashboard",
                output_dir=tmp,
            )

            self.assertEqual(second["persistence"]["status"], "success")
            page = master.parent / "pages" / "dashboard.md"
            self.assertTrue(page.exists())
            self.assertEqual(master.read_text(encoding="utf-8"), original_master)
            self.assertIn("`pages/[page-name].md`", original_master)
            self.assertIn("`../MASTER.md`", page.read_text(encoding="utf-8"))

    def test_design_system_search_error_is_not_replaced_by_defaults(self):
        with patch("design_system.search", return_value={"error": "broken data"}):
            with self.assertRaisesRegex(RuntimeError, "broken data"):
                generate_design_system("saas dashboard", "Test Project")


class TestReasoningMatch(unittest.TestCase):
    def test_known_category_matches_exactly(self):
        gen = DesignSystemGenerator()
        rule = gen._find_reasoning_rule("SaaS (General)")
        self.assertTrue(rule, "exact-match category lookup should not fall through to fuzzy matching")

    def test_unknown_category_falls_back_gracefully(self):
        gen = DesignSystemGenerator()
        rule = gen._find_reasoning_rule("Totally Unknown Category XYZ")
        # Should not raise; may return {} which _apply_reasoning handles with defaults.
        self.assertIsInstance(rule, dict)


if __name__ == "__main__":
    unittest.main()
