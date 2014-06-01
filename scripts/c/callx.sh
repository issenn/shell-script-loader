test_log  '(callx.sh)         ' -- "$@"
test_exec '(callx.sh)         ' callx 'callx/01.sh'
test_exec '(callx.sh)         ' callx 'callx/0?.sh' A
test_exec '(callx.sh)         ' callx -name 'callx/0?.sh' A B
test_exec '(callx.sh)         ' callx -regex 'callx/0.\.sh' A B C
test_exec '(callx.sh)         ' callx './scripts/c/callx/01.sh' A B C D
test_exec '(callx.sh)         ' callx './scripts/c/callx/0?.sh'
test_exec '(callx.sh)         ' callx -name './scripts/c/callx/0?.sh' A
test_exec '(callx.sh)         ' callx -regex './scripts/c/callx/0.\.sh' A B
test_exec '(callx.sh)         ' callx "$TEST_CWD/scripts/c/callx/01.sh" A B C
test_exec '(callx.sh)         ' callx "$TEST_CWD/scripts/c/callx/0?.sh" A B C D
test_exec '(callx.sh)         ' callx -name "$TEST_CWD/scripts/c/callx/0?.sh"
test_exec '(callx.sh)         ' callx -regex "$TEST_CWD/scripts/c/callx/0.\.sh" A
