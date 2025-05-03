package utils

import (
	"bytes"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
)

// 使用Wit.ai API进行语音转文字 (Facebook提供的免费语音识别API)
// https://wit.ai/
func TranscribeSpeech(audioFilePath string) (string, error) {
	// Wit.ai API密钥 - 需要在Wit.ai注册并创建应用获取
	witAiToken := "YVPZQCNFZ7WFMLYEQCFCBGAB6QFIQTBZ" // 这是一个示例令牌，需要替换为真实的

	// 读取音频文件
	audioData, err := os.ReadFile(audioFilePath)
	if err != nil {
		return "", err
	}

	// 创建HTTP请求
	req, err := http.NewRequest("POST", "https://api.wit.ai/speech", bytes.NewReader(audioData))
	if err != nil {
		return "", err
	}

	// 设置请求头
	req.Header.Set("Authorization", "Bearer "+witAiToken)
	req.Header.Set("Content-Type", "audio/wav") // 根据实际音频格式调整

	// 发送请求
	client := &http.Client{}
	resp, err := client.Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()

	// 读取响应
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return "", err
	}

	// 解析响应
	var result map[string]interface{}
	err = json.Unmarshal(body, &result)
	if err != nil {
		return "", err
	}

	// 提取文本
	text, ok := result["_text"].(string)
	if !ok {
		// 尝试新版API格式
		if entities, ok := result["entities"].(map[string]interface{}); ok {
			if messageBody, ok := entities["message_body"].([]interface{}); ok && len(messageBody) > 0 {
				if firstMessage, ok := messageBody[0].(map[string]interface{}); ok {
					if value, ok := firstMessage["value"].(string); ok {
						return value, nil
					}
				}
			}
		}

		// 如果仍然无法提取文本，返回错误
		return "", fmt.Errorf("无法从响应中提取文本: %s", string(body))
	}

	return text, nil
}

// 备用方案：使用Wit.ai API进行语音转文字
// https://wit.ai/ - Facebook提供的免费语音识别API
func TranscribeSpeechWithWitAI(audioFilePath string, language string) (string, error) {
	// 读取音频文件
	audioData, err := os.ReadFile(audioFilePath)
	if err != nil {
		return "", err
	}

	// 创建HTTP请求
	req, err := http.NewRequest("POST", "https://api.wit.ai/speech", bytes.NewReader(audioData))
	if err != nil {
		return "", err
	}

	// 设置请求头
	req.Header.Set("Content-Type", "audio/wav")                 // 根据实际音频格式调整
	req.Header.Set("Authorization", "Bearer YOUR_WIT_AI_TOKEN") // 替换为你的Wit.ai访问令牌

	// 设置语言（如果支持）
	if language != "" {
		req.Header.Set("Accept-Language", language)
	}

	// 发送请求
	client := &http.Client{}
	resp, err := client.Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()

	// 解析响应
	var result map[string]interface{}
	err = json.NewDecoder(resp.Body).Decode(&result)
	if err != nil {
		return "", err
	}

	// 提取文本
	text, ok := result["_text"].(string)
	if !ok {
		return "", fmt.Errorf("invalid response format")
	}

	return text, nil
}

// 使用base64编码的音频数据进行语音识别
func TranscribeSpeechFromBase64(base64Audio string, language string) (string, error) {
	// 解码base64音频数据
	audioData, err := base64.StdEncoding.DecodeString(base64Audio)
	if err != nil {
		return "", err
	}

	// 创建临时文件
	tempFile, err := os.CreateTemp("", "audio-*.wav")
	if err != nil {
		return "", err
	}
	defer os.Remove(tempFile.Name())
	defer tempFile.Close()

	// 写入音频数据
	_, err = tempFile.Write(audioData)
	if err != nil {
		return "", err
	}

	// 使用临时文件进行语音识别
	if language == "" {
		return TranscribeSpeech(tempFile.Name())
	} else {
		return TranscribeSpeechWithWitAI(tempFile.Name(), language)
	}
}
