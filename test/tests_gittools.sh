#!/bin/bash

. "$(dirname "$0")/../lib/gittools"

setUp() {
  TESTDIR="${SHUNIT_TMPDIR}/${_shunit_test_}"
  mkdir -p "${TESTDIR}"
  pushd "${TESTDIR}" >/dev/null  
}

tearDown() {
  unset GIT_MOCK_DESCRIBE
  unset GIT_MOCK_REVPARSE
  unset GIT_MOCK_REVLIST
}

git_mock() {
  echo "git $*" >&2
  
  case $1 in
    'rev-parse')
      return ${GIT_MOCK_REVPARSE-0}
      ;;
    'describe')
      if [ -n "${GIT_MOCK_DESCRIBE+x}" ]; then
        echo "${GIT_MOCK_DESCRIBE}"
        return 0
      elif [[ " $* " =~ " --always " ]]; then
        echo "1abcdef"
        return 0
      else
        return 1
      fi
      ;;
    'for-each-ref')
      echo "refs/tags/v1.5.0"
      echo "refs/tags/v1.2.4"
      echo "refs/tags/v1.2.3"
      echo "refs/tags/v0.9.0"
      return 0
      ;;
    'rev-list')
      return ${GIT_MOCK_REVLIST-1}
      ;;
    'tag')
      if [[ " $* " =~ " %(contents) " ]]; then
        echo "Change log text for release version ${@: -1}"
        return 0
      elif [[ " $* " =~ " %(taggerdate:short) " ]]; then
        case "${@: -1}" in
          "v1.5.0")
            echo "2022-08-03"
          ;;
          "v1.2.4")
            echo "2022-06-27"
          ;;
          "v1.2.3")
            echo "2022-06-15"
          ;;  
          *)
            return 1
          ;;
        esac        
        return 0
      elif [[ " $* " =~ " %(committerdate:short) " ]]; then
        echo "2021-07-29"
        return 0
      fi
      ;;
  esac

  echo "Error: unrecognized git command '$1'" >&2
  return 1
}

test_git_describe() {
  UTILITY_GIT="git_mock"
  
  GIT_MOCK_DESCRIBE="v1.2.3-0-g1abcdef" 
  local version=$(git_describe v 2>/dev/null)
  assertEquals "1.2.3" "${version}"

  GIT_MOCK_DESCRIBE="v1.2.3-dev1-0-g1abcdef"
  local version=$(git_describe v 2>/dev/null)
  assertEquals "1.2.3-dev1" "${version}"

  GIT_MOCK_DESCRIBE="v1.2.3-3-g1abcdef" 
  local version=$(git_describe v 2>/dev/null)
  assertEquals "1.2.4-dev3+g1abcdef" "${version}"

  GIT_MOCK_DESCRIBE="1.2.3-rc2-3-g1abcdef" 
  local version=$(git_describe 2>/dev/null)
  assertEquals "1.2.3-rc2+p3+g1abcdef" "${version}"

  GIT_MOCK_DESCRIBE="1.2.3-rc2-0-g1abcdef" 
  local version=$(git_describe 2>/dev/null)
  assertEquals "1.2.3-rc2" "${version}"

  GIT_MOCK_DESCRIBE="1.2.3-dev-3-g1abcdef" 
  local version=$(git_describe 2>/dev/null)
  assertEquals "1.2.3-dev3+g1abcdef" "${version}"

  unset GIT_MOCK_DESCRIBE
  local version=$(git_describe 2>/dev/null)
  assertEquals "0.0.0-dirty1+g1abcdef" "${version}"

  GIT_MOCK_REVPARSE=1
  local version=$(git_describe 2>/dev/null)
  assertEquals "0.0.0-nogit" "${version}"  
}

test_git_changelog_pdsc() {
  UTILITY_GIT="git_mock"
  
  GIT_MOCK_DESCRIBE="v1.5.0-3-g1abcdef" 
  
  changelog=$(git_changelog -f pdsc -d -p v)

  read -r -d '' expected <<EOF
<releases>
  <release version="1.5.1-dev3+g1abcdef">
    Active development ...
  </release>
  <release version="1.5.0" date="2022-08-03" tag="v1.5.0">
    Change log text for release version v1.5.0
  </release>
  <release version="1.2.4" date="2022-06-27" tag="v1.2.4">
    Change log text for release version v1.2.4
  </release>
  <release version="1.2.3" date="2022-06-15" tag="v1.2.3">
    Change log text for release version v1.2.3
  </release>
  <release version="0.9.0" date="2021-07-29" tag="v0.9.0">
    Change log text for release version v0.9.0
  </release>
</releases>
EOF

  assertEquals "${expected}" "${changelog}"
}

test_git_changelog_html() {
  UTILITY_GIT="git_mock"
  
  GIT_MOCK_DESCRIBE="v1.5.0-3-g1abcdef" 
  
  changelog=$(git_changelog -f html -p v)

  read -r -d '' expected <<EOF
<table class="cmtable" summary="Revision History">
<tr>
  <th>Version</th>
  <th>Description</th>
</tr>
<tr>
  <td>v1.5.0</td>
  <td>
    Change log text for release version v1.5.0
  </td>
</tr>
<tr>
  <td>v1.2.4</td>
  <td>
    Change log text for release version v1.2.4
  </td>
</tr>
<tr>
  <td>v1.2.3</td>
  <td>
    Change log text for release version v1.2.3
  </td>
</tr>
<tr>
  <td>v0.9.0</td>
  <td>
    Change log text for release version v0.9.0
  </td>
</tr>
</table>
EOF

  assertEquals "${expected}" "${changelog}"
}

. "$(dirname "$0")/shunit2/shunit2"
