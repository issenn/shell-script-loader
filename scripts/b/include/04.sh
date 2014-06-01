test "$include_04_sh" = . && test_twice "include/04.sh"
include_04_sh=.

test_log  '(include/04.sh)    ' -- "$@"
test_exec '(include/04.sh)    ' include "$TEST_CWD/scripts/a/include/./../include/././01/01.sh"
test_exec '(include/04.sh)    ' include "$TEST_CWD//scripts///b////include///.//..///include////.///.//01///02.sh" A
