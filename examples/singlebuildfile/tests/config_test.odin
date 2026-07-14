package tests

import "core:testing"
import simpleenv "simpleenv:simpleenv"
import toml "toml_parser:toml_parser"

Config :: struct {
	name: string,
	port: int,
}

@(test)
loads_two_external_dependencies :: proc(t: ^testing.T) {
	config: Config
	testing.expect(t, toml.unmarshal_string("name = \"odin\"\nport = 8080", &config) == .None)
	values, err := simpleenv.parse("ENV=test")
	defer simpleenv.delete_map(values)
	testing.expect(t, err == nil)
	testing.expect_value(t, values["ENV"], "test")
	testing.expect_value(t, config.port, 8080)
}
