#!/usr/bin/env python3
"""채널 × 목적 조합기.

채널과 목적을 정하면 읽어야 할 문서를 항상 같은 순서로 이어 붙여 하나의 안내문으로 출력한다.
같은 채널·목적·입력이면 출력이 매번 같다 (시각·절대경로를 넣지 않는다).
조합에 필요한 문서가 하나라도 없으면 아무것도 출력하지 않고, 빠진 곳을 모두 알린 뒤 멈춘다.

사용:
  python3 tools/compose/compose.py <채널> <목적> [--brief inbox/.../brief.md] [--list]
  python3 tools/compose/compose.py --brief inbox/.../brief.md
"""
import argparse
import re
import sys
from pathlib import Path

PURPOSES = ("write", "edit", "convert")
TEXT_FAMILY = "글"
VIDEO_FAMILIES = ("숏폼", "스토리", "롱폼")
# channels/README.md "계열별 공통 규격"에서 계열마다 읽을 소제목
FAMILY_SECTION = {
    "글": ("### 글", "글 공통 규격"),
    "숏폼": ("### 숏폼", "숏폼 공통 규격"),
    "사진": ("### 사진, 스토리, 롱폼", "사진·스토리·롱폼 공통 규격"),
    "스토리": ("### 사진, 스토리, 롱폼", "사진·스토리·롱폼 공통 규격"),
    "롱폼": ("### 사진, 스토리, 롱폼", "사진·스토리·롱폼 공통 규격"),
}
EMPTY_CELL = "⬜"
DECISIONS_SHEET = "docs/결정할-것.md"
# 결정 시트 맨 위 표의 한 줄: | D1 | 공통 또는 채널 이름(쉼표로 여러 개) | 질문 | 급함 | ⬜ 미정 |
DECISION_ROW = re.compile(r"^\|\s*(D\d+)\s*\|([^|]*)\|([^|]*)\|([^|]*)\|([^|]*)\|\s*$")


class ComposeError(Exception):
    def __init__(self, problems):
        super().__init__("\n".join(problems))
        self.problems = problems


def parse_front(text):
    m = re.match(r"---\n(.*?)\n---\n?", text, flags=re.S)
    if not m:
        return {}, text
    front = {}
    for line in m.group(1).splitlines():
        key, _, value = line.partition(":")
        front[key.strip()] = value.strip()
    return front, text[m.end():]


def parse_list(value):
    return [v.strip() for v in value.strip("[]").split(",") if v.strip()]


def channels_in(root):
    return sorted(p.parent.name for p in (root / "channels").glob("*/channel.md"))


def family_section(readme_text, family):
    heading, label = FAMILY_SECTION[family]
    lines = readme_text.splitlines()
    start = next((i for i, l in enumerate(lines) if l.startswith(heading)), None)
    if start is None:
        return None, label
    end = next((i for i in range(start + 1, len(lines)) if lines[i].startswith(("### ", "## "))), len(lines))
    return "\n".join(lines[start:end]).strip(), label


def load_brief(path):
    front, body = parse_front(path.read_text(encoding="utf-8"))
    body = re.sub(r"<!--.*?-->", "", body, flags=re.S).strip()
    return front, body


def build_plan(root, channel, purpose, origin, brief_label, brief_body):
    """(문서 목록, 안내문 앞부분 정보)를 만든다. 문서 목록 항목은 (표시 이름, 내용)."""
    problems = []
    docs = []

    def need(rel, label=None):
        path = root / rel
        if not path.is_file():
            problems.append(f"필요한 문서가 없다: {rel}")
            return None
        text = path.read_text(encoding="utf-8").strip()
        docs.append((label or rel, text))
        return text

    channel_text = (root / "channels" / channel / "channel.md").read_text(encoding="utf-8")
    front, _ = parse_front(channel_text)
    family = front.get("family", "")
    if purpose not in parse_list(front.get("purposes", "")):
        problems.append(f"{channel} 채널은 {purpose} 목적을 하지 않는다 (가능: {', '.join(parse_list(front.get('purposes', ''))) or '없음'})")
    if family not in FAMILY_SECTION:
        problems.append(f"channels/{channel}/channel.md의 family가 올바르지 않다: '{family}'")
    if problems:
        raise ComposeError(problems)

    is_video = family in VIDEO_FAMILIES
    need("brand/profile.md")
    need("brand/voice.md")
    if family != TEXT_FAMILY:
        need("brand/style-guide.md")
    if is_video and purpose in ("edit", "convert"):
        need("brand/caption-rules.md")

    readme = root / "channels/README.md"
    if not readme.is_file():
        problems.append("필요한 문서가 없다: channels/README.md")
    elif family in FAMILY_SECTION:
        section, label = family_section(readme.read_text(encoding="utf-8"), family)
        if section is None:
            problems.append(f"channels/README.md에 '{FAMILY_SECTION[family][0]}' 소제목이 없다")
        else:
            docs.append((f"channels/README.md ({label})", section))

    need(f"channels/{channel}/channel.md")
    if (root / f"channels/{channel}/feedback.md").is_file():
        need(f"channels/{channel}/feedback.md")
    profile = f"channels/{channel}/profile.json"
    if purpose == "edit":
        need(profile)
    elif is_video and purpose == "convert" and (root / profile).is_file():
        need(profile)
    need(f"workflows/{purpose}.md")

    if origin:
        origin_path = f"channels/{origin}/channel.md"
        if origin not in channels_in(root):
            problems.append(f"원본 채널을 찾을 수 없다: {origin} (있는 채널: {', '.join(channels_in(root))})")
        else:
            need(origin_path, f"{origin_path} (원본 채널)")
    if brief_body is not None:
        docs.append((brief_label, brief_body))

    if problems:
        raise ComposeError(problems)
    empty = sum(1 for l in channel_text.splitlines() if EMPTY_CELL in l)
    return docs, front, empty


