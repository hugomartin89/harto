#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

load '../../../tests/helpers/setup'

setup_file() {
  harto_test_prepare
  export HARTO_STUB_KEYCHAIN="${BATS_FILE_TMPDIR}/prepared/keychain"
  export PATH="${BATS_TEST_DIRNAME}/stubs:${PATH}"
  "$(harto_bin)" plugin enable localenv
}

setup() {
  harto_test_isolate
  export HARTO_STUB_KEYCHAIN="${BATS_TEST_TMPDIR}/keychain"
  export PATH="${BATS_TEST_DIRNAME}/stubs:${PATH}"
  harto_test_apply_prepared
  STORE_DIR="${XDG_CONFIG_HOME}/harto/plugins/localenv"
  KEY_FILE="${HARTO_STUB_KEYCHAIN}/harto-localenv.$(id -un)"
  WORK="${BATS_TEST_TMPDIR}/work"
  BLOG="${WORK}/blog"
  mkdir -p "$BLOG"
}

hl() {
  "$(harto_bin)" localenv "$@"
}

real_path() {
  (cd "$1" && pwd -P)
}

@test "enable creates the plain project index and a Keychain key" {
  [ -f "${STORE_DIR}/projects.ini" ]
  grep -q '\[projects\]' "${STORE_DIR}/projects.ini"
  [ ! -e "${STORE_DIR}/blog" ]
  [ -f "$KEY_FILE" ]
}

@test "the project file is encrypted and the index stays in the clear" {
  cd "$BLOG"
  hl init blog
  hl set local PORT 3000
  hl set local DATABASE_URL postgres://localhost/blog
  [ -f "${STORE_DIR}/blog/env.ini.enc" ]
  grep -q '^blog = ' "${STORE_DIR}/projects.ini"
  run grep -q PORT "${STORE_DIR}/projects.ini"
  [ "$status" -eq 1 ]
  for needle in PORT DATABASE_URL localhost; do
    run grep -q "$needle" "${STORE_DIR}/blog/env.ini.enc"
    [ "$status" -eq 1 ]
  done
}

@test "setup rejects arguments and does not change the index" {
  cp "${STORE_DIR}/projects.ini" "${BATS_TEST_TMPDIR}/before.ini"
  run hl setup extra
  [ "$status" -eq 2 ]
  cmp "${STORE_DIR}/projects.ini" "${BATS_TEST_TMPDIR}/before.ini"
}

@test "init refuses --plain and --encrypt together" {
  run hl init blog --plain --encrypt
  [ "$status" -eq 2 ]
}

@test "setup again keeps the index and the project file" {
  cd "$BLOG"
  hl init blog
  hl set local PORT 3000
  cp "${STORE_DIR}/projects.ini" "${BATS_TEST_TMPDIR}/before.ini"
  cp "${STORE_DIR}/blog/env.ini.enc" "${BATS_TEST_TMPDIR}/before.enc"
  run hl setup
  [ "$status" -eq 0 ]
  cmp "${STORE_DIR}/projects.ini" "${BATS_TEST_TMPDIR}/before.ini"
  cmp "${STORE_DIR}/blog/env.ini.enc" "${BATS_TEST_TMPDIR}/before.enc"
}

@test "init registers the current directory and which resolves it" {
  cd "$BLOG"
  run hl init blog
  [ "$status" -eq 0 ]
  run hl which
  [ "$status" -eq 0 ]
  [ "$output" = "$(printf 'blog\t%s' "$(real_path "$BLOG")")" ]
}

@test "init with the same name and path changes nothing" {
  cd "$BLOG"
  hl init blog
  cp "${STORE_DIR}/projects.ini" "${BATS_TEST_TMPDIR}/before.ini"
  cp "${STORE_DIR}/blog/env.ini.enc" "${BATS_TEST_TMPDIR}/before.enc"
  run hl init blog
  [ "$status" -eq 0 ]
  cmp "${STORE_DIR}/projects.ini" "${BATS_TEST_TMPDIR}/before.ini"
  cmp "${STORE_DIR}/blog/env.ini.enc" "${BATS_TEST_TMPDIR}/before.enc"
}

@test "init refuses a directory that belongs to another project" {
  cd "$BLOG"
  hl init blog
  run hl init shop
  [ "$status" -eq 1 ]
  [[ "$output" == *"already belongs to project blog"* ]]
}

@test "init with another path asks before it replaces the project" {
  cd "$BLOG"
  hl init blog
  mkdir -p "${WORK}/moved"
  cd "${WORK}/moved"
  run bash -c "printf 'n\n' | '$(harto_bin)' localenv init blog"
  [ "$status" -eq 1 ]
  cd "$BLOG"
  [ "$(hl which)" = "$(printf 'blog\t%s' "$(real_path "$BLOG")")" ]

  cd "${WORK}/moved"
  HARTO_YES=1 hl init blog
  [ "$(hl which)" = "$(printf 'blog\t%s' "$(real_path "${WORK}/moved")")" ]
}

