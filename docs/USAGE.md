# 사용법

## 전역 옵션

| 옵션 | 동작 |
|------|------|
| `--yes`, `-y` | 확인 프롬프트 자동 동의 |
| `--no-color` / `--color` | 색상 출력 끄기/켜기 |
| `--force` | 위험 검사(활성 세션 등) 우회 |
| `--version`, `-V` | 버전 출력 |
| `--help`, `-h` | 도움말 |

환경 변수
- `CPROF_YES=1` — 모든 확인을 자동 동의
- `NO_COLOR=1` 또는 `CPROF_NO_COLOR=1` — 색상 끄기
- `CPROF_LOCK_TIMEOUT=10` — 동시 실행 lock 대기 시간 (초)

---

## init

첫 실행 마이그레이션. 기존 `~/.claude/`와 `~/.claude.json` 을 default 프로파일로 이동하고, 두 위치에 심볼릭 링크를 만듭니다.

```bash
claude-profiler init [--yes] [--no-git]
```

옵션
- `--yes` — 동의 프롬프트 우회
- `--no-git` — 통합 git 저장소를 만들지 않음 (git 미설치 환경에서 자동 적용)

종료 코드
- 0 성공 / 1 이미 초기화됨 / 10 마이그레이션 실패 / 21 백업 디스크 부족

동작
1. `~/.claude/`와 `~/.claude.json` 전체를 `~/.claude-profiler/backup/<ts>-origin.tgz` 로 백업
2. 두 항목을 `~/.claude-profiler/profiles/default/` 와 `.../default/_home/` 으로 이동
3. 두 위치(`~/.claude`, `~/.claude.json`)에 심볼릭 링크 생성
4. `~/.claude-profiler/.git/` 통합 저장소 초기화 (git 가능 시)
5. `current` 파일 = `default`

---

## list

```bash
claude-profiler list [--quiet] [--json]
```

옵션
- `--quiet` — 이름만 출력 (스크립트 친화)
- `--json` — `{"current":"...","profiles":[...]}` 형식

---

## current

```bash
claude-profiler current
```

활성 프로파일 이름을 출력. 셸 변수에 캡처할 때 유용:
```bash
profile=$(claude-profiler current)
```

---

## switch

```bash
claude-profiler switch <name> [--force]
```

옵션
- `--force` — 활성 Claude Code 세션 감지를 무시하고 강제 전환 (위험)

특수 동작
- `<name>` 이 `vanilla` 이고 프로파일이 없으면 **자동 생성** (빈 settings.json만 포함)
- 이미 활성 프로파일이면 안내 후 no-op (종료 코드 0)

종료 코드
- 0 성공 / 3 프로파일 없음 / 4 lock 충돌 / 5 활성 Claude 세션 / 11 트랜잭션 실패 / 12 검증 실패

---

## create

```bash
claude-profiler create <name> [--from <src>] [--empty]
```

옵션
- `--from <src>` — 다른 프로파일을 복제하여 생성
- `--empty` — 옵션 미지정 시 기본값 (빈 프로파일)

예
```bash
claude-profiler create work                   # 빈 프로파일
claude-profiler create work --from default    # default를 그대로 복제
```

종료 코드
- 0 성공 / 2 잘못된 이름 / 3 원본 없음 / 6 예약어 / 7 이미 존재

---

## delete

```bash
claude-profiler delete <name> [--yes] [--force]
```

활성 프로파일은 삭제할 수 없습니다. 삭제 직전 자동 백업 (`<ts>-delete-<name>.tgz`).

종료 코드
- 0 성공 / 3 프로파일 없음 / 4 lock 충돌 / 5 활성 세션 / 8 활성 프로파일 거부

---

## rename

```bash
claude-profiler rename <old> <new>
```

활성 프로파일은 이름을 변경할 수 없습니다 (다른 프로파일로 먼저 switch).

---

## export

```bash
claude-profiler export <name> <path.tgz> [--exclude-cache]
```

