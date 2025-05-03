package main

import (
	"fmt"
	"regexp"
	"strings"
)

// 验证银行卡号是否有效
func IsValidCardNumber(cardNumber string) bool {
	// 移除空格和破折号
	cardNumber = strings.ReplaceAll(cardNumber, " ", "")
	cardNumber = strings.ReplaceAll(cardNumber, "-", "")

	// 检查长度（大多数银行卡是16-19位）
	if len(cardNumber) < 16 || len(cardNumber) > 19 {
		return false
	}

	// 检查是否全是数字
	match, _ := regexp.MatchString("^[0-9]+$", cardNumber)
	if !match {
		return false
	}

	// 使用Luhn算法验证卡号
	return validateLuhn(cardNumber)
}

// Luhn算法验证卡号
func validateLuhn(cardNumber string) bool {
	sum := 0
	nDigits := len(cardNumber)
	parity := nDigits % 2

	for i := 0; i < nDigits; i++ {
		digit := int(cardNumber[i] - '0')

		if i%2 == parity {
			digit *= 2
			if digit > 9 {
				digit -= 9
			}
		}

		sum += digit
	}

	return sum%10 == 0
}

// 掩码银行卡号，只显示前6位和后4位
func MaskCardNumber(cardNumber string) string {
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

func main() {
	// 测试银行卡号验证
	testCardNumber := "6225887654321234"
	fmt.Printf("测试银行卡号 %s 是否有效: %v\n", testCardNumber, IsValidCardNumber(testCardNumber))

	// 测试掩码银行卡号
	maskedCardNumber := MaskCardNumber(testCardNumber)
	fmt.Printf("掩码后的银行卡号: %s\n", maskedCardNumber)

	fmt.Println("测试完成")
}
