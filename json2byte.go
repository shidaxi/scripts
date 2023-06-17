package main

import (
	"encoding/hex"
	"flag"
	"fmt"
	"os"
	"strings"
)

func main() {
	fileName := flag.String("crefile", "file is nil",
		"the fileName of credential")
	flag.Parse()
	if strings.Compare(*fileName, "file is nil") == 0 {
		panic("nil key")
	}

	creData, err := os.ReadFile(*fileName)
	if err != nil {
		fmt.Println(err)
	}

	fmt.Println(hex.EncodeToString([]byte(creData)))
}
