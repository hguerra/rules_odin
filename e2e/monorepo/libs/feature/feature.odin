package feature

import core "shared_core:core"
import parser "parser:parser"

value :: proc() -> int {
	return core.base() + parser.answer()
}
