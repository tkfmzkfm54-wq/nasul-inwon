#!/bin/bash
# 자체 시험: 인원관리.html 사본에 selftest_tail.html을 붙여 헤드리스 크롬으로 열고 결과 화면을 png로 남긴다.
# 실행: Git Bash에서  bash selftest.sh   → 출력된 png를 열어 "모두 통과"인지 본다. 실패한 줄은 맨 위에 나온다.
# 결과 대신 앱 화면이 찍히면 가상 시간이 먼저 끝난 것(시험 끝의 빈 타이머로 막아 둠, 5번 연속 정상).
# 크롬 여러 개를 동시에 돌렸을 때 실패 1건이 나온 적이 있음(어느 시험인지·원인은 확인 못 함). 실패하면 하나씩 다시 돌려 본다.
set -e
cd "$(dirname "$0")"
OUT="D:/0000000.CODE/.tmp/인원관리/selftest"
rm -rf "$OUT"
mkdir -p "$OUT"
cat 인원관리.html selftest_tail.html > "$OUT/test.html"
# 크롬은 한글 경로의 file:// 주소를 못 여는 경우가 있어 주소만 인코딩한다
URL="file:///D:/0000000.CODE/.tmp/%EC%9D%B8%EC%9B%90%EA%B4%80%EB%A6%AC/selftest/test.html"
# --force-prefers-reduced-motion: 움직임 줄이기 설정이어도 테마 효과가 움직이는지 보는 시험이 어느 PC에서나 같게
MSYS_NO_PATHCONV=1 "/c/Program Files/Google/Chrome/Application/chrome.exe" --headless=new --disable-gpu --no-first-run --force-prefers-reduced-motion \
  --user-data-dir="$OUT/prof" --virtual-time-budget=60000 --window-size=1100,500 --screenshot="$OUT/result.png" "$URL"
for i in $(seq 1 60); do   # 크롬이 바로 돌아오고 뒤에서 그림을 씀: 최대 60초 기다림
  [ -f "$OUT/result.png" ] && break
  powershell -c "Start-Sleep 1"
done
ls "$OUT/result.png"
