package billing_tests

import "core:testing"
import feature "feature:feature"

@(test)
billing_dependency_test :: proc(t: ^testing.T) {
	testing.expect_value(t, feature.value(), 50)
}
