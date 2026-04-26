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
claude-profiler           # 인자 없이 호출해도 동일 (단축형)
```

활성 프로파일 이름을 출력. 인자 없이 `claude-profiler` 만 입력해도 같은 결과를 보여주므로, 가볍게 현재 상태를 확인할 때 편리합니다. 단, **초기화되지 않은 상태에서 인자 없이 호출하면 사용법(usage)이 출력**됩니다.

셸 변수에 캡처할 때:
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
claude-profiler create <name> [--from <src> | --empty]
```

기본 동작 — 옵션을 생략하면 **현재 활성 프로파일을 복제**합니다. 인증(`.credentials.json`), MCP 설정, skills/agents 등이 그대로 따라옵니다. 이는 "현재 환경을 그대로 가져가서 거기서 분기하고 싶다"는 가장 흔한 의도에 맞춘 안전 디폴트입니다.

옵션
- `--from <src>` — 지정한 프로파일을 복제 (현재가 아니라 다른 프로파일에서 분기하고 싶을 때)
- `--empty` — 인증/설정이 모두 비어 있는 클린 슬레이트로 생성. **이 경우 스위칭 후 Claude Code 재인증이 필요**합니다. (`vanilla`와 동일한 상태)
- `--from` 과 `--empty` 는 함께 사용할 수 없습니다 (의도 충돌, 종료 코드 2).

예
```bash
claude-profiler create work                   # 현재 활성 프로파일을 복제 (기본)
claude-profiler create work --from default    # default 를 명시적으로 복제
claude-profiler create work --from vanilla    # vanilla 에서 복제 (재인증 필요)
claude-profiler create scratch --empty        # 완전히 빈 프로파일 (재인증 필요)
```

종료 코드
- 0 성공 / 2 잘못된 사용법(이름·옵션 충돌) / 3 원본 없음 / 6 예약어 / 7 이미 존재 / 30 현재 활성 프로파일 확인 불가

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

## update

```bash
claude-profiler update [--from <git-url|local-path>] [--ref <branch|tag>] [--check] [--yes]
```

설치된 `claude-profiler` 바이너리를 새 버전으로 갱신합니다. **사용자 데이터(`~/.claude-profiler/`)와 셸 rc 마커는 건드리지 않습니다** — 바이너리와 완성(completions) 파일만 교체.

### 소스 지정

업데이트 소스는 다음 우선순위로 결정됩니다.

1. `--from <url-or-path>` — 명시적 지정 (가장 우선).
2. 환경 변수 `CPROF_UPDATE_URL` — 셸 rc 또는 CI 환경에서 고정해두고 사용.
3. 둘 다 없으면 에러로 종료 (코드 2).

소스가 **로컬 디렉토리**면 그대로 사용하고, **URL**(git 저장소)이면 `git clone --depth 1` 으로 임시 디렉토리에 가져온 뒤 빌드합니다. `--ref` 로 브랜치 또는 태그를 지정할 수 있습니다.

### 소스 형태 자동 감지

| 소스 구성 | 동작 |
|----------|------|
| `build.sh` + `src/` 존재 | `build.sh` 로 재빌드 후 `dist/install.sh` 로 설치 |
| `dist/install.sh` + `dist/claude-profiler` 만 존재 | 빌드 건너뛰고 즉시 설치 (릴리스 tarball 호환) |
| 둘 다 아님 | 종료 코드 1 |

### 동작 흐름

1. 실행 중 바이너리 경로(`$BASH_SOURCE`)에서 `$PREFIX/bin/claude-profiler` 패턴을 검출하여 설치 prefix 추론.
2. 소스 확보(로컬은 그대로, URL은 shallow clone).
3. 새 버전을 `build.sh` 의 `VERSION="${VERSION:-X.Y.Z}"` 라인에서 추출하여 현재 버전과 함께 표시.
4. 사용자 확인(`--yes` 로 우회 가능).
5. lock 획득 → 빌드(필요 시) → `dist/install.sh --prefix <검출> --no-shell` 실행.
6. lock 해제 + 임시 디렉토리 정리.

### 옵션

