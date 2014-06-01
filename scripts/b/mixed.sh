test_log  '(mixed.sh)         ' -- "$@"
test_exec '(mixed.sh)         ' load 'mixed/01.sh'
test_exec '(mixed.sh)         ' include 'mixed/02.sh'
test_exec '(mixed.sh)         ' call 'mixed/03.sh'
test_exec '(mixed.sh)         ' load './scripts/b/mixed/04.sh'
test_exec '(mixed.sh)         ' include './scripts/b/mixed/05.sh'
test_exec '(mixed.sh)         ' call './scripts/b/mixed/06.sh'
