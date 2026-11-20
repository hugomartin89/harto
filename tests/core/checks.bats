#!/usr/bin/env bats

load '../helpers/setup'

setup() {
  HARTO_ROOT=$(harto_test_root)
  export HARTO_ROOT
}

@test "conventional commit subjects are accepted" {
  local file="${BATS_TEST_TMPDIR}/message"
  printf 'feat(devhost): persist routes outside the repository\n' > "$file"
  run "${HARTO_ROOT}/scripts/check-commits.sh" --file "$file"
  [ "$status" -eq 0 ]
}

@test "non-conventional subjects are rejected" {
  local file="${BATS_TEST_TMPDIR}/message"
  printf 'Update stuff.\n' > "$file"
  run "${HARTO_ROOT}/scripts/check-commits.sh" --file "$file"
  [ "$status" -ne 0 ]
}

@test "the generic scan rejects a public host in a fixture" {
  local file="${BATS_TEST_TMPDIR}/sample.txt"
  printf 'see %s.%s for details\n' "secret.example" "com" > "$file"
  run "${HARTO_ROOT}/scripts/check-generic.sh" --paths "$file"
  [ "$status" -ne 0 ]
}

@test "the generic scan allows the public RDS CA host and rejects other amazonaws hosts" {
  local file="${BATS_TEST_TMPDIR}/sample.txt"
  printf 'https://truststore.pki.rds.amazonaws.com/global/global-bundle.pem\n' > "$file"
  printf 'https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html\n' >> "$file"
  run "${HARTO_ROOT}/scripts/check-generic.sh" --paths "$file"
  [ "$status" -eq 0 ]
  printf '%s.%s.%s\n' "db.cluster.rds" "amazonaws" "com" > "$file"
  run "${HARTO_ROOT}/scripts/check-generic.sh" --paths "$file"
  [ "$status" -ne 0 ]
}

@test "the generic scan allows local.test" {
  local file="${BATS_TEST_TMPDIR}/sample.txt"
  printf 'open https://app.local.test\n' > "$file"
  run "${HARTO_ROOT}/scripts/check-generic.sh" --paths "$file"
  [ "$status" -eq 0 ]
}

@test "the generic scan succeeds when git lists no files" {
  mkdir -p "${BATS_TEST_TMPDIR}/bin"
  printf '#!/bin/sh\nexit 0\n' > "${BATS_TEST_TMPDIR}/bin/git"
  chmod +x "${BATS_TEST_TMPDIR}/bin/git"
  run env PATH="${BATS_TEST_TMPDIR}/bin:${PATH}" "${HARTO_ROOT}/scripts/check-generic.sh"
  [ "$status" -eq 0 ]
}

@test "the denylist scan uses only the requested paths" {
  local listed="${BATS_TEST_TMPDIR}/listed.txt"
  local other="${BATS_TEST_TMPDIR}/other.txt"
  local deny="${BATS_TEST_TMPDIR}/deny"
  printf 'hello\n' > "$listed"
  printf 'secret-term\n' > "$other"
  printf 'secret-term\n' > "$deny"
  run env HARTO_DENYLIST="$deny" "${HARTO_ROOT}/scripts/check-generic.sh" --paths "$listed"
  [ "$status" -eq 0 ]
  run env HARTO_DENYLIST="$deny" "${HARTO_ROOT}/scripts/check-generic.sh" --paths "$other"
  [ "$status" -ne 0 ]
  [[ "$output" == *"forbidden term from denylist"* ]]
}

_harto_git_repo() {
  local repo="${BATS_TEST_TMPDIR}/repo"
  mkdir -p "$repo"
  cd "$repo"
  git init
  git config user.name "Test User"
  git config user.email "$(printf '%s@%s.%s' tester example invalid)"
}

@test "pre-commit passes when nothing is staged" {
  _harto_git_repo
  printf 'see %s.%s for details\n' "secret.example" "com" > bad.txt
  run "${HARTO_ROOT}/.githooks/pre-commit"
  [ "$status" -eq 0 ]
}

@test "pre-commit rejects a staged public host" {
  _harto_git_repo
  printf 'see %s.%s for details\n' "secret.example" "com" > bad.txt
  git add bad.txt
  run git -c "core.hooksPath=${HARTO_ROOT}/.githooks" commit -m "feat(core): add a sample"
  [ "$status" -ne 0 ]
  [[ "$output" == *"domain"* ]]
}

@test "pre-commit accepts a clean staged file" {
  _harto_git_repo
  printf 'hello\n' > clean.txt
  git add clean.txt
  run git -c "core.hooksPath=${HARTO_ROOT}/.githooks" commit -m "feat(core): add a sample"
  [ "$status" -eq 0 ]
}
