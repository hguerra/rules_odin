package config

import toml "toml_parser:toml_parser"

Config :: struct {
	Name: string,
	Port: int,
}

raw_config :: struct {
	name: string,
	port: int,
}

load :: proc(data: string) -> (Config, bool) {
	raw: raw_config
	if toml.unmarshal_string(data, &raw) != .None {return {}, false}
	return {Name = raw.name, Port = raw.port}, true
}
