package feature

import "core:fmt"
import shared_core "shared_core:core"

print_message :: proc() {
	fmt.println(shared_core.message())
}
