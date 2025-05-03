package utils

import (
	"fmt"
	"math/rand"
	"time"
)

// 格式化金额
func FormatMoney(amount float64) string {
	return fmt.Sprintf("%.2f 元", amount)
}

// 生成随机验证码（已在verification.go中定义，此处为兼容保留）
func GenerateRandomCodeCompat(length int) string {
	rand.Seed(time.Now().UnixNano())
	const digits = "0123456789"
	code := make([]byte, length)
	for i := 0; i < length; i++ {
		code[i] = digits[rand.Intn(len(digits))]
	}
	return string(code)
}

// 生成随机字符串
func GenerateRandomString(length int) string {
	rand.Seed(time.Now().UnixNano())
	const chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
	result := make([]byte, length)
	for i := 0; i < length; i++ {
		result[i] = chars[rand.Intn(len(chars))]
	}
	return string(result)
}

// 生成随机数字ID
func GenerateRandomNumericID(length int) string {
	rand.Seed(time.Now().UnixNano())
	const digits = "0123456789"
	id := make([]byte, length)
	for i := 0; i < length; i++ {
		id[i] = digits[rand.Intn(len(digits))]
	}
	return string(id)
}
