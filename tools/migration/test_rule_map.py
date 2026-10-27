"""이관 전후 대조: 옛 스킬 3개와 피드백이 새 위치에 빠짐없이 있는지 확인한다.

기준은 이관 전 커밋(BASE)의 파일이다. 옛 파일의 내용 줄이 새 위치(채널 문서·피드백·목적 절차·브랜드)에
그대로 있어야 한다. 일부러 옮기지 않은 줄은 rule_map.md의 "옮기지 않은 줄"에 이유와 함께 적는다.

실행: python3 -m unittest tools/migration/test_rule_map.py  (저장소 루트에서)
"""
import re
import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BASE = "a42526e"

OLD_SKILLS = {
    "naver-blog": ".claude/skills/naver-blog/SKILL.md",
    "threads": ".claude/skills/threads-post/SKILL.md",
    "insta-reels": ".claude/skills/fashion-reels/SKILL.md",
}


def old_file(path):
    return subprocess.run(
        ["git", "show", f"{BASE}:{path}"], cwd=ROOT, capture_output=True, text=True, check=True
    ).stdout


def norm(line):
    line = re.sub(r"^\s*(?:[-*]\s+|\d+\.\s+)?", "", line.strip())
    return re.sub(r"\s+", " ", line)


def content_lines(text):
    """머리말·제목·빈 줄·코드 울타리를 뺀 내용 줄."""
    text = re.sub(r"\A---\n.*?\n---\n", "", text, flags=re.S)
    out = []
    for line in text.splitlines():
        if not line.strip() or line.lstrip().startswith("#") or line.strip().startswith("```"):
            continue
        out.append(norm(line))
    return out


def read_all(patterns):
    chunks = []
    for pattern in patterns:
        for f in sorted(ROOT.glob(pattern)):
            chunks.append(f.read_text())
    return "\n".join(norm(l) for c in chunks for l in c.splitlines())


def exceptions():
    """rule_map.md "옮기지 않은 줄"의 `- 앞부분 || 이유` 줄. 앞부분으로 시작하는 옛 줄을 예외로 본다."""
    text = (ROOT / "tools/migration/rule_map.md").read_text()
    section = text.split("## 옮기지 않은 줄", 1)[1]
    return [norm(l[2:].split(" || ", 1)[0]) for l in section.splitlines() if l.startswith("- ") and " || " in l]


DEST = [
    "channels/naver-blog/*.md",
    "channels/threads/*.md",
    "channels/insta-reels/*.md",
    "channels/README.md",
    "workflows/*.md",
    "brand/*.md",
    "history/feedback.md",
]


class RuleMapTest(unittest.TestCase):
    def test_old_skill_lines_exist_in_new_places(self):
        dest = read_all(DEST)
        skip = exceptions()
        missing = {
            path: [l for l in content_lines(old_file(path)) if l not in dest and not l.startswith(tuple(skip))]
            for path in OLD_SKILLS.values()
        }
        missing = {p: ls for p, ls in missing.items() if ls}
        self.assertEqual(missing, {}, "새 위치에 없는 줄")

    def test_every_feedback_entry_moved_exactly_once(self):
        old = [l for l in old_file("history/feedback.md").splitlines() if l.startswith("[20")]
        new = []
        for f in ["history/feedback.md", "channels/naver-blog/feedback.md",
                  "channels/threads/feedback.md", "channels/insta-reels/feedback.md"]:
            new += [l for l in (ROOT / f).read_text().splitlines() if l.startswith("[20")]
        self.assertEqual(sorted(old), sorted(new))

    def test_feedback_entries_are_in_their_channel(self):
        for f, tags in [("channels/naver-blog/feedback.md", ("(네이버)", "블로그:")),
                        ("channels/threads/feedback.md", ("(쓰레드)",))]:
            for l in (ROOT / f).read_text().splitlines():
                if l.startswith("[20"):
                    self.assertTrue(any(t in l for t in tags), f"{f}에 다른 채널 피드백: {l[:40]}")


if __name__ == "__main__":
    unittest.main()