@test "which resolves from a subdirectory" {
  cd "$BLOG"
  hl init blog
  mkdir -p "$BLOG/src/deep"
  cd "$BLOG/src/deep"
  run hl which
  [ "$status" -eq 0 ]
  [[ "$output" == blog$'\t'* ]]
}

@test "the longest matching project path wins" {
  cd "$BLOG"
  hl init blog
  mkdir -p "$BLOG/api/src"
  cd "$BLOG/api"
  hl init api
  cd "$BLOG/api/src"
  run hl which
  [ "$status" -eq 0 ]
  [[ "$output" == api$'\t'* ]]
}

@test "a sibling directory with the same prefix does not match" {
  cd "$BLOG"
  hl init blog
  mkdir -p "${WORK}/blog-old"
  cd "${WORK}/blog-old"
  run hl which
  [ "$status" -eq 1 ]
  [[ "$output" == *"no project for this directory"* ]]
}

@test "set, get and unset round-trip a value with spaces" {
  cd "$BLOG"
  hl init blog
  hl set local MESSAGE "hello world"
  run hl get local MESSAGE
  [ "$status" -eq 0 ]
  [ "$output" = "hello world" ]
  hl unset local MESSAGE
  run hl get local MESSAGE
  [ "$status" -eq 1 ]
}

@test "set on an existing variable asks before it replaces the value" {
  cd "$BLOG"
  hl init blog
  hl set local PORT 3000
  run bash -c "printf 'n\n' | '$(harto_bin)' localenv set local PORT 4000"
  [ "$status" -eq 1 ]
  [[ "$output" != *"3000"* ]]
  [ "$(hl get local PORT)" = "3000" ]

  HARTO_YES=1 hl set local PORT 4000
  [ "$(hl get local PORT)" = "4000" ]
}

@test "dry-run set does not change the store" {
  cd "$BLOG"
  hl init blog
  hl set local PORT 3000
  run "$(harto_bin)" --dry-run localenv set local PORT 9
  [ "$status" -eq 0 ]
  [[ "$output" == *"[dry-run]"* ]]
  [ "$(hl get local PORT)" = "3000" ]
}

@test "get and unset fail for a missing variable" {
  cd "$BLOG"
  hl init blog
  hl set local PORT 3000
  run hl get local MISSING
  [ "$status" -eq 1 ]
  run hl unset local MISSING
  [ "$status" -eq 1 ]
}

@test "list shows projects outside a project and environments inside one" {
  cd "$BLOG"
  hl init blog
  hl set local PORT 3000
  hl set ci PORT 3000
  cd "$BATS_TEST_TMPDIR"
  run hl list
  [ "$status" -eq 0 ]
  [[ "$output" == *"blog"$'\t'* ]]
  cd "$BLOG"
  run hl list
  [ "$status" -eq 0 ]
  [ "$output" = $'ci\nlocal' ] || [ "$output" = $'local\nci' ]
}

@test "list --json returns the environment names" {
  cd "$BLOG"
  hl init blog
  hl set local PORT 3000
  run "$(harto_bin)" --json localenv list
  [ "$status" -eq 0 ]
  [[ "$output" == *'"name":"local"'* ]]
}

@test "show --json returns the variables as one object" {
  cd "$BLOG"
  hl init blog
  hl set local PORT 3000
  run "$(harto_bin)" --json localenv show local
  [ "$status" -eq 0 ]
  [ "$output" = '{"PORT":"3000"}' ]
}

@test "show --json refuses a value that contains spaces" {
  cd "$BLOG"
  hl init blog
  hl set local MESSAGE "hello world"
  run "$(harto_bin)" --json localenv show local
  [ "$status" -eq 1 ]
  [[ "$output" == *"MESSAGE has spaces in its value"* ]]
}

@test "which --json returns the project name and path" {
  cd "$BLOG"
  hl init blog
  run "$(harto_bin)" --json localenv which
  [ "$status" -eq 0 ]
  [ "$output" = "{\"name\":\"blog\",\"path\":\"$(real_path "$BLOG")\"}" ]
}

@test "export prints lines that a shell reads back with the same values" {
  cd "$BLOG"
  hl init blog
  hl set local MESSAGE "hello world"
  hl set local PORT 3000
  run hl export local
  [ "$status" -eq 0 ]
  run bash -c 'eval "$1"; printf "%s|%s" "$MESSAGE" "$PORT"' _ "$output"
  [ "$output" = "hello world|3000" ]
}