프로파일을 tarball로 내보냅니다. `--exclude-cache` 는 `cache/`, `image-cache/` 등 휘발성 디렉토리를 제외하여 크기를 줄입니다.

---

## import

```bash
claude-profiler import <path.tgz> [--name <new>]
```

tarball에서 프로파일을 가져옵니다. tarball에는 정확히 하나의 프로파일 디렉토리가 있어야 합니다 (보통 `export`로 만든 파일).

옵션
- `--name <new>` — 가져온 프로파일을 다른 이름으로 저장

안전 검사
- 절대 경로(`/...`) 또는 상위 경로(`../`) 가 포함된 tarball은 거부

---

## backup

```bash
claude-profiler backup list                          # 백업 목록 (시각/크기/이름)
claude-profiler backup prune [--older-than <days>]   # 오래된 백업 정리 (기본 30일)
claude-profiler backup restore <backup-filename>     # 백업을 임시 디렉토리에 추출
```

`backup restore` 는 임시 위치에만 추출하며, 실제 복원은 사용자가 결정합니다 (의도적인 보호 정책).

---

## uninstall

```bash
# 1. 기본 — 활성 프로파일을 ~/.claude/로 복원, 다른 프로파일은 archive
claude-profiler uninstall [--archive-others|--discard-others|--keep-others] [--yes]

# 2. 다른 프로파일을 활성으로 만들어 복원
claude-profiler uninstall --restore <name>

# 3. 도구 사용 이전 상태로 완전 원복 (origin-backup 사용)
claude-profiler uninstall --restore-origin [<tgz>]

# 4. 도구 스크립트만 제거, 데이터는 보존
claude-profiler uninstall --keep-data
```

공통 동작
1. 외부 안전망 스냅샷 생성: `~/uninstall-snapshot-<ts>.tgz`
2. 활성 Claude 세션 검사 (--force로 우회 가능)

옵션
- `--archive-others` (기본) — 다른 프로파일들을 `~/claude-profiles-archive-<ts>.tgz`로 보관
- `--discard-others` — 다른 프로파일들을 영구 삭제 (명시적 의사 표시)
- `--keep-others` — `~/.claude-profiler/profiles/` 그대로 유지 (`--keep-data`와 결합 권장)

복구 안내
설치된 환경이라면:
```bash
tar -xzf ~/uninstall-snapshot-<ts>.tgz -C ~
```

---

## doctor

```bash
claude-profiler doctor
```

설정 일관성을 진단합니다. 가능한 상태:

| 상태 | 의미 |
|------|------|
| `active` | 정상 |
| `unconfigured` | 초기화되지 않음 (init 필요) |
| `corrupted-current` | `current` 파일이 손상되었거나 가리키는 프로파일이 없음 |
| `corrupted-link` | `~/.claude` 또는 `~/.claude.json` 심볼릭 링크가 깨짐 |

복구는 자동으로 적용되지 않습니다. 데이터 안전을 위해 사용자가 결정합니다.

---

## 종료 코드 표준

| 코드 | 의미 |
|------|------|
| 0 | 성공 |
| 1 | 일반 에러 |
| 2 | 잘못된 사용법 (인자, 옵션, 백업 안전성 등) |
| 3 | 프로파일 또는 파일 없음 |
| 4 | lock 충돌 |
| 5 | 활성 Claude Code 세션 감지 |
| 6 | 예약어 사용 |
| 7 | 이미 존재하는 프로파일 |
| 8 | 활성 프로파일 조작 시도 (delete/rename) |
| 10 | 마이그레이션 실패 |
| 11 | 스위칭 트랜잭션 실패 (롤백됨) |
| 12 | 스위칭 검증 실패 (롤백됨) |
| 13 | 통합 저장소 init 실패 |
| 20 | 권한 부족 |
| 21 | 디스크 공간 부족 또는 tar 실패 |
| 30 | 손상 상태 (doctor 진단) |
