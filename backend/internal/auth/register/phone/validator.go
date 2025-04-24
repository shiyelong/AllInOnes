package phone

import "regexp"

func Validate(phone, code, password, generatedCode string) (ok bool, errMsg string) {
	if phone == "" {
		return false, "请输入手机号"
	}
	matched, _ := regexp.MatchString(`^1[3-9]\d{9}$`, phone)
	if !matched {
		return false, "手机号格式不正确"
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
