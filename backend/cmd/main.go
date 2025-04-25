package main

import (
	"allinone_backend/api"
)

func main() {
	r := api.SetupRouter()
	r.Run(":3001")
}
