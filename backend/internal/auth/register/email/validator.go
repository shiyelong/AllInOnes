package email

import "regexp"

func Validate(email, code, password, generatedCode string) (ok bool, errMsg string) {
	if email == "" {
		return false, "请输入邮箱"
	}
	matched, _ := regexp.MatchString(`^[\w-.]+@[\w-]+\.[a-zA-Z]{2,4}$`, email)
	if !matched {
		return false, "邮箱格式不正确"
	}
	if code == "" {
		return false, "请输入验证码"
	}
	if code != generatedCode {
		return false, "验证码错误"
	}
	if len(password) < 6 {
		return false, "密码至少6位"
	}
	return true, ""
}
