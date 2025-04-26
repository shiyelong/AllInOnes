package utils

import (
	"time"
	"github.com/golang-jwt/jwt/v5"
	"errors"
)

var jwtSecret = []byte("allinone_secret_key")

// Claims 定义自定义的 token 声明
// 可根据需要添加字段
// Account 用于标识用户身份
// ExpiresAt 用于设置过期时间

type Claims struct {
	Account string `json:"account"`
	jwt.RegisteredClaims
}

// GenerateToken 生成 JWT token
func GenerateToken(account string) (string, error) {
	claims := Claims{
		Account: account,
		RegisteredClaims: jwt.RegisteredClaims{
			ExpiresAt: jwt.NewNumericDate(time.Now().Add(7 * 24 * time.Hour)), // 7天有效
			IssuedAt:  jwt.NewNumericDate(time.Now()),
		},
	}
	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	return token.SignedString(jwtSecret)
}

// ParseToken 校验并解析 token
func ParseToken(tokenString string) (*Claims, error) {
	token, err := jwt.ParseWithClaims(tokenString, &Claims{}, func(token *jwt.Token) (interface{}, error) {
		return jwtSecret, nil
	})
	if err != nil {
		return nil, err
	}
	if claims, ok := token.Claims.(*Claims); ok && token.Valid {
		return claims, nil
	}
	return nil, errors.New("invalid token")
}
