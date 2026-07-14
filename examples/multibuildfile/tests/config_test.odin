package tests

import config "config:config"
import "core:testing"
import simpleenv "simpleenv:simpleenv"

@(test)
loads_external_dependencies :: proc(t: ^testing.T) {
	value, ok := config.load("name = \"odin\"\nport = 8080")
	values, err := simpleenv.parse("ENV=test")
	defer simpleenv.delete_map(values)
	testing.expect(t, ok && err == nil)
	testing.expect_value(t, value.Port, 8080)
	testing.expect_value(t, values["ENV"], "test")
}
