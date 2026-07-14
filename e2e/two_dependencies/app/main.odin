package tests

import "core:testing"
import formatter "formatter:formatter"
import parser "parser:parser"

@(test)
two_external_dependencies_test :: proc(t: ^testing.T) {
	testing.expect_value(t, formatter.decorate(parser.answer()), "answer=42")
}
