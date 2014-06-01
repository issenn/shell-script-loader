test "$include_01_sh" = . && test_twice 'include/01.sh'
include_01_sh=.

test_log  '(include/01.sh)    ' -- "$@"
test_exec '(include/01.sh)    ' include 'include/./../include/././02.sh' A B C D
test_exec '(include/01.sh)    ' include 'include//.///..////include///.//.///03.sh'
test_exec '(include/01.sh)    ' include './scripts/b/include/./../include/././04.sh' A
