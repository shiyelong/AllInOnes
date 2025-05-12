package utils

import "strings"

// 聊天消息辅助工具
// 包含敏感词过滤、消息格式化等功能

// 敏感词列表
var sensitiveWords = []string{
	"傻逼", "操你妈", "fuck", "shit", "bitch",
	"政府", "共产党", "习近平", "毛泽东", "法轮功",
	"台独", "港独", "藏独", "新疆独立", "民主",
}

// FilterSensitiveWords 过滤敏感词
// 将敏感词替换为****
func FilterSensitiveWords(content string) string {
	// 如果内容为空，直接返回
	if content == "" {
		return content
	}

	// 遍历敏感词列表，替换敏感词
	filteredContent := content
	for _, word := range sensitiveWords {
		// 替换为等长度的*
		replacement := ""
		for i := 0; i < len(word); i++ {
			replacement += "*"
		}

		// 替换敏感词
		filteredContent = strings.Replace(filteredContent, word, replacement, -1)
	}

	return filteredContent
}
