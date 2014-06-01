test "$includex_01_01_sh" = . && test_twice 'includex/01/01.sh'
includex_01_01_sh=.

test_log  '(includex/01/01.sh)' -- "$@"
