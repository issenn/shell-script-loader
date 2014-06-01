test_log  '(include.sh)       ' -- "$@"
test_exec '(include.sh)       ' include 'include/01.sh'
test_exec '(include.sh)       ' include './scripts/a/include/02.sh' A
test_exec '(include.sh)       ' include "../$TEST_CWD_BASE/scripts/b/include/03.sh" A B
test_exec '(include.sh)       ' include "$TEST_CWD/scripts/b/include/04.sh" A B C
