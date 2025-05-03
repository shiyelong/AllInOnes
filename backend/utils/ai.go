package utils

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"strings"
	"time"
)

// AI聊天请求
type AIChatRequest struct {
	Model       string      `json:"model"`
	Messages    []AIMessage `json:"messages"`
	Temperature float64     `json:"temperature"`
	MaxTokens   int         `json:"max_tokens"`
	Stream      bool        `json:"stream"`
}

// AI消息
type AIMessage struct {
	Role    string `json:"role"`
	Content string `json:"content"`
}

// AI聊天响应
type AIChatResponse struct {
	ID      string     `json:"id"`
	Object  string     `json:"object"`
	Created int64      `json:"created"`
	Choices []AIChoice `json:"choices"`
	Usage   AIUsage    `json:"usage"`
}

// AI选择
type AIChoice struct {
	Index        int       `json:"index"`
	Message      AIMessage `json:"message"`
	FinishReason string    `json:"finish_reason"`
}

// AI使用情况
type AIUsage struct {
	PromptTokens     int `json:"prompt_tokens"`
	CompletionTokens int `json:"completion_tokens"`
	TotalTokens      int `json:"total_tokens"`
}

// 使用Hugging Face API进行聊天
func ChatWithAI(messages []AIMessage, model string, temperature float64, maxTokens int) (string, error) {
	// Hugging Face API密钥 - 需要在Hugging Face注册并获取
	huggingFaceToken := "hf_FLFBZXYZONWXXXXXXXXXXXXXXXXXXXXXXXx" // 替换为您的真实API密钥

	// 如果未指定模型，使用默认模型
	if model == "" {
		model = "facebook/blenderbot-400M-distill" // 一个开放的对话模型
	}

	// 构建对话历史
	var conversation string
	for _, msg := range messages {
		if msg.Role == "user" {
			conversation += "User: " + msg.Content + "\n"
		} else if msg.Role == "assistant" {
			conversation += "Assistant: " + msg.Content + "\n"
		} else if msg.Role == "system" {
			// 系统消息作为指令
			conversation = "Instructions: " + msg.Content + "\n" + conversation
		}
	}

	// 添加最后的提示
	conversation += "Assistant: "

	// 构建请求数据
	requestData := map[string]interface{}{
		"inputs": conversation,
		"parameters": map[string]interface{}{
			"temperature":      temperature,
			"max_length":       maxTokens,
			"return_full_text": false,
		},
	}

	// 转换为JSON
	jsonData, err := json.Marshal(requestData)
	if err != nil {
		return "", err
	}

	// 创建HTTP请求
	req, err := http.NewRequest("POST", "https://api-inference.huggingface.co/models/"+model, bytes.NewBuffer(jsonData))
	if err != nil {
		return "", err
	}

	// 设置请求头
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+huggingFaceToken)

	// 发送请求
	client := &http.Client{
		Timeout: 30 * time.Second, // 设置超时时间
	}
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

	// 检查响应状态码
	if resp.StatusCode != http.StatusOK {
		return "", fmt.Errorf("API请求失败: %s", string(body))
	}

	// 解析响应
	var response []map[string]interface{}
	err = json.Unmarshal(body, &response)
	if err != nil {
		// 尝试解析单个响应
		var singleResponse map[string]interface{}
		err = json.Unmarshal(body, &singleResponse)
		if err != nil {
			return "", fmt.Errorf("解析响应失败: %s", string(body))
		}

		// 检查是否有生成的文本
		if generatedText, ok := singleResponse["generated_text"].(string); ok {
			return generatedText, nil
		}

		return "", fmt.Errorf("无法从响应中提取文本: %s", string(body))
	}

	// 检查是否有响应
	if len(response) == 0 {
		return "", fmt.Errorf("AI没有返回响应")
	}

	// 获取生成的文本
	generatedText, ok := response[0]["generated_text"].(string)
	if !ok {
		return "", fmt.Errorf("无法从响应中提取文本")
	}

	return generatedText, nil
}

