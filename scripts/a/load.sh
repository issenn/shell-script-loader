test_log  '(load.sh)          ' -- "$@"
test_exec '(load.sh)          ' load 'load/01.sh'
test_exec '(load.sh)          ' load './scripts/a/load/01.sh' A
test_exec '(load.sh)          ' load "../$TEST_CWD_BASE/scripts/b/load/02.sh" A B
test_exec '(load.sh)          ' load "$TEST_CWD/scripts/b/load/02.sh" A B C
test_exec '(load.sh)          ' load 'load/./../load/././02.sh' A B C D
test_exec '(load.sh)          ' load 'load//.///..////load///.//.///02.sh' 
test_exec '(load.sh)          ' load './scripts/b/load/./../load/././02.sh' A
test_exec '(load.sh)          ' load './/scripts///b////load///.//..///load////.///.//02.sh' A B
test_exec '(load.sh)          ' load "../$TEST_CWD_BASE/scripts/b/load/./../load/././02.sh" A B C
test_exec '(load.sh)          ' load "..//$TEST_CWD_BASE///scripts/b////load///.//..///load////.///.//02.sh" A B C D
test_exec '(load.sh)          ' load "$TEST_CWD/scripts/b/load/./../load/././02.sh"
test_exec '(load.sh)          ' load "$TEST_CWD//scripts///b////load///.//..///load////.///.//02.sh" A