@test "exec runs the command with the variables from the project directory" {
  cd "$BLOG"
  hl init blog
  hl set local PORT 3000
  run hl exec local bash -c 'printf "%s|%s" "$PORT" "$(pwd -P)"'
  [ "$status" -eq 0 ]
  [ "$output" = "3000|$(real_path "$BLOG")" ]
}

@test "start loads the variables and enters the project directory" {
  cd "$BLOG"
  hl init blog
  hl set local PORT 3000
  printf '#!/usr/bin/env bash\nprintf "%%s|%%s\\n" "$PORT" "$(pwd -P)"\n' > "${BATS_TEST_TMPDIR}/fakeshell"
  chmod +x "${BATS_TEST_TMPDIR}/fakeshell"
  SHELL="${BATS_TEST_TMPDIR}/fakeshell" run --separate-stderr hl start local
  [ "$status" -eq 0 ]
  [ "$output" = "3000|$(real_path "$BLOG")" ]
}

@test "start --dry-run does not start a shell" {
  cd "$BLOG"
  hl init blog
  hl set local PORT 3000
  printf '#!/usr/bin/env bash\ntouch "%s"\n' "${BATS_TEST_TMPDIR}/started" > "${BATS_TEST_TMPDIR}/fakeshell"
  chmod +x "${BATS_TEST_TMPDIR}/fakeshell"
  SHELL="${BATS_TEST_TMPDIR}/fakeshell" run "$(harto_bin)" --dry-run localenv start local
  [ "$status" -eq 0 ]
  [[ "$output" == *"[dry-run]"* ]]
  [ ! -e "${BATS_TEST_TMPDIR}/started" ]
}

@test "set and unset in a started bash update that shell" {
  cd "$BLOG"
  hl init blog
  hl set local PORT 3000
  bin_dir=$(dirname "$(harto_bin)")
  export PATH="${bin_dir}:${PATH}"
  export HARTO_YES=1
  script='harto localenv set local PORT 4000
printf "set=%s\n" "$PORT"
harto localenv unset local PORT
printf "unset=%s\n" "${PORT-gone}"
exit'
  SHELL=/bin/bash run --separate-stderr bash -c 'printf "%s\n" "$1" | "$2" localenv start local' _ "$script" "$(harto_bin)"
  [ "$status" -eq 0 ]
  [ "$output" = $'set=4000\nunset=gone' ]
}

@test "set and unset in a started zsh update that shell" {
  cd "$BLOG"
  hl init blog
  hl set local PORT 3000
  bin_dir=$(dirname "$(harto_bin)")
  export PATH="${bin_dir}:${PATH}"
  export HARTO_YES=1
  script='harto localenv set local PORT 4000
printf "set=%s\n" "$PORT"
harto localenv unset local PORT
printf "unset=%s\n" "${PORT-gone}"
exit'
  SHELL=/bin/zsh run --separate-stderr bash -c 'printf "%s\n" "$1" | "$2" localenv start local' _ "$script" "$(harto_bin)"
  [ "$status" -eq 0 ]
  [[ "$output" == *set=4000* ]]
  [[ "$output" == *unset=gone* ]]
}

@test "import copies a dotenv file without running it" {
  cd "$BLOG"
  hl init blog
  cat > "${BATS_TEST_TMPDIR}/app.env" <<'EOF'
# comment
export PORT=3000
MESSAGE="hello world"
TOKEN='$(printf pwned)'
EMPTY=
EOF
  hl import local "${BATS_TEST_TMPDIR}/app.env"
  [ "$(hl get local PORT)" = "3000" ]
  [ "$(hl get local MESSAGE)" = "hello world" ]
  [ "$(hl get local TOKEN)" = '$(printf pwned)' ]
  [ "$(hl get local EMPTY)" = "" ]
}

@test "import asks before replacing and dry-run does not write" {
  cd "$BLOG"
  hl init blog
  hl set local PORT 3000
  printf 'PORT=4000\nNEW=1\n' > "${BATS_TEST_TMPDIR}/app.env"
  run "$(harto_bin)" --dry-run localenv import local "${BATS_TEST_TMPDIR}/app.env"
  [ "$status" -eq 0 ]
  [[ "$output" == *"[dry-run]"* ]]
  [ "$(hl get local PORT)" = "3000" ]
  run bash -c "printf 'n\n' | '$(harto_bin)' localenv import local '${BATS_TEST_TMPDIR}/app.env'"
  [ "$status" -eq 1 ]
  [ "$(hl get local PORT)" = "3000" ]
  HARTO_YES=1 hl import local "${BATS_TEST_TMPDIR}/app.env"
  [ "$(hl get local PORT)" = "4000" ]
  [ "$(hl get local NEW)" = "1" ]
}

