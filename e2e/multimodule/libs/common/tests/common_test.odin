package common_tests

import common "common:common"
import "core:testing"

@(test)
common_dependency_test :: proc(t: ^testing.T) {
	testing.expect_value(t, common.value(), 43)
}
