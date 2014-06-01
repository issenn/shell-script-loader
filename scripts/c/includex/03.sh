test "$includex_03_sh" = . && test_twice 'includex/03.sh'
includex_03_sh=.

test_log  '(includex/03.sh)   ' -- "$@"
test_exec '(includex/03.sh)   ' includex 'includex/0?.sh'
test_exec '(includex/03.sh)   ' includex 'includex/01/0?.sh'
