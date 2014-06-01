test "$includex_02_sh" = . && test_twice 'includex/02.sh'
includex_02_sh=.

test_log  '(includex/02.sh)   ' -- "$@"
test_exec '(includex/02.sh)   ' includex './scripts/c/includex/03.sh'
test_exec '(includex/02.sh)   ' includex './scripts/c/includex/01/01.sh'
