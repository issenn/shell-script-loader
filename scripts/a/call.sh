test_log  '(call.sh)          ' -- "$@"

test_exec '(call.sh)          ' call 'call/01.sh'
test "$?" -eq 0 || test_fail 'call returned nonzero.'

test_exec '(call.sh)          ' call './scripts/a/call/01.sh' A
test "$?" -eq 0 || test_fail 'call returned nonzero.'

test_exec '(call.sh)          ' call "../$TEST_CWD_BASE/scripts/b/call/02.sh" A B
test "$?" -eq 0 || test_fail 'call returned nonzero.'

test_exec '(call.sh)          ' call "$TEST_CWD/scripts/b/call/02.sh" A B C
test "$?" -eq 0 || test_fail 'call returned nonzero.'

test_exec '(call.sh)          ' call 'call/./../call/././02.sh' A B C D
test "$?" -eq 0 || test_fail 'call returned nonzero.'

test_exec '(call.sh)          ' call 'call//.///..////call///.//.///02.sh'
test "$?" -eq 0 || test_fail 'call returned nonzero.'

test_exec '(call.sh)          ' call './scripts/b/call/./../call/././02.sh' A
test "$?" -eq 0 || test_fail 'call returned nonzero.'

test_exec '(call.sh)          ' call './/scripts///b////call///.//..///call////.///.//02.sh' A B
test "$?" -eq 0 || test_fail 'call returned nonzero.'

test_exec '(call.sh)          ' call "../$TEST_CWD_BASE/scripts/b/call/./../call/././02.sh" A B C
test "$?" -eq 0 || test_fail 'call returned nonzero.'

test_exec '(call.sh)          ' call "..//$TEST_CWD_BASE///scripts////b///call//.///..////call///.//.///02.sh" A B C D
test "$?" -eq 0 || test_fail 'call returned nonzero.'

test_exec '(call.sh)          ' call "$TEST_CWD/scripts/b/call/./../call/././02.sh"
test "$?" -eq 0 || test_fail 'call returned nonzero.'

test_exec '(call.sh)          ' call "$TEST_CWD//scripts///b////call///.//..///call////.///.//02.sh" A
test "$?" -eq 0 || test_fail 'call returned nonzero.'
