test_log  '(load/01.sh)       ' -- "$@"

test_exec '(load/01.sh)       ' load 'load/01/01.sh'
test_exec '(load/01.sh)       ' load './scripts/b/load/01/02.sh'