@test "import rejects a line that is not a variable" {
  cd "$BLOG"
  hl init blog
  printf 'not a variable\n' > "${BATS_TEST_TMPDIR}/app.env"
  run hl import local "${BATS_TEST_TMPDIR}/app.env"
  [ "$status" -eq 2 ]
  [[ "$output" == *"line 1"* ]]
}

@test "remove deletes one environment after confirmation" {
  cd "$BLOG"
  hl init blog
  hl set local PORT 3000
  hl set ci PORT 3000
  HARTO_YES=1 hl remove local
  run hl list
  [ "$status" -eq 0 ]
  [ "$output" = "ci" ]
  run "$(harto_bin)" --non-interactive localenv remove ci
  [ "$status" -eq 3 ]
  [ "$(hl get ci PORT)" = "3000" ]
}

@test "remove --project deletes the project and its environments" {
  cd "$BLOG"
  hl init blog
  hl set local PORT 3000
  HARTO_YES=1 hl remove --project
  run hl which
  [ "$status" -eq 1 ]
  cd "$BATS_TEST_TMPDIR"
  run hl list
  [[ "$output" != *"blog"* ]]
}

@test "invalid project, environment and variable names are refused" {
  cd "$BLOG"
  run hl init 1bad
  [ "$status" -eq 2 ]
  hl init blog
  run hl set local 1X value
  [ "$status" -eq 2 ]
  run hl set 'bad env' PORT value
  [ "$status" -eq 2 ]
}

@test "a missing Keychain key still lists projects and blocks encrypted reads" {
  cd "$BLOG"
  hl init blog
  hl set local PORT 3000
  rm -f "$KEY_FILE"
  cd "$BATS_TEST_TMPDIR"
  run hl list
  [ "$status" -eq 0 ]
  [[ "$output" == *"blog"* ]]
  cd "$BLOG"
  run hl get local PORT
  [ "$status" -eq 1 ]
  [[ "$output" == *"Keychain"* ]]
}

@test "init --plain and --encrypt convert one project and leave the index in the clear" {
  cd "$BLOG"
  hl init blog
  hl set local PORT 3000
  hl init blog --plain
  [ -f "${STORE_DIR}/blog/env.ini" ]
  [ ! -e "${STORE_DIR}/blog/env.ini.enc" ]
  [ "$(stat -f '%Lp' "${STORE_DIR}/blog/env.ini")" = "600" ]
  grep -q '^blog = ' "${STORE_DIR}/projects.ini"
  [ "$(hl get local PORT)" = "3000" ]

  hl init blog --encrypt
  [ -f "${STORE_DIR}/blog/env.ini.enc" ]
  [ ! -e "${STORE_DIR}/blog/env.ini" ]
  [ "$(hl get local PORT)" = "3000" ]

  mkdir -p "${WORK}/shop"
  cd "${WORK}/shop"
  hl init shop --plain
  [ -f "${STORE_DIR}/shop/env.ini" ]
  [ -f "${STORE_DIR}/blog/env.ini.enc" ]
  grep -q '^blog = ' "${STORE_DIR}/projects.ini"
  grep -q '^shop = ' "${STORE_DIR}/projects.ini"
}

@test "doctor reports each project and does not change the files" {
  cd "$BLOG"
  hl init blog
  hl set local PORT 3000
  cp "${STORE_DIR}/projects.ini" "${BATS_TEST_TMPDIR}/before.ini"
  cp "${STORE_DIR}/blog/env.ini.enc" "${BATS_TEST_TMPDIR}/before.enc"
  run hl doctor
  [ "$status" -eq 0 ]
  [[ "$output" == *"index=present"* ]]
  [[ "$output" == *"key=present"* ]]
  [[ "$output" == *"mode=encrypted"* ]]
  [[ "$output" == *"readable=yes"* ]]
  [[ "$output" == *"current_project=blog"* ]]
  cmp "${STORE_DIR}/projects.ini" "${BATS_TEST_TMPDIR}/before.ini"
  cmp "${STORE_DIR}/blog/env.ini.enc" "${BATS_TEST_TMPDIR}/before.enc"
}

@test "commands explain setup when the index is missing" {
  rm -f "${STORE_DIR}/projects.ini"
  run hl list
  [ "$status" -eq 1 ]
  [[ "$output" == *"not set up"* ]]
}

@test "disable removes the store and keeps the key when asked" {
  cd "$BLOG"
  hl init blog
  run bash -c "printf 'y\nn\n' | '$(harto_bin)' plugin disable localenv"
  [ "$status" -eq 0 ]
  [ ! -e "$STORE_DIR" ]
  [ -f "$KEY_FILE" ]
}

@test "disable removes the key when asked" {
  run bash -c "printf 'y\ny\n' | '$(harto_bin)' plugin disable localenv"
  [ "$status" -eq 0 ]
  [ ! -e "$KEY_FILE" ]
}
