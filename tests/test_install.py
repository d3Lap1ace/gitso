"""Exercise the installer offline, including preservation of an existing install."""
import hashlib
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class InstallerTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="gitso installer ")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.bin = self.root / "bin"
        self.bin.mkdir()
        # Deliberately expose no Go toolchain to the installer.
        for tool in ("sh", "mktemp", "awk", "grep", "chmod", "mkdir", "cp", "mv", "rm"):
            (self.bin / tool).symlink_to(shutil.which(tool))
        checksum = "sha256sum" if shutil.which("sha256sum") else "shasum"
        (self.bin / checksum).symlink_to(shutil.which(checksum))
        self.script("git", '#!/bin/sh\necho "git version fixture"\n')
        self.script("uname", '#!/bin/sh\ncase "$1" in -s) echo "${TEST_OS:-Linux}";; -m) echo "${TEST_ARCH:-x86_64}";; esac\n')
        self.script("curl", """#!/bin/sh
out= url= head=no
while [ "$#" -gt 0 ]; do
    case "$1" in
        -o) out=$2; shift 2 ;;
        -I) head=yes; shift ;;
        -w|--proto|--proto-redir|--connect-timeout|--max-time|--retry) shift 2 ;;
        https://*) url=$1; shift ;;
        *) shift ;;
    esac
done
printf '%s\n' "$url" >> "$TEST_LOG"
[ "${TEST_DOWNLOAD_FAIL:-no}" != yes ] || exit 22
if [ "$head" = yes ]; then
    printf 'https://github.com/d3Lap1ace/gitso/releases/tag/v1.2.3'
else
    cp "$TEST_FIXTURES/${url##*/}" "$out"
fi
""")
        self.fixtures = self.root / "fixtures"
        self.fixtures.mkdir()
        self.payload = b'#!/bin/sh\nexec git --version\n'
        for os_name in ("linux", "darwin"):
            for arch in ("amd64", "arm64"):
                (self.fixtures / f"gitso_{os_name}_{arch}").write_bytes(self.payload)
        digest = hashlib.sha256(self.payload).hexdigest()
        (self.fixtures / "checksums.txt").write_text("".join(
            f"{digest}  {p.name}\n" for p in self.fixtures.glob("gitso_*")
        ))
        self.target = self.root / "install with spaces" / "gitso"
        self.env = {
            **os.environ, "PATH": str(self.bin), "HOME": str(self.root),
            "GITSO_INSTALL_DIR": str(self.target.parent), "GITSO_VERSION": "latest",
            "TEST_FIXTURES": str(self.fixtures), "TEST_LOG": str(self.root / "requests"),
        }

    def script(self, name, content):
        p = self.bin / name
        p.write_text(content)
        p.chmod(0o755)

    def run_installer(self, **env):
        return subprocess.run(["/bin/sh", str(ROOT / "install.sh")], env={**self.env, **env}, capture_output=True, text=True)

    def existing_install(self):
        self.target.parent.mkdir()
        self.target.write_text("old binary")

    def test_install_and_repeat_without_go(self):
        for _ in range(2):
            result = self.run_installer()
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(self.target.read_bytes(), self.payload)
            self.assertTrue(os.access(self.target, os.X_OK))
        urls = (self.root / "requests").read_text().splitlines()
        self.assertIn("https://github.com/d3Lap1ace/gitso/releases/download/v1.2.3/gitso_linux_amd64", urls)
        self.assertFalse(list(self.target.parent.glob(".gitso.*")))

    def test_macos_arm64(self):
        result = self.run_installer(TEST_OS="Darwin", TEST_ARCH="arm64")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("gitso_darwin_arm64", (self.root / "requests").read_text())

    def test_pin_skips_latest_lookup(self):
        result = self.run_installer(GITSO_VERSION="v2.0.0")
        self.assertEqual(result.returncode, 0, result.stderr)
        urls = (self.root / "requests").read_text()
        self.assertNotIn("/releases/latest", urls)
        self.assertIn("/download/v2.0.0/", urls)

    def test_bad_checksum_preserves_existing(self):
        self.existing_install()
        (self.fixtures / "gitso_linux_amd64").write_text("corrupt")
        self.assertNotEqual(self.run_installer().returncode, 0)
        self.assertEqual(self.target.read_text(), "old binary")

    def test_download_failure_preserves_existing(self):
        self.existing_install()
        self.assertNotEqual(self.run_installer(TEST_DOWNLOAD_FAIL="yes").returncode, 0)
        self.assertEqual(self.target.read_text(), "old binary")

    def test_bad_executable_preserves_existing(self):
        self.existing_install()
        payload = b'#!/bin/sh\nexit 42\n'
        (self.fixtures / "gitso_linux_amd64").write_bytes(payload)
        (self.fixtures / "checksums.txt").write_text(hashlib.sha256(payload).hexdigest() + "  gitso_linux_amd64\n")
        self.assertNotEqual(self.run_installer().returncode, 0)
        self.assertEqual(self.target.read_text(), "old binary")

    def test_missing_git_before_download(self):
        (self.bin / "git").unlink()
        result = self.run_installer()
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse((self.root / "requests").exists())

    def test_unsupported_arch_before_download(self):
        self.assertNotEqual(self.run_installer(TEST_ARCH="i686").returncode, 0)
        self.assertFalse((self.root / "requests").exists())

    def test_invalid_version_before_download(self):
        self.assertNotEqual(self.run_installer(GITSO_VERSION="../../bad").returncode, 0)
        self.assertFalse((self.root / "requests").exists())


if __name__ == "__main__":
    unittest.main()
