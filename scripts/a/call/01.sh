test_log  '(call/01.sh)       ' -- "$@"

test_exec '(call/01.sh)       ' call 'call/01/01.sh'
test "$?" -eq 0 || test_fail 'call returned nonzero.'

test_exec '(call/01.sh)       ' call './scripts/b/call/01/02.sh'
test "$?" -eq 0 || test_fail 'call returned nonzero.'
