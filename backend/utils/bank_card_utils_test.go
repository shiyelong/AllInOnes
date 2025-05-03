package utils

import (
	"fmt"
	"testing"
)

func TestIsValidCardNumber(t *testing.T) {
	cardNumber := "6225887654321234"
	result := IsValidCardNumber(cardNumber)
	fmt.Printf("Card number %s is valid: %v\n", cardNumber, result)
}
