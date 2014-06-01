test "$includex_04_sh" = . && test_twice 'includex/04.sh'
includex_04_sh=.

test_log  '(includex/04.sh)   ' -- "$@"
test_exec '(includex/04.sh)   ' includex './scripts/c/includex/0?.sh'
test_exec '(includex/04.sh)   ' includex './scripts/c/includex/01/0?.sh'
