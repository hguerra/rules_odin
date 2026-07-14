package main

import config "config:config"
import "core:fmt"
import simpleenv "simpleenv:simpleenv"

main :: proc() {
	value, ok := config.load("name = \"odin-example\"\nport = 8080")
	values, err := simpleenv.parse("ENV=development")
	defer simpleenv.delete_map(values)
	if !ok || err != nil {return}
	fmt.printf("%s name=%s port=%d\n", values["ENV"], value.Name, value.Port)
}
