# fish completion for claude-profiler

function __cprof_profiles
    claude-profiler list --quiet 2>/dev/null
end

# Disable file completion for the main command
complete -c claude-profiler -f

# Subcommands
complete -c claude-profiler -n "__fish_use_subcommand" -a "init"      -d "첫 실행 마이그레이션"
complete -c claude-profiler -n "__fish_use_subcommand" -a "list"      -d "프로파일 목록"
complete -c claude-profiler -n "__fish_use_subcommand" -a "current"   -d "현재 활성 프로파일"
complete -c claude-profiler -n "__fish_use_subcommand" -a "switch"    -d "프로파일 전환"
complete -c claude-profiler -n "__fish_use_subcommand" -a "create"    -d "새 프로파일 생성"
complete -c claude-profiler -n "__fish_use_subcommand" -a "delete"    -d "프로파일 삭제"
complete -c claude-profiler -n "__fish_use_subcommand" -a "rename"    -d "이름 변경"
complete -c claude-profiler -n "__fish_use_subcommand" -a "export"    -d "tarball 내보내기"
complete -c claude-profiler -n "__fish_use_subcommand" -a "import"    -d "tarball 가져오기"
complete -c claude-profiler -n "__fish_use_subcommand" -a "backup"    -d "백업 관리"
complete -c claude-profiler -n "__fish_use_subcommand" -a "uninstall" -d "도구 제거"
complete -c claude-profiler -n "__fish_use_subcommand" -a "doctor"    -d "일관성 진단"
complete -c claude-profiler -n "__fish_use_subcommand" -a "version"   -d "버전"
complete -c claude-profiler -n "__fish_use_subcommand" -a "help"      -d "도움말"

# Arguments per command — profile names
complete -c claude-profiler -n "__fish_seen_subcommand_from switch use delete rm rename mv export" -a "(__cprof_profiles)"

# create
complete -c claude-profiler -n "__fish_seen_subcommand_from create new" -l from -d "복제 원본" -a "(__cprof_profiles)"
complete -c claude-profiler -n "__fish_seen_subcommand_from create new" -l empty -d "빈 프로파일"

# init
complete -c claude-profiler -n "__fish_seen_subcommand_from init" -l yes -d "자동 동의"
complete -c claude-profiler -n "__fish_seen_subcommand_from init" -l no-git -d "git 비활성"

# list
complete -c claude-profiler -n "__fish_seen_subcommand_from list ls" -l quiet -d "이름만 출력"
complete -c claude-profiler -n "__fish_seen_subcommand_from list ls" -l json  -d "JSON 출력"

# backup
complete -c claude-profiler -n "__fish_seen_subcommand_from backup; and not __fish_seen_subcommand_from list prune restore" -a "list prune restore"

# uninstall
complete -c claude-profiler -n "__fish_seen_subcommand_from uninstall" -l restore -d "지정 프로파일 복원" -a "(__cprof_profiles)"
complete -c claude-profiler -n "__fish_seen_subcommand_from uninstall" -l restore-origin -d "원본 백업 원복"
complete -c claude-profiler -n "__fish_seen_subcommand_from uninstall" -l keep-data -d "데이터 보존"
complete -c claude-profiler -n "__fish_seen_subcommand_from uninstall" -l archive-others -d "다른 프로파일 보관"
complete -c claude-profiler -n "__fish_seen_subcommand_from uninstall" -l discard-others -d "다른 프로파일 삭제"
complete -c claude-profiler -n "__fish_seen_subcommand_from uninstall" -l keep-others -d "다른 프로파일 그대로"
complete -c claude-profiler -n "__fish_seen_subcommand_from uninstall" -l yes -d "자동 동의"
complete -c claude-profiler -n "__fish_seen_subcommand_from uninstall" -l force -d "활성 세션 검사 우회"

# import — file completion
complete -c claude-profiler -n "__fish_seen_subcommand_from import" -F -r
complete -c claude-profiler -n "__fish_seen_subcommand_from import" -l name -d "새 이름"
