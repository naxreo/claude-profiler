# claude-profiler

> Claude Code의 `~/.claude/` 디렉토리를 여러 프로파일로 관리하고 빠르게 전환합니다.

업무용·개인용·클린 데모 환경처럼 **상황별로 활성화하고 싶은 skills/agents/commands/MCP 세트**를 분리해 두고, 한 명령으로 갈아끼웁니다. macOS·Linux의 bash·zsh·fish에서 동작합니다.

## 빠른 시작

```bash
# 빌드
bash build.sh

# 설치 (사용자 영역)
bash dist/install.sh
exec $SHELL    # 또는 source ~/.zshrc / ~/.bashrc

# 첫 실행 — 기존 ~/.claude/와 ~/.claude.json을 'default' 프로파일로 마이그레이션
claude-profiler init

# 새 프로파일 만들기 (현재 활성 프로파일을 복제하는 게 기본)
claude-profiler create work

# 전환
claude-profiler switch work

# 현재 활성 프로파일 확인 (인자 없이 호출해도 동일)
claude-profiler current
claude-profiler

# 깨끗한 환경 (없으면 자동 생성)
claude-profiler switch vanilla

# 클린 슬레이트로 새 프로파일 (Claude Code 재인증 필요)
claude-profiler create personal --empty
```

## 명령

| 명령 | 동작 |
|------|------|
| `init` | 첫 실행 마이그레이션 + 통합 git 저장소 초기화 |
| `list` | 프로파일 목록 (활성에 `*`) |
| `current` | 현재 활성 프로파일 이름 (인자 없이 `claude-profiler` 만 입력해도 동일) |
| `switch <name>` | 전환. `vanilla`는 미존재 시 자동 생성 |
| `create <name> [--from <src> \| --empty]` | 기본은 현재 프로파일 복제. `--from`으로 다른 원본, `--empty`로 클린 슬레이트(재인증 필요) |
| `delete <name>` | 비활성 프로파일 삭제 (자동 백업) |
| `rename <old> <new>` | 이름 변경 |
| `export <name> <path.tgz>` | 프로파일 내보내기 |
| `import <path.tgz> [--name <new>]` | 프로파일 가져오기 |
| `backup list/prune/restore` | 백업 관리 |
| `uninstall` | 도구 제거 (자세한 옵션은 `docs/USAGE.md`) |
| `update [--from <url\|path>] [--ref <ref>] [--check]` | 설치된 바이너리를 새 버전으로 갱신 (사용자 데이터/셸 rc 보존) |
| `doctor` | 일관성 진단 |

## 동작 방식

```
~/.claude          → ~/.claude-profiler/profiles/<현재>/                          (심볼릭 링크)
~/.claude.json     → ~/.claude-profiler/profiles/<현재>/_home/.claude.json        (심볼릭 링크)
```

`switch` 한 번에 두 심볼릭 링크가 갱신됩니다. Claude Code 입장에서는 평소처럼 `~/.claude/` 와 `~/.claude.json`을 사용하지만, 그 실체는 활성 프로파일에 따라 바뀝니다.

## 세션 배너

`init` 후 모든 프로파일에 SessionStart 훅이 자동 등록되어, `claude` 가 시작/재개될 때마다 컨텍스트 첫머리에 현재 프로파일 이름과 전환 안내가 표시됩니다. 빈 프로파일(`--empty`/`vanilla`)에도 동일하게 적용됩니다. 비활성화/커스터마이징은 `docs/USAGE.md` 의 [세션 배너 섹션](docs/USAGE.md#세션-배너-sessionstart-훅) 참고.

## 데이터 안전성

- **위험 작업 자동 백업** — `init`, `switch`, `delete`, `import`, `rename`, `uninstall` 직전마다 `~/.claude-profiler/backup/` 단일 폴더에 자동 백업.
- **활성 Claude Code 세션 차단** — 위험 작업 중 데이터 손상을 방지하기 위해 기본적으로 거부됩니다. `--force`로만 우회.
- **동시 실행 lock** — `~/.claude-profiler/.lock`으로 두 명령 동시 실행 방지.
- **트랜잭션식 스위칭** — 두 심볼릭 링크 갱신 중 실패하면 즉시 이전 상태로 롤백.
- **uninstall 안전망** — 제거 전에 `~/uninstall-snapshot-<ts>.tgz`를 홈에 자동 보관. 도구를 지운 후에도 복원 가능.
- **응급 복구 가능** — 도구가 망가져도 `mv`/`ln` 같은 셸 기본 명령만으로 원복할 수 있도록 설계 (`docs/TROUBLESHOOTING.md`).

## 통합 git 저장소

`init` 시 `~/.claude-profiler/.git/` 이 생성되어 모든 프로파일을 한 저장소로 백업·동기화할 수 있습니다.

```bash
cd ~/.claude-profiler
git add profiles/
git commit -m "snapshot"
git push    # 사용자가 origin을 등록한 경우
```

다른 머신에서:
```bash
git clone <URL> ~/.claude-profiler
claude-profiler switch default
```

자격증명(`.credentials.json`)과 캐시는 `.gitignore`로 추적되지 않으므로 머신마다 별도로 관리됩니다.

## 문서

- [docs/INSTALL.md](docs/INSTALL.md) — 셸별 설치 (bash/zsh/fish)
- [docs/USAGE.md](docs/USAGE.md) — 명령별 사용법, 옵션, 종료 코드
- [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) — 자주 발생하는 문제와 해결

## 라이선스

MIT
