package common

import parser "parser:parser"

value :: proc() -> int {
	return parser.answer() + 1
}
