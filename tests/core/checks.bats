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

@test "the generic scan allows local.test" {
  local file="${BATS_TEST_TMPDIR}/sample.txt"
  printf 'open https://app.local.test\n' > "$file"
  run "${HARTO_ROOT}/scripts/check-generic.sh" --paths "$file"
  [ "$status" -eq 0 ]
}
