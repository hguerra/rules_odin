package tests

import "core:testing"
import parser "parser:parser"

@(test)
parser_answer_test :: proc(t: ^testing.T) {
	testing.expect_value(t, parser.answer(), 42)
}
