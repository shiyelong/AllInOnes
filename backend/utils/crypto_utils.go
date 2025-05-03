package utils

import (
	"crypto/rand"
	"encoding/hex"
)

// 对虚拟货币地址进行掩码处理
func MaskAddress(address string) string {
	if len(address) <= 10 {
		return address
	}

	prefix := address[:6]
	suffix := address[len(address)-4:]
	return prefix + "..." + suffix
}

// 生成随机哈希
func GenerateRandomHash() string {
	bytes := make([]byte, 32)
	rand.Read(bytes)
	return hex.EncodeToString(bytes)
}
