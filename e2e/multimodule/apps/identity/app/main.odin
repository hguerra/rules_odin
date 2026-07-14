package identity_tests

import common "common:common"
import "core:testing"

@(test)
identity_common_module_test :: proc(t: ^testing.T) {
	testing.expect_value(t, common.value(), 43)
}
