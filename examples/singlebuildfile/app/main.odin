package main

import "core:fmt"
import simpleenv "simpleenv:simpleenv"
import toml "toml_parser:toml_parser"

Config :: struct {
	name: string,
	port: int,
}

main :: proc() {
	config: Config
	toml.unmarshal_string(`name = "odin-example"
port = 8080`, &config)

	values, err := simpleenv.parse("ENV=development")
	defer simpleenv.delete_map(values)
	if err != nil {
		return
	}

	fmt.printf("%s name=%s port=%d\n", values["ENV"], config.name, config.port)
}
