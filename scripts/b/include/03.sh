test "$include_03_sh" = . && test_twice "include/03.sh"
include_03_sh=.

test_log  '(include/03.sh)    ' -- "$@"
test_exec '(include/03.sh)    ' include "..//$TEST_CWD_BASE///scripts////b///include//.///..////include///.//.///04.sh" A B C D
