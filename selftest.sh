#!/bin/bash
# 자체 시험: 인원관리.html 사본에 selftest_tail.html을 붙여 헤드리스 크롬으로 열고 결과 화면을 png로 남긴다.
# 실행: Git Bash에서  bash selftest.sh   → 출력된 png를 열어 "모두 통과"인지 본다.
set -e
cd "$(dirname "$0")"
OUT="D:/0000000.CODE/.tmp/인원관리/selftest"
rm -rf "$OUT"
mkdir -p "$OUT"
cat 인원관리.html selftest_tail.html > "$OUT/test.html"
# 크롬은 한글 경로의 file:// 주소를 못 여는 경우가 있어 주소만 인코딩한다
URL="file:///D:/0000000.CODE/.tmp/%EC%9D%B8%EC%9B%90%EA%B4%80%EB%A6%AC/selftest/test.html"
MSYS_NO_PATHCONV=1 "/c/Program Files/Google/Chrome/Application/chrome.exe" --headless=new --disable-gpu --no-first-run \
  --user-data-dir="$OUT/prof" --virtual-time-budget=15000 --window-size=1100,1000 --screenshot="$OUT/result.png" "$URL"
for i in 1 2 3 4 5 6 7 8 9 10; do
  [ -f "$OUT/result.png" ] && break
  powershell -c "Start-Sleep 1"
done
ls "$OUT/result.png"
