# 설치 가이드

## 의존성

**필수**
- bash 3.2+ (macOS 기본 호환), 권장 4+
- coreutils: `mv`, `ln`, `mkdir`, `rm`, `cp`, `cat`, `mktemp`
- `tar`, `gzip`, `find`, `grep`, `awk`, `sed`

**선택**
- `git` — 통합 저장소 기능. 미설치 시 init이 `--no-git` 모드로만 진행 가능
- `python3` — `realpath` 등 BSD/GNU 차이 흡수 fallback

## 설치 (자동)

```bash
bash build.sh             # dist/ 생성
bash dist/install.sh
```

기본 설치 위치는 `~/.local/`. PREFIX 변경:
```bash
bash dist/install.sh --prefix /usr/local
```

설치 스크립트는 다음을 수행합니다:
- `claude-profiler` 바이너리 → `<prefix>/bin/`
- 완성 스크립트 → `<prefix>/share/claude-profiler/completions/`
- 사용 셸을 자동 감지하여 적절한 rc 파일에 PATH/완성 등록 (마커 블록으로 구분되어 추후 깔끔히 제거 가능)

설치 후 새 셸을 열거나 rc 파일을 source 하면 즉시 사용 가능:

```bash
exec $SHELL               # 또는
source ~/.zshrc           # zsh 사용자
source ~/.bashrc          # Linux bash 사용자
source ~/.bash_profile    # macOS bash 사용자
source ~/.config/fish/config.fish    # fish 사용자
```

검증:
```bash
claude-profiler version
```

## 설치 (수동)

자동 설치를 원하지 않거나 시스템 패키지로 관리하려면 다음을 직접 수행:

### 1. 바이너리 설치

```bash
install -m 0755 dist/claude-profiler /usr/local/bin/claude-profiler
```

### 2. 셸별 완성 등록

#### bash (Linux)

`~/.bashrc` 에 추가:
```bash
export PATH="/usr/local/bin:$PATH"
[ -f /usr/local/share/claude-profiler/completions/claude-profiler.bash ] \
  && . /usr/local/share/claude-profiler/completions/claude-profiler.bash
```

#### bash (macOS)

`~/.bash_profile` 에 위와 동일한 내용 추가.

#### zsh

```bash
sudo cp dist/completions/_claude-profiler /usr/local/share/zsh/site-functions/
```

또는 `~/.zshrc` 에 추가:
```zsh
fpath=("$HOME/.local/share/claude-profiler/completions" $fpath)
autoload -Uz compinit && compinit -i
```

#### fish

```bash
mkdir -p ~/.config/fish/completions
cp dist/completions/claude-profiler.fish ~/.config/fish/completions/
```

PATH 등록은 `~/.config/fish/config.fish` 에:
```fish
set -gx PATH /usr/local/bin $PATH
```

## 제거

설치한 파일과 셸 rc의 마커 블록만 제거 (사용자 데이터는 보존):
```bash
bash dist/install.sh --uninstall
```

도구 + 사용자 프로파일 데이터까지 모두 정리하려면 도구 명령:
```bash
claude-profiler uninstall                    # 활성 프로파일을 ~/.claude/로 복원
claude-profiler uninstall --restore-origin   # 도구 사용 이전 상태로 완전 원복
```

자세한 uninstall 옵션은 [docs/USAGE.md](USAGE.md#uninstall) 참고.
