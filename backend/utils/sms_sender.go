package utils

import (
	"crypto/md5"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io/ioutil"
	"net/http"
	"net/url"
	"strconv"
	"strings"
	"time"
)

// 短信配置
type SMSConfig struct {
	AppID     string
	AppKey    string
	TemplateID string
	Sign      string
}

// 全局短信配置
var smsConfig = SMSConfig{
	AppID:     "your_app_id",     // 替换为您的短信服务AppID
	AppKey:    "your_app_key",    // 替换为您的短信服务AppKey
	TemplateID: "your_template_id", // 替换为您的短信模板ID
	Sign:      "your_sign",       // 替换为您的短信签名
}

// 设置短信配置
func SetSMSConfig(config SMSConfig) {
	smsConfig = config
}

// 发送短信验证码
func SendSMSVerificationCode(phone, code string) error {
	// 这里使用腾讯云短信服务的示例
	// 实际使用时请替换为您使用的短信服务商的API
	
	// 构建请求参数
	timestamp := strconv.FormatInt(time.Now().Unix(), 10)
	params := map[string]string{
		"phone_number_set": fmt.Sprintf("[%s]", phone),
		"template_id":      smsConfig.TemplateID,
		"template_param_set": fmt.Sprintf("[\"%s\"]", code),
		"sign_name":        smsConfig.Sign,
		"sms_sdk_app_id":   smsConfig.AppID,
	}
	
	// 构建签名
	paramsStr, _ := json.Marshal(params)
	signStr := fmt.Sprintf("POST\n/v2/sendSms\n%s\n%s\n", timestamp, string(paramsStr))
	h := md5.New()
	h.Write([]byte(signStr + smsConfig.AppKey))
	sign := hex.EncodeToString(h.Sum(nil))
	
	// 构建请求URL
	apiURL := "https://sms.tencentcloudapi.com/v2/sendSms"
	data := url.Values{}
	for k, v := range params {
		data.Set(k, v)
	}
	data.Set("timestamp", timestamp)
	data.Set("sign", sign)
	
	// 发送请求
	req, err := http.NewRequest("POST", apiURL, strings.NewReader(data.Encode()))
	if err != nil {
		return err
	}
	req.Header.Add("Content-Type", "application/x-www-form-urlencoded")
	
	client := &http.Client{}
	resp, err := client.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	
	// 解析响应
	body, err := ioutil.ReadAll(resp.Body)
	if err != nil {
		return err
	}
	
	// 检查响应是否成功
	var result map[string]interface{}
	if err := json.Unmarshal(body, &result); err != nil {
		return err
	}
	
	if status, ok := result["status"].(float64); !ok || status != 0 {
		return fmt.Errorf("发送短信失败: %s", string(body))
	}
	
	return nil
}

// 验证手机号格式
func ValidatePhone(phone string) bool {
	// 简单的中国大陆手机号格式验证
	return len(phone) == 11 && strings.HasPrefix(phone, "1")
}
