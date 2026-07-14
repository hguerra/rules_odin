package feature

import "core:testing"

@(test)
transitive_value_test :: proc(t: ^testing.T) {
	testing.expect_value(t, value(), 50)
}
