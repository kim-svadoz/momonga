"""채널 × 목적 조합기 시험. PRD REQ-3에서 도출했다.

- 같은 채널·목적·입력이면 조립 결과가 매번 같다.
- 필요한 문서 묶음이 항상 같은 순서로 조립된다.
- 정의되지 않은 조합이면 빠진 곳을 알려 주고, 아무것도 출력하지 않고 멈춘다.

실행: python3 -m unittest tools/compose/test_compose.py  (저장소 루트에서)
"""
import re
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
COMPOSE = ROOT / "tools/compose/compose.py"


def run(*args, root=None):
    cmd = [sys.executable, str(COMPOSE), *args]
    if root:
        cmd += ["--root", str(root)]
    return subprocess.run(cmd, capture_output=True, text=True)


def doc_order(output):
    return re.findall(r"^## 문서: (.+)$", output, flags=re.M)


class ComposeTest(unittest.TestCase):
    def test_same_input_gives_identical_output(self):
        a = run("insta-reels", "edit")
        b = run("insta-reels", "edit")
        self.assertEqual(a.returncode, 0, a.stderr)
        self.assertEqual(a.stdout, b.stdout)

    def test_output_has_no_machine_specific_text(self):
        out = run("insta-reels", "edit").stdout
        self.assertNotIn(str(ROOT), out)
        self.assertNotIn("/Users/", out)

    def test_video_channel_edit_documents_in_fixed_order(self):
        r = run("insta-reels", "edit")
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertEqual(
            doc_order(r.stdout),
            [
                "brand/profile.md",
                "brand/voice.md",
                "brand/style-guide.md",
                "brand/caption-rules.md",
                "channels/README.md (숏폼 공통 규격)",
                "channels/insta-reels/channel.md",
                "channels/insta-reels/feedback.md",
                "channels/insta-reels/profile.json",
                "workflows/edit.md",
            ],
        )

    def test_text_channel_write_skips_video_documents(self):
        r = run("naver-blog", "write")
        self.assertEqual(r.returncode, 0, r.stderr)
        order = doc_order(r.stdout)
        self.assertEqual(
            order,
            [
                "brand/profile.md",
                "brand/voice.md",
                "channels/README.md (글 공통 규격)",
                "channels/naver-blog/channel.md",
                "channels/naver-blog/feedback.md",
                "workflows/write.md",
            ],
        )

    def test_list_shows_only_the_plan(self):
        r = run("threads", "write", "--list")
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn("channels/threads/channel.md", r.stdout)
        self.assertNotIn("## 문서:", r.stdout)

    def test_unknown_channel_stops_and_lists_valid_channels(self):
        r = run("youtube-vlog", "write")
        self.assertNotEqual(r.returncode, 0)
        self.assertEqual(r.stdout, "")
        self.assertIn("youtube-vlog", r.stderr)
        self.assertIn("naver-blog", r.stderr)

    def test_unknown_purpose_stops(self):
        r = run("naver-blog", "dance")
        self.assertNotEqual(r.returncode, 0)
        self.assertEqual(r.stdout, "")
        self.assertIn("write", r.stderr)

    def test_channel_that_does_not_do_the_purpose_stops(self):
        r = run("naver-blog", "edit")
        self.assertNotEqual(r.returncode, 0)
        self.assertEqual(r.stdout, "")
        self.assertIn("naver-blog", r.stderr)
        self.assertIn("edit", r.stderr)
        self.assertNotIn("profile.json", r.stderr)

    def test_edit_without_channel_profile_names_the_missing_file(self):
        r = run("tiktok", "edit")
        self.assertNotEqual(r.returncode, 0)
        self.assertEqual(r.stdout, "")
        self.assertIn("channels/tiktok/profile.json", r.stderr)

    def test_stub_channel_write_works_and_warns_about_empty_cells(self):
        r = run("tiktok", "write")
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn("비어 있는 칸", r.stdout)
        self.assertNotIn("channels/tiktok/profile.json", r.stdout)

    def test_missing_workflow_names_the_file_and_prints_nothing(self):
        with tempfile.TemporaryDirectory() as tmp:
            copy = Path(tmp) / "repo"
            shutil.copytree(ROOT, copy, ignore=shutil.ignore_patterns(".git", "output", "inbox", "sugo"))
            (copy / "workflows/write.md").unlink()
            r = run("naver-blog", "write", root=copy)
            self.assertNotEqual(r.returncode, 0)
            self.assertEqual(r.stdout, "")
            self.assertIn("workflows/write.md", r.stderr)

    def test_all_missing_documents_are_reported_together(self):
        with tempfile.TemporaryDirectory() as tmp:
            copy = Path(tmp) / "repo"
            shutil.copytree(ROOT, copy, ignore=shutil.ignore_patterns(".git", "output", "inbox", "sugo"))
            (copy / "workflows/write.md").unlink()
            (copy / "brand/voice.md").unlink()
            r = run("naver-blog", "write", root=copy)
            self.assertIn("workflows/write.md", r.stderr)
            self.assertIn("brand/voice.md", r.stderr)


class BriefTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.dir = Path(self.tmp.name)

    def brief(self, front, body="## 주제 한 줄\n가디건 추천\n", name="brief.md"):
        path = self.dir / name
        path.write_text(f"---\n{front}\n---\n\n<!-- 쓰는 법: 지워질 안내 -->\n\n{body}")
        return path

    def test_brief_gives_channel_and_purpose(self):
        b = self.brief("channel: threads\npurpose: write\nfrom_channel:")
        by_brief = run("--brief", str(b))
        by_args = run("threads", "write")
        self.assertEqual(by_brief.returncode, 0, by_brief.stderr)
        self.assertEqual(doc_order(by_brief.stdout), doc_order(by_args.stdout) + ["brief.md"])
        self.assertIn("가디건 추천", by_brief.stdout)

    def test_brief_comes_last_and_instructions_are_removed(self):
        b = self.brief("channel: threads\npurpose: write\nfrom_channel:")
        out = run("--brief", str(b)).stdout
        self.assertEqual(doc_order(out)[-1], "brief.md")
        self.assertNotIn("지워질 안내", out)

    def test_args_and_brief_must_agree(self):
        b = self.brief("channel: threads\npurpose: write\nfrom_channel:")
        r = run("naver-blog", "write", "--brief", str(b))
        self.assertNotEqual(r.returncode, 0)
        self.assertEqual(r.stdout, "")
        self.assertIn("threads", r.stderr)
        self.assertIn("naver-blog", r.stderr)

    def test_empty_brief_fields_stop_and_name_the_fields(self):
        b = self.brief("channel:\npurpose:\nfrom_channel:")
        r = run("--brief", str(b))
        self.assertNotEqual(r.returncode, 0)
        self.assertEqual(r.stdout, "")
        self.assertIn("channel", r.stderr)
        self.assertIn("purpose", r.stderr)

    def test_convert_includes_origin_channel_after_workflow(self):
        b = self.brief("channel: insta-reels\npurpose: convert\nfrom_channel: threads")
        r = run("--brief", str(b))
        self.assertEqual(r.returncode, 0, r.stderr)
        order = doc_order(r.stdout)
        self.assertIn("channels/threads/channel.md (원본 채널)", order)
        self.assertGreater(order.index("channels/threads/channel.md (원본 채널)"), order.index("workflows/convert.md"))

    def test_unknown_origin_channel_stops(self):
        b = self.brief("channel: insta-reels\npurpose: convert\nfrom_channel: myspace")
        r = run("--brief", str(b))
        self.assertNotEqual(r.returncode, 0)
        self.assertIn("myspace", r.stderr)


if __name__ == "__main__":
    unittest.main()
