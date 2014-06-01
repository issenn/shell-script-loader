test "$include_01_02_sh" = . && test_twice "include/01/02.sh"
include_01_02_sh=.

test_log  '(include/01/02.sh) ' -- "$@"
