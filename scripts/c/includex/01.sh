test "$includex_01_sh" = . && test_twice 'includex/01.sh'
includex_01_sh=.

test_log  '(includex/01.sh)   ' -- "$@"
test_exec '(includex/01.sh)   ' includex 'includex/02.sh'
test_exec '(includex/01.sh)   ' includex 'includex/01/01.sh'
