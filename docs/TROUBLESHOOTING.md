# 트러블슈팅

## "활성 Claude Code 세션이 감지되었습니다" — 종료 코드 5

**원인**
스위칭/삭제 도중 데이터 손상을 방지하기 위해 자동 차단됩니다.

**해결**
1. 모든 Claude Code 창을 닫고 재시도
2. 혹은 강제 진행 (위험):
   ```bash
   claude-profiler switch <name> --force
   ```

---

## "다른 claude-profiler 실행 중입니다" — 종료 코드 4

**원인**
`~/.claude-profiler/.lock` 이 다른 실행 프로세스에 의해 보유 중.

**해결**
1. 다른 터미널에서 진행 중인 명령이 있는지 확인
2. 비정상 종료된 lock이 의심되면 PID 확인 후 강제 제거:
   ```bash
   cat ~/.claude-profiler/.lock          # PID:timestamp 확인
   kill -0 <PID> 2>/dev/null && echo "alive" || rm ~/.claude-profiler/.lock
   ```

> 도구는 1시간 이상 된 lock과 죽은 PID의 lock을 자동 정리합니다. 그래도 남으면 위 명령으로 수동 제거.

---

## ~/.claude 또는 ~/.claude.json 이 깨졌습니다

**증상**
- Claude Code 실행 시 설정이 보이지 않음
- `claude-profiler doctor` 가 `corrupted-link` 출력

**진단**
```bash
ls -la ~/.claude ~/.claude.json
readlink ~/.claude
readlink ~/.claude.json
cat ~/.claude-profiler/current
```

**해결**
1. 가장 간단: 다른 프로파일로 switch (자동 재설정)
   ```bash
   claude-profiler switch <last-known-good>
   ```
2. 그래도 안 되면 doctor 안내를 따라 수동 복구
3. 최후: 백업에서 복원
   ```bash
   ls ~/.claude-profiler/backup/        # 백업 목록 확인
   tar -tzf ~/.claude-profiler/backup/<file>.tgz | head    # 내용 미리보기
   ```

---

## init 시 "이미 초기화되어 있습니다"

**원인**
`~/.claude-profiler/` 가 이미 존재. 두 번째 init은 데이터를 보호하기 위해 거부됩니다.

**해결**
```bash
claude-profiler list      # 현재 상태 확인
claude-profiler doctor    # 일관성 진단
```

새로 시작하려면 (사용자 데이터를 잃지 않으려면 먼저 백업 필수):
```bash
claude-profiler uninstall --restore-origin    # 도구 사용 이전 상태로 원복
# 또는
claude-profiler uninstall --keep-others       # 데이터만 남기고 도구 제거
```

---

## init 시 "~/.claude 가 이미 심볼릭 링크입니다"

**원인**
다른 프로파일 관리 도구(`asdf`, `dotbot`, 직접 만든 링크 등)가 `~/.claude` 를 관리 중.

**해결**
1. 어디로 연결되어 있는지 확인:
   ```bash
   readlink ~/.claude
   ```
2. 다른 도구를 비활성화하거나, 해당 위치의 데이터를 일반 디렉토리로 변환:
   ```bash
   real=$(readlink ~/.claude)
   rm ~/.claude
   cp -a "$real" ~/.claude
   ```
3. claude-profiler init 재시도

---

## 응급 수동 복구 (도구가 작동하지 않을 때)

### 활성 프로파일을 ~/.claude/로 살리고 도구 제거

```bash
# 어떤 프로파일이 활성인지 확인
CURRENT=$(cat ~/.claude-profiler/current)

# ~/.claude를 실체 디렉토리로 변환
mv "$(readlink ~/.claude)"  /tmp/claude-restore
rm ~/.claude
mv /tmp/claude-restore ~/.claude

# ~/.claude.json도 동일
mv "$(readlink ~/.claude.json)" /tmp/claude-json-restore
rm ~/.claude.json
mv /tmp/claude-json-restore ~/.claude.json

# _home/ 잔여 정리
mv ~/.claude/_home/.claude.json ~/.claude.json 2>/dev/null || true
rmdir ~/.claude/_home 2>/dev/null || true

# 다른 프로파일 보존 (선택)
tar -czf ~/claude-profiles-archive.tgz -C ~/.claude-profiler profiles/

# 도구 제거
rm -rf ~/.claude-profiler
```

### 도구 사용 이전 상태로 완전 원복 (원본 백업 사용)

```bash
# 원본 백업 위치 확인
ls ~/.claude-profiler/backup/*-origin.tgz

# 사용할 백업을 안전한 곳에 복사 (다음 단계에서 도구 영역이 지워지므로)
cp ~/.claude-profiler/backup/<timestamp>-origin.tgz  /tmp/

# 현재 상태 정리
rm ~/.claude  ~/.claude.json
rm -rf ~/.claude-profiler

# 백업 풀기
tar -xzf /tmp/<timestamp>-origin.tgz -C ~
```

---

## 통합 git 저장소를 다른 머신과 동기화하고 싶음

### 첫 머신
```bash
cd ~/.claude-profiler
git remote add origin <repo-url>
git push -u origin main --force        # 기존 origin이 있었다면 force 필요
```

### 다른 머신
```bash
git clone <repo-url> ~/.claude-profiler
claude-profiler switch default
```

새 머신에서는 자격증명(`.credentials.json`)이 동기화되지 않으므로 한 번 재인증이 필요합니다.

---

## 캐시 또는 자격증명을 프로파일별로 분리하고 싶음

기본 정책상 다음은 모든 프로파일에서 공유됩니다 (`.gitignore` 처리):
- `cache/`, `image-cache/`, `paste-cache/`, `shell-snapshots/`, `session-env/`
- `.credentials.json`
- `telemetry/`, `statsig/`, `debug/`, `ide/`

자격증명을 정말 분리하려면 직접 파일을 옮기고 새 토큰으로 재인증해야 합니다. 도구는 `.credentials.json`을 옮기지 않습니다 (보안 정책).

---

## 빌드/설치 관련

### `bash: claude-profiler: command not found`

`install.sh` 가 추가한 마커 블록이 셸 rc에 있는지 확인:
```bash
grep -A 4 'claude-profiler' ~/.zshrc        # 또는 .bashrc / .bash_profile
```

새 셸을 열거나 source 했는지 확인:
```bash
source ~/.zshrc
hash -r
which claude-profiler
```

### `bash 4 이상이 필요합니다` 같은 오류

도구는 bash 3.2 호환을 목표로 작성되었습니다. 만약 이런 오류가 보이면 모듈 빌드 산출물이 아니라 raw lib 파일을 직접 실행한 경우일 수 있습니다. `dist/claude-profiler` 를 사용하세요.

---

## 그 외 문제

`claude-profiler doctor` 출력과 `~/.claude-profiler/backup/` 의 최근 백업 목록을 함께 확인하면 대부분의 손상 상태를 진단할 수 있습니다.
