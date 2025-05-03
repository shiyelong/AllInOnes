package utils

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strings"
	"time"
)

// 支持的语言列表
var SupportedLanguages = map[string]string{
	"zh-CN": "简体中文",
	"zh-TW": "繁体中文",
	"en":    "英语",
	"ja":    "日语",
	"ko":    "韩语",
	"fr":    "法语",
	"de":    "德语",
	"es":    "西班牙语",
	"it":    "意大利语",
	"ru":    "俄语",
	"pt":    "葡萄牙语",
	"ar":    "阿拉伯语",
	"hi":    "印地语",
}

// 使用LibreTranslate API进行翻译
// https://github.com/LibreTranslate/LibreTranslate
func TranslateText(text, sourceLang, targetLang string) (string, error) {
	// 如果源语言和目标语言相同，直接返回原文
	if sourceLang == targetLang {
		return text, nil
	}

	// 使用公共LibreTranslate实例
	apiURL := "https://translate.argosopentech.com/translate"

	// 构建请求数据
	data := map[string]interface{}{
		"q":      text,
		"source": sourceLang,
		"target": targetLang,
		"format": "text",
	}

	jsonData, err := json.Marshal(data)
	if err != nil {
		return "", err
	}

	// 发送请求
	req, err := http.NewRequest("POST", apiURL, bytes.NewBuffer(jsonData))
	if err != nil {
		return "", err
	}

	req.Header.Set("Content-Type", "application/json")

	client := &http.Client{
		Timeout: 10 * time.Second, // 设置超时时间
	}
	resp, err := client.Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()

	// 解析响应
	var result map[string]interface{}
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return "", err
	}

	err = json.Unmarshal(body, &result)
	if err != nil {
		return "", err
	}

	// 检查是否有错误
	if errMsg, ok := result["error"]; ok {
		return "", fmt.Errorf("translation error: %v", errMsg)
	}

	// 获取翻译结果
	translatedText, ok := result["translatedText"].(string)
	if !ok {
		return "", fmt.Errorf("invalid response format")
	}

	return translatedText, nil
}

// 备用翻译API：使用Google翻译
func TranslateTextWithGoogle(text, sourceLang, targetLang string) (string, error) {
	// 如果源语言和目标语言相同，直接返回原文
	if sourceLang == targetLang {
		return text, nil
	}

	// 构建Google翻译URL
	baseURL := "https://translate.googleapis.com/translate_a/single"

	// 设置查询参数
	params := url.Values{}
	params.Add("client", "gtx")
	params.Add("sl", sourceLang)
	params.Add("tl", targetLang)
	params.Add("dt", "t")
	params.Add("q", text)

	// 发送请求
	resp, err := http.Get(baseURL + "?" + params.Encode())
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()

	// 读取响应
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return "", err
	}

	// 解析JSON响应
	var result []interface{}
	err = json.Unmarshal(body, &result)
	if err != nil {
		return "", err
	}

	// 提取翻译结果
	if len(result) == 0 {
		return "", fmt.Errorf("empty translation result")
	}

	translations, ok := result[0].([]interface{})
	if !ok {
		return "", fmt.Errorf("invalid translation format")
	}

	var translatedText strings.Builder
	for _, t := range translations {
		translation, ok := t.([]interface{})
		if !ok || len(translation) == 0 {
			continue
		}

		text, ok := translation[0].(string)
		if !ok {
			continue
		}

		translatedText.WriteString(text)
	}

	return translatedText.String(), nil
}

// 检测语言
func DetectLanguage(text string) (string, error) {
	// 使用公共LibreTranslate实例检测语言
	apiURL := "https://translate.argosopentech.com/detect"

	// 构建请求数据
	data := map[string]interface{}{
		"q": text,
	}

	jsonData, err := json.Marshal(data)
	if err != nil {
		return "", err
	}

	// 发送请求
	req, err := http.NewRequest("POST", apiURL, bytes.NewBuffer(jsonData))
	if err != nil {
		return "", err
	}

	req.Header.Set("Content-Type", "application/json")

	client := &http.Client{
		Timeout: 10 * time.Second, // 设置超时时间
	}
	resp, err := client.Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()

	// 解析响应
	var result []map[string]interface{}
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return "", err
	}

	err = json.Unmarshal(body, &result)
	if err != nil {
		return "", err
	}

	// 检查是否有结果
	if len(result) == 0 {
		return "", fmt.Errorf("no language detection result")
	}

	// 获取检测到的语言
	language, ok := result[0]["language"].(string)
	if !ok {
		return "", fmt.Errorf("invalid response format")
	}

	return language, nil
}

// 备用语言检测：使用Google翻译
func DetectLanguageWithGoogle(text string) (string, error) {
	// 构建Google翻译URL
	baseURL := "https://translate.googleapis.com/translate_a/single"

	// 设置查询参数
	params := url.Values{}
	params.Add("client", "gtx")
	params.Add("sl", "auto")
	params.Add("tl", "en") // 目标语言可以是任何语言
	params.Add("dt", "t")
	params.Add("q", text)

	// 发送请求
	resp, err := http.Get(baseURL + "?" + params.Encode())
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()

	// 读取响应
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return "", err
	}

	// 解析JSON响应
	var result []interface{}
	err = json.Unmarshal(body, &result)
	if err != nil {
		return "", err
	}

	// 提取检测到的语言
	if len(result) < 3 {
		return "", fmt.Errorf("invalid response format")
	}

	detectedLang, ok := result[2].(string)
	if !ok {
		return "", fmt.Errorf("invalid language detection format")
	}

	return detectedLang, nil
}
