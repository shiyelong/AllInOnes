package utils

import (
	"bytes"
	"errors"
	"fmt"
	"os"
	"os/exec"
	"strings"
)

// SpeechToText 将语音文件转换为文本
// 支持多种方式：本地处理、调用第三方API等
func SpeechToText(audioFilePath string) (string, error) {
	// 首先尝试使用本地处理（如果有安装相关工具）
	text, err := localSpeechToText(audioFilePath)
	if err == nil {
		return text, nil
	}

	// 如果本地处理失败，尝试使用免费API
	text, err = freeSpeechToTextAPI(audioFilePath)
	if err == nil {
		return text, nil
	}

	// 如果都失败了，返回错误
	return "", errors.New("语音识别失败，请稍后再试")
}

// localSpeechToText 使用本地工具进行语音识别
// 这里使用ffmpeg和whisper.cpp作为示例
func localSpeechToText(audioFilePath string) (string, error) {
	// 检查是否安装了ffmpeg
	_, err := exec.LookPath("ffmpeg")
	if err != nil {
		return "", errors.New("未安装ffmpeg")
	}

	// 检查是否安装了whisper.cpp
	_, err = exec.LookPath("whisper")
	if err != nil {
		return "", errors.New("未安装whisper")
	}

	// 转换音频格式为wav（如果需要）
	wavFile := strings.TrimSuffix(audioFilePath, "."+getFileExtension(audioFilePath)) + ".wav"
	cmd := exec.Command("ffmpeg", "-i", audioFilePath, "-ar", "16000", "-ac", "1", "-c:a", "pcm_s16le", wavFile)
	err = cmd.Run()
	if err != nil {
		return "", fmt.Errorf("音频转换失败: %v", err)
	}
	defer os.Remove(wavFile) // 处理完后删除临时文件

	// 使用whisper进行语音识别
	cmd = exec.Command("whisper", "-m", "models/ggml-base.bin", "-f", wavFile, "-l", "zh")
	var out bytes.Buffer
	cmd.Stdout = &out
	err = cmd.Run()
	if err != nil {
		return "", fmt.Errorf("语音识别失败: %v", err)
	}

	// 解析输出
	text := strings.TrimSpace(out.String())
	return text, nil
}

// freeSpeechToTextAPI 使用免费API进行语音识别
func freeSpeechToTextAPI(audioFilePath string) (string, error) {
	// 检查文件是否存在
	_, err := os.Stat(audioFilePath)
	if err != nil {
		return "", fmt.Errorf("音频文件不存在: %v", err)
	}

	// 使用实际的API调用
	// 这里应该集成真实的语音识别API
	// 例如百度语音识别API、讯飞语音识别API等

	// 临时返回错误，提示需要配置API
	return "", errors.New("需要配置语音识别API")
}

// 实际应用中应该实现真实的语音识别API调用

// getFileExtension 获取文件扩展名
func getFileExtension(filePath string) string {
	parts := strings.Split(filePath, ".")
	if len(parts) > 1 {
		return parts[len(parts)-1]
	}
	return ""
}

// 以下是一些常用的语音识别API的实现示例

// baiduSpeechToText 使用百度语音识别API
func baiduSpeechToText(audioData []byte) (string, error) {
	// 这里应该是实际的百度API调用
	// 需要替换为你自己的API密钥和配置
	return "", errors.New("需要配置百度语音识别API")
}

// xunfeiSpeechToText 使用讯飞语音识别API
func xunfeiSpeechToText(audioData []byte) (string, error) {
	// 这里应该是实际的讯飞API调用
	// 需要替换为你自己的API密钥和配置
	return "", errors.New("需要配置讯飞语音识别API")
}

// googleSpeechToText 使用Google语音识别API
func googleSpeechToText(audioData []byte) (string, error) {
	// 这里应该是实际的Google API调用
	// 需要替换为你自己的API密钥和配置
	return "", errors.New("需要配置Google语音识别API")
}