// 使用备用API：DialoGPT模型进行聊天
func ChatWithHuggingFace(messages []AIMessage) (string, error) {
	// Hugging Face API密钥 - 需要在Hugging Face注册并获取
	huggingFaceToken := "hf_FLFBZXYZONWXXXXXXXXXXXXXXXXXXXXXXXx" // 替换为您的真实API密钥

	// 使用不同的模型作为备用
	model := "microsoft/DialoGPT-medium" // 一个开放的对话模型

	// 构建对话历史
	var conversation string
	for _, msg := range messages {
		if msg.Role == "user" {
			conversation += "Human: " + msg.Content + "\n"
		} else if msg.Role == "assistant" {
			conversation += "AI: " + msg.Content + "\n"
		} else if msg.Role == "system" {
			// 系统消息作为指令
			conversation = "Context: " + msg.Content + "\n" + conversation
		}
	}

	// 添加最后的提示
	conversation += "AI: "

	// 构建请求数据
	requestData := map[string]interface{}{
		"inputs": conversation,
		"parameters": map[string]interface{}{
			"temperature":      0.7,
			"max_length":       1000,
			"return_full_text": false,
		},
	}

	// 转换为JSON
	jsonData, err := json.Marshal(requestData)
	if err != nil {
		return "", err
	}

	// 创建HTTP请求
	req, err := http.NewRequest("POST", "https://api-inference.huggingface.co/models/"+model, bytes.NewBuffer(jsonData))
	if err != nil {
		return "", err
	}

	// 设置请求头
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+huggingFaceToken)

	// 发送请求
	client := &http.Client{
		Timeout: 30 * time.Second, // 设置超时时间
	}
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

	// 检查响应状态码
	if resp.StatusCode != http.StatusOK {
		// 如果模型正在加载，返回一个友好的消息
		if strings.Contains(string(body), "loading") {
			return "我正在思考中，请稍等片刻再试...", nil
		}
		return "", fmt.Errorf("API请求失败: %s", string(body))
	}

	// 解析响应
	var response []map[string]interface{}
	err = json.Unmarshal(body, &response)
	if err != nil {
		// 尝试解析单个响应
		var singleResponse map[string]interface{}
		err = json.Unmarshal(body, &singleResponse)
		if err != nil {
			return "", fmt.Errorf("解析响应失败: %s", string(body))
		}

		// 检查是否有生成的文本
		if generatedText, ok := singleResponse["generated_text"].(string); ok {
			// 提取AI的回复
			parts := strings.Split(generatedText, "AI: ")
			if len(parts) > 1 {
				return parts[len(parts)-1], nil
			}
			return generatedText, nil
		}

		return "", fmt.Errorf("无法从响应中提取文本: %s", string(body))
	}

	// 检查是否有响应
	if len(response) == 0 {
		return "", fmt.Errorf("AI没有返回响应")
	}

	// 获取生成的文本
	generatedText, ok := response[0]["generated_text"].(string)
	if !ok {
		return "", fmt.Errorf("无法从响应中提取文本")
	}

	// 提取AI的回复
	parts := strings.Split(generatedText, "AI: ")
	if len(parts) > 1 {
		return parts[len(parts)-1], nil
	}

	return generatedText, nil
}

// 个人AI助手
func PersonalAIAssistant(userID uint, message string, history []AIMessage) (string, error) {
	// 构建系统提示
	systemPrompt := "你是一个友好、乐于助人的个人助手。你可以帮助用户回答问题、提供建议、进行日常对话等。"

	// 构建消息列表
	messages := []AIMessage{
		{Role: "system", Content: systemPrompt},
	}

	// 添加历史消息
	messages = append(messages, history...)

	// 添加用户当前消息
	messages = append(messages, AIMessage{Role: "user", Content: message})

	// 调用AI聊天
	response, err := ChatWithAI(messages, "gpt-3.5-turbo", 0.7, 2000)
	if err != nil {
		// 尝试备用API
		response, err = ChatWithHuggingFace(messages)
		if err != nil {
			return "", err
		}
	}

	return response, nil
}

// 群组AI管理
func GroupAIManager(groupID uint, userID uint, message string, history []AIMessage) (string, error) {
	// 构建系统提示
	systemPrompt := "你是一个群组管理助手。你可以帮助用户管理群组、回答群组相关问题、提供群组活动建议等。"

	// 构建消息列表
	messages := []AIMessage{
		{Role: "system", Content: systemPrompt},
	}

	// 添加历史消息
	messages = append(messages, history...)

	// 添加用户当前消息
	messages = append(messages, AIMessage{Role: "user", Content: message})

	// 调用AI聊天
	response, err := ChatWithAI(messages, "gpt-3.5-turbo", 0.7, 2000)
	if err != nil {
		// 尝试备用API
		response, err = ChatWithHuggingFace(messages)
		if err != nil {
			return "", err
		}
	}

	return response, nil
}

// AI游戏陪玩
func GameAICompanion(gameID uint, userID uint, message string, history []AIMessage) (string, error) {
	// 构建系统提示
	systemPrompt := "你是一个游戏陪玩助手。你可以陪伴用户玩游戏、提供游戏建议、讨论游戏策略等。"

	// 构建消息列表
	messages := []AIMessage{
		{Role: "system", Content: systemPrompt},
	}

	// 添加历史消息
	messages = append(messages, history...)

	// 添加用户当前消息
	messages = append(messages, AIMessage{Role: "user", Content: message})

	// 调用AI聊天
	response, err := ChatWithAI(messages, "gpt-3.5-turbo", 0.8, 2000)
	if err != nil {
		// 尝试备用API
		response, err = ChatWithHuggingFace(messages)
		if err != nil {
			return "", err
		}
	}

	return response, nil
}