- `--from <git-url|local-path>` — 업데이트 소스. URL은 git 저장소, 경로는 로컬 디렉토리.
- `--ref <branch|tag>` — 원격 git URL일 때 특정 브랜치/태그를 체크아웃.
- `--check` — 실제 갱신 없이 현재 버전 vs 새 버전 비교만 출력 (lock 미획득, 임시 디렉토리도 정리).
- `--yes`, `-y` — 확인 프롬프트 자동 동의.

### 예

```bash
# 로컬에 클론한 저장소에서 업데이트
claude-profiler update --from ~/Projects/claude-profiler

# 원격 저장소 main 브랜치에서 업데이트
claude-profiler update --from https://example.org/claude-profiler.git

# 특정 태그로 업데이트
claude-profiler update --from https://example.org/claude-profiler.git --ref v0.2.0

# 환경 변수로 고정해두고 짧게 호출
export CPROF_UPDATE_URL=https://example.org/claude-profiler.git
claude-profiler update --check       # 새 버전 가용 여부만 확인
claude-profiler update --yes         # 바로 갱신
```

### 안전 사항

- `~/.claude-profiler/` 의 프로파일·백업·통합 git 저장소는 update 가 **전혀** 건드리지 않습니다.
- 셸 rc 의 마커 블록도 그대로 유지됩니다 (`--no-shell` 강제).
- update 중에는 lock(`~/.claude-profiler/.lock`)을 획득하므로 동시 `switch`/`create`/`delete` 와 충돌하지 않습니다.
- 정상 설치(`$PREFIX/bin/claude-profiler`)가 아닌 경로에서 실행 시 거부됩니다 (개발용 소스 트리에서 직접 실행한 경우 등).

### 종료 코드

- 0 성공 (또는 `--check` 정상 종료) / 1 빌드·설치·git clone 실패, 비정상 설치 위치 / 2 잘못된 사용법 / 4 lock 충돌

---

## 세션 배너 (SessionStart 훅)

`init` 시 활성 프로파일의 `settings.json` 에 SessionStart 훅이 자동 주입됩니다. 이후 `claude` 가 프로젝트에서 시작/재개될 때마다 컨텍스트 첫머리에 다음과 같은 안내가 표시됩니다.

```
[claude-profiler] 현재 프로파일: default

프로파일 전환 (Claude Code 종료 후 새 셸에서 실행):
  claude-profiler list             # 사용 가능 프로파일 보기
  claude-profiler switch <name>    # 다른 프로파일로 전환
  claude-profiler                  # 현재 프로파일 확인
```

작동 메커니즘
- `settings.json` 의 `hooks.SessionStart` 항목으로 `claude-profiler --session-banner` 가 등록됩니다.
- matcher 는 `startup|resume` 두 상황 모두 매칭.
- `--session-banner` 는 내부 명령으로, plain text 만 출력하고 미초기화 상태에서는 조용히 종료합니다 (세션 방해 없음).

자동 주입되는 시점
- `init` — 마이그레이션된 default 프로파일에 주입.
- `create <name>` (기본/`--from`) — 원본 프로파일에서 클론되며 자연 상속.
- `create <name> --empty` 또는 `switch vanilla` 자동 생성 — `cprof_profile_seed_empty` 가 빈 settings.json 생성 직후 주입.

기존 `settings.json` 에 사용자 내용이 이미 있을 때
- `jq` 가 있으면 안전하게 병합 (기존 키 보존).
- `jq` 가 없으면 사용자 JSON 손상을 막기 위해 **건너뛰고 경고**만 표시. 수동 추가는 아래 형식을 `settings.json` 의 `"hooks"` 키에 추가하세요.

```jsonc
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "startup|resume",
        "hooks": [
          { "type": "command", "command": "claude-profiler --session-banner" }
        ]
      }
    ]
  }
}
```

배너 비활성화
- 활성 프로파일의 `~/.claude/settings.json` 에서 위 항목을 제거하면 됩니다 (영구 비활성).
- 일시적으로 끄고 싶다면 `claude` 시작 시 `CLAUDE_DISABLE_HOOKS=1` 같은 환경 변수(Claude Code 정책에 따름)를 사용.

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
