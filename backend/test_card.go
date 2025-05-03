package main

import (
	"fmt"
	"strings"
)

func main() {
	cardNumber := "6225887654321234"
	fmt.Printf("Card number: %s\n", cardNumber)
	
	// 掩码银行卡号
	maskedCardNumber := maskCardNumber(cardNumber)
	fmt.Printf("Masked card number: %s\n", maskedCardNumber)
}

// 掩码银行卡号，只显示前6位和后4位
func maskCardNumber(cardNumber string) string {
	// 移除空格和破折号
	cardNumber = strings.ReplaceAll(cardNumber, " ", "")
	cardNumber = strings.ReplaceAll(cardNumber, "-", "")

	if len(cardNumber) < 10 {
		return cardNumber // 卡号太短，不做掩码
	}

	prefix := cardNumber[:6]
	suffix := cardNumber[len(cardNumber)-4:]
	masked := strings.Repeat("*", len(cardNumber)-10)

	return fmt.Sprintf("%s%s%s", prefix, masked, suffix)
}
