package email

import "math/rand"
import "time"

func GenerateLocalCode() string {
	const digits = "0123456789"
	rand.Seed(time.Now().UnixNano())
	code := make([]byte, 6)
	for i := range code {
		code[i] = digits[rand.Intn(len(digits))]
	}
	return string(code)
}
