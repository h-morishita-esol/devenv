from __future__ import annotations

import os
import stat
import subprocess
import tempfile
import textwrap
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
DEVENV_SOURCE = REPO_ROOT / ".devenv"


class DevenvIntegrationTest(unittest.TestCase):
    def setUp(self) -> None:
        self._tmpdir = tempfile.TemporaryDirectory(prefix="devenv-test-")
        self.project_root = Path(self._tmpdir.name) / "project"
        self.project_root.mkdir()
        (self.project_root / ".devenv").symlink_to(DEVENV_SOURCE)

    def tearDown(self) -> None:
        self._tmpdir.cleanup()

    def run_project_command(
        self,
        args: list[str],
        *,
        env: dict[str, str] | None = None,
        check: bool = False,
    ) -> subprocess.CompletedProcess[str]:
        merged_env = os.environ.copy()
        if env:
            merged_env.update(env)
        return subprocess.run(
            args,
            cwd=self.project_root,
            env=merged_env,
            text=True,
            capture_output=True,
            check=check,
        )

    def write_file(self, relative_path: str, content: str) -> Path:
        target = self.project_root / relative_path
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(content, encoding="utf-8")
        return target

    def test_setup_requires_devenvrc(self) -> None:
        result = self.run_project_command(["bash", "./.devenv/setup.sh"])

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("cp ./.devenv/template/.devenvrc ./.devenvrc", result.stderr)
        self.assertFalse((self.project_root / ".devenvrc").exists())

    def test_setup_updates_gitignore_without_calling_direnv(self) -> None:
        self.write_file(
            ".devenvrc",
            textwrap.dedent(
                """
                [codex]
                codex_home_relative = ".codex"

                [clangd]
                enable = false

                [serena]
                enable = false
                """
            ).strip()
            + "\n",
        )
        codex_bin = self.project_root / ".codex" / "node_modules" / ".bin" / "codex"
        codex_bin.parent.mkdir(parents=True, exist_ok=True)
        codex_bin.write_text("#!/usr/bin/env bash\nexit 0\n", encoding="utf-8")
        codex_bin.chmod(codex_bin.stat().st_mode | stat.S_IXUSR)

        fake_bin = self.project_root / "fake-bin"
        fake_bin.mkdir()
        direnv_log = self.project_root / "direnv-called.log"
        fake_direnv = fake_bin / "direnv"
        fake_direnv.write_text(
            f"#!/usr/bin/env bash\nprintf called > {direnv_log}\nexit 0\n",
            encoding="utf-8",
        )
        fake_direnv.chmod(fake_direnv.stat().st_mode | stat.S_IXUSR)
        fake_uv = fake_bin / "uv"
        fake_uv.write_text("#!/usr/bin/env bash\nexit 0\n", encoding="utf-8")
        fake_uv.chmod(fake_uv.stat().st_mode | stat.S_IXUSR)

        result = self.run_project_command(
            ["bash", "./.devenv/setup.sh"],
            env={
                "PATH": f"{fake_bin}:{os.environ['PATH']}",
                "CODEX_INSTALL_SCOPE": "local",
                "HOME": str(self.project_root / "home"),
            },
        )

        self.assertEqual(result.returncode, 0, msg=result.stderr)
        self.assertTrue((self.project_root / ".envrc").is_symlink())
        gitignore = (self.project_root / ".gitignore").read_text(encoding="utf-8")
        self.assertIn(".devenvrc", gitignore)
        self.assertFalse(direnv_log.exists())

    def test_run_exports_codex_home_from_devenvrc(self) -> None:
        self.write_file(
            ".devenvrc",
            textwrap.dedent(
                """
                [codex]
                codex_home_relative = ".cache/codex-home"

                [clangd]
                enable = false

                [serena]
                enable = false
                """
            ).strip()
            + "\n",
        )

        result = self.run_project_command(
            [
                "bash",
                "-lc",
                "source ./.devenv/run.sh && printf '%s\\n%s\\n' \"$CODEX_HOME_RELATIVE\" \"$CODEX_HOME\"",
            ]
        )

        self.assertEqual(result.returncode, 0, msg=result.stderr)
        lines = result.stdout.strip().splitlines()
        self.assertEqual(lines[0], ".cache/codex-home")
        self.assertEqual(lines[1], str(self.project_root / ".cache" / "codex-home"))

    def test_serena_script_uses_project_root_with_symlinked_devenv(self) -> None:
        self.write_file(
            ".devenvrc",
            textwrap.dedent(
                """
                [serena]
                enable = true
                ignored_paths = ["build/generated", "vendor/cache"]
                """
            ).strip()
            + "\n",
        )
        project_yml = self.write_file(".serena/project.yml", "name: demo\nignored_paths: []\n")

        result = self.run_project_command(
            [
                "python3",
                "./.devenv/serena/update_serena_config.py",
                "--project-root",
                str(self.project_root),
            ]
        )

        self.assertEqual(result.returncode, 0, msg=result.stderr)
        updated = project_yml.read_text(encoding="utf-8")
        self.assertIn('- "build/generated"', updated)
        self.assertIn('- "vendor/cache"', updated)
        self.assertFalse((REPO_ROOT / ".serena" / "project.yml").exists())

    def test_clangd_generator_uses_project_root_with_symlinked_devenv(self) -> None:
        self.write_file(
            ".devenvrc",
            textwrap.dedent(
                """
                [clangd]
                enable = true
                exclude_path = []
                background_skip_path = ["third_party/lib"]
                """
            ).strip()
            + "\n",
        )
        source_file = self.write_file("src/main.c", "int main(void) { return 0; }\n")
        compile_commands = textwrap.dedent(
            f"""
            [
              {{
                "directory": "{self.project_root / 'build'}",
                "file": "{source_file}",
                "command": "cc -c {source_file}"
              }}
            ]
            """
        ).strip()
        self.write_file("build/compile_commands.json", compile_commands + "\n")

        result = self.run_project_command(
            [
                "python3",
                "./.devenv/clangd/generate_clangd.py",
                "--project-root",
                str(self.project_root),
            ]
        )

        self.assertEqual(result.returncode, 0, msg=result.stderr)
        generated = (self.project_root / ".clangd").read_text(encoding="utf-8")
        self.assertIn("CompilationDatabase: build", generated)
        self.assertIn("PathMatch: ^.*", generated)
        self.assertIn("Background: Skip", generated)


if __name__ == "__main__":
    unittest.main()
