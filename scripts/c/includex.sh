test_log  '(includex.sh)      ' -- "$@"
test_exec '(includex.sh)      ' includex 'includex/01.sh'
test_exec '(includex.sh)      ' includex 'includex/0?.sh' A
test_exec '(includex.sh)      ' includex -name 'includex/0?.sh' A B
test_exec '(includex.sh)      ' includex -regex 'includex/0.\.sh' A B C
test_exec '(includex.sh)      ' includex './scripts/c/includex/01.sh' A B C D
test_exec '(includex.sh)      ' includex './scripts/c/includex/0?.sh'
test_exec '(includex.sh)      ' includex -name './scripts/c/includex/0?.sh' A
test_exec '(includex.sh)      ' includex -regex './scripts/c/includex/0.\.sh' A B
test_exec '(includex.sh)      ' includex "$TEST_CWD/scripts/c/includex/01.sh" A B C
test_exec '(includex.sh)      ' includex "$TEST_CWD/scripts/c/includex/0?.sh" A B C D
test_exec '(includex.sh)      ' includex -name "$TEST_CWD/scripts/c/includex/0?.sh"
test_exec '(includex.sh)      ' includex -regex "$TEST_CWD/scripts/c/includex/0.\.sh" A
