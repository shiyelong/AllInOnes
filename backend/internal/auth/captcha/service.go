package captcha

import (
	"github.com/mojocn/base64Captcha"
	"log"
	"sync"
)

var (
	store = base64Captcha.DefaultMemStore
	once  sync.Once
)

func GenerateCaptcha() (id, b64s string) {
	driver := base64Captcha.NewDriverDigit(40, 120, 5, 0.7, 80)
	c := base64Captcha.NewCaptcha(driver, store)
	id, b64s, _, _ = c.Generate()
	log.Printf("生成验证码 base64 长度: %d, 前50: %s", len(b64s), b64s[:50])
	return
}

func VerifyCaptcha(id, value string) bool {
	return store.Verify(id, value, true)
}
