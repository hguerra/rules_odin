package formatter

import "core:fmt"

decorate :: proc(value: int) -> string {
	return fmt.tprintf("answer=%d", value)
}
