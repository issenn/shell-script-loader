test "$include_01_01_sh" = . && test_twice 'include/01/01.sh'
include_01_01_sh=.

test_log  '(include/01/01.sh) ' -- "$@"