def pending_decisions(root, channel):
    """결정 시트에서 아직 정하지 않은(미정) 항목 중 이 채널 또는 공통에 해당하는 것. 시트가 없으면 빈 목록."""
    sheet = root / DECISIONS_SHEET
    if not sheet.is_file():
        return []
    found = []
    for line in sheet.read_text(encoding="utf-8").splitlines():
        m = DECISION_ROW.match(line)
        if not m:
            continue
        number, channels, question, urgency, state = (g.strip() for g in m.groups())
        applies = [c.strip() for c in channels.split(",")]
        if "미정" in state and ("공통" in applies or channel in applies):
            found.append((number, channels, question, urgency))
    return found


def render(channel, purpose, front, empty, docs, pending=()):
    out = [f"# 조합: {channel} × {purpose}", ""]
    out.append(f"채널: {front.get('name', channel)} (계열: {front.get('family')}, 상태: {front.get('status')})")
    out.append("")
    out.append("## 읽는 순서")
    out += [f"{i}. {label}" for i, (label, _) in enumerate(docs, 1)]
    if empty:
        out += [
            "",
            "## 비어 있는 칸",
            f"channels/{channel}/channel.md에 {EMPTY_CELL}로 비어 있는 줄이 {empty}개 있다. "
            "비어 있는 칸은 추측해서 채우지 말고 사용자에게 알린다.",
        ]
    if pending:
        out += [
            "",
            "## 결정 대기",
            f"벵짱이 아직 정하지 않은 항목이다. 작업을 시작하기 전에 사용자에게 알리고, 원하면 그 자리에서 묻는다. 항목별 선택지와 추천은 {DECISIONS_SHEET}에 있다.",
        ]
        out += [f"- {n} ({c}, {u}): {q}" for n, c, q, u in pending]
    for label, text in docs:
        out += ["", "---", f"## 문서: {label}", "", text]
    return "\n".join(out) + "\n"


def run(args):
    root = Path(args.root).resolve() if args.root else Path(__file__).resolve().parents[2]
    problems = []
    channel, purpose, origin, brief_label, brief_body = args.channel, args.purpose, None, None, None

    if args.brief:
        brief_path = Path(args.brief)
        if not brief_path.is_file():
            raise ComposeError([f"brief 파일을 찾을 수 없다: {args.brief}"])
        front, brief_body = load_brief(brief_path)
        brief_label = brief_path.name
        for key, given in (("channel", channel), ("purpose", purpose)):
            if given and front.get(key) and given != front[key]:
                problems.append(f"인자의 {key}({given})와 brief의 {key}({front[key]})가 다르다")
        channel = channel or front.get("channel")
        purpose = purpose or front.get("purpose")
        origin = front.get("from_channel") or None

    if not channel:
        problems.append("채널이 없다 (인자나 brief의 channel)")
    if not purpose:
        problems.append("목적이 없다 (인자나 brief의 purpose)")
    if problems:
        raise ComposeError(problems)

    valid = channels_in(root)
    if channel not in valid:
        problems.append(f"알 수 없는 채널: {channel} (있는 채널: {', '.join(valid)})")
    if purpose not in PURPOSES:
        problems.append(f"알 수 없는 목적: {purpose} (있는 목적: {', '.join(PURPOSES)})")
    if problems:
        raise ComposeError(problems)

    docs, front, empty = build_plan(root, channel, purpose, origin, brief_label, brief_body)
    if args.list:
        return "\n".join(label for label, _ in docs) + "\n"
    return render(channel, purpose, front, empty, docs, pending_decisions(root, channel))


def main(argv=None):
    parser = argparse.ArgumentParser(description="채널 × 목적 조합기")
    parser.add_argument("channel", nargs="?")
    parser.add_argument("purpose", nargs="?")
    parser.add_argument("--brief")
    parser.add_argument("--list", action="store_true", help="읽을 문서 목록만 출력")
    parser.add_argument("--root", help="저장소 위치 (시험용)")
    args = parser.parse_args(argv)
    try:
        sys.stdout.write(run(args))
    except ComposeError as e:
        sys.stderr.write("조합할 수 없다:\n" + "\n".join(f"- {p}" for p in e.problems) + "\n")
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
