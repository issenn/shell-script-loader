test_log  '(loadx.sh)         ' -- "$@"
test_exec '(loadx.sh)         ' loadx 'loadx/01.sh'
test_exec '(loadx.sh)         ' loadx 'loadx/0?.sh' A
test_exec '(loadx.sh)         ' loadx -name 'loadx/0?.sh' A B
test_exec '(loadx.sh)         ' loadx -regex 'loadx/0.\.sh' A B C
test_exec '(loadx.sh)         ' loadx './scripts/c/loadx/01.sh' A B C D
test_exec '(loadx.sh)         ' loadx './scripts/c/loadx/0?.sh'
test_exec '(loadx.sh)         ' loadx -name './scripts/c/loadx/0?.sh' A
test_exec '(loadx.sh)         ' loadx -regex './scripts/c/loadx/0.\.sh' A B
test_exec '(loadx.sh)         ' loadx "$TEST_CWD/scripts/c/loadx/01.sh" A B C
test_exec '(loadx.sh)         ' loadx "$TEST_CWD/scripts/c/loadx/0?.sh" A B C D
test_exec '(loadx.sh)         ' loadx -name "$TEST_CWD/scripts/c/loadx/0?.sh"
test_exec '(loadx.sh)         ' loadx -regex "$TEST_CWD/scripts/c/loadx/0.\.sh" A
