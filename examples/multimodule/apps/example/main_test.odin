package main

import config "config:config"
import "core:testing"
import simpleenv "simpleenv:simpleenv"

@(test)
loads_library_and_external_dependency :: proc(t: ^testing.T) {
	value, ok := config.load("name = \"odin\"\nport = 8080")
	values, err := simpleenv.parse("ENV=test")
	defer simpleenv.delete_map(values)
	testing.expect(t, ok && err == nil)
	testing.expect_value(t, value.Name, "odin")
	testing.expect_value(t, values["ENV"], "test")
}
