test "$include_02_sh" = . && test_twice 'include/02.sh'
include_02_sh=.

test_log  '(include/02.sh)    ' -- "$@"
test_exec '(include/02.sh)    ' include './/scripts///b////include///.//..///include////.//.///03.sh' A B
test_exec '(include/02.sh)    ' include "../$TEST_CWD_BASE/scripts/b/include/./../include/././04.sh" A B C
