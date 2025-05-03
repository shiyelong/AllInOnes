package controllers

import (
	"net/http"
	"time"

	"allinone_backend/models"
	"allinone_backend/utils"

	"github.com/gin-gonic/gin"
)

// AI相关接口
func ListAiTools(c *gin.Context) {
	// 获取当前用户
	_, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "未授权"})
		return
	}

	// 返回可用的AI工具列表
	c.JSON(http.StatusOK, gin.H{
		"tools": []map[string]interface{}{
			{
				"id":          "personal_assistant",
				"name":        "个人AI助手",
				"description": "一个智能的个人助手，可以回答问题、提供建议、进行日常对话等。",
				"icon":        "assistant",
			},
			{
				"id":          "group_manager",
				"name":        "群组AI管理",
				"description": "帮助管理群组、回答群组相关问题、提供群组活动建议等。",
				"icon":        "group",
			},
			{
				"id":          "game_companion",
				"name":        "AI游戏陪玩",
				"description": "陪伴玩游戏、提供游戏建议、讨论游戏策略等。",
				"icon":        "game",
			},
			{
				"id":          "voice_recognition",
				"name":        "语音识别",
				"description": "将语音转换为文字。",
				"icon":        "mic",
			},
			{
				"id":          "translation",
				"name":        "文字翻译",
				"description": "将文字翻译成不同的语言。",
				"icon":        "translate",
			},
		},
	})
}

// 获取AI聊天历史
func GetAIChatHistory(c *gin.Context) {
	// 获取当前用户
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "未授权"})
		return
	}

	// 解析请求参数
	var req struct {
		Type    string `form:"type" binding:"required"` // personal, group, game
		GroupID uint   `form:"group_id"`
		GameID  uint   `form:"game_id"`
		Limit   int    `form:"limit"`
		Offset  int    `form:"offset"`
	}

	if err := c.ShouldBindQuery(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "参数错误"})
		return
	}

	// 设置默认值
	if req.Limit <= 0 {
		req.Limit = 20
	}
	if req.Offset < 0 {
		req.Offset = 0
	}

	// 查询聊天历史
	var messages []models.AIChatMessage
	query := utils.DB.Where("user_id = ? AND type = ?", userID, req.Type)

	// 根据类型添加额外条件
	if req.Type == "group" && req.GroupID > 0 {
		query = query.Where("group_id = ?", req.GroupID)
	} else if req.Type == "game" && req.GameID > 0 {
		query = query.Where("game_id = ?", req.GameID)
	}

	// 执行查询
	if err := query.Order("created_at DESC").Limit(req.Limit).Offset(req.Offset).Find(&messages).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "获取聊天历史失败"})
		return
	}

	// 返回结果
	c.JSON(http.StatusOK, gin.H{
		"messages": messages,
	})
}

// 个人AI助手聊天
func ChatWithPersonalAI(c *gin.Context) {
	// 获取当前用户
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "未授权"})
		return
	}

	// 解析请求参数
	var req struct {
		Message string `json:"message" binding:"required"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "参数错误"})
		return
	}

	// 获取用户AI设置
	var aiSettings models.AISettings
	if err := utils.DB.Where("user_id = ?", userID).First(&aiSettings).Error; err != nil {
		// 如果没有设置，使用默认设置
		aiSettings = models.AISettings{
			UserID:         userID.(uint),
			AIModel:        "gpt-3.5-turbo",
			Temperature:    0.7,
			MaxTokens:      2000,
			PersonalPrompt: "你是一个友好、乐于助人的个人助手。你可以帮助用户回答问题、提供建议、进行日常对话等。",
		}
	}

	// 获取聊天历史
	var history []models.AIChatMessage
	if err := utils.DB.Where("user_id = ? AND type = ?", userID, "personal").Order("created_at DESC").Limit(10).Find(&history).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "获取聊天历史失败"})
		return
	}

	// 转换历史消息格式
	var messages []utils.AIMessage
	for i := len(history) - 1; i >= 0; i-- {
		messages = append(messages, utils.AIMessage{Role: "user", Content: history[i].Content})
		messages = append(messages, utils.AIMessage{Role: "assistant", Content: history[i].Response})
	}

	// 添加系统提示
	messages = append([]utils.AIMessage{{Role: "system", Content: aiSettings.PersonalPrompt}}, messages...)

	// 添加用户当前消息
	messages = append(messages, utils.AIMessage{Role: "user", Content: req.Message})

	// 调用AI聊天
	response, err := utils.ChatWithAI(messages, aiSettings.AIModel, aiSettings.Temperature, aiSettings.MaxTokens)
	if err != nil {
		// 尝试备用API
		response, err = utils.ChatWithHuggingFace(messages)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "AI聊天失败"})
			return
		}
	}

	// 保存聊天记录
	chatMessage := models.AIChatMessage{
		UserID:    userID.(uint),
		Content:   req.Message,
		Response:  response,
		CreatedAt: time.Now().Unix(),
		Type:      "personal",
	}

	if err := utils.DB.Create(&chatMessage).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "保存聊天记录失败"})
		return
	}

	// 返回结果
	c.JSON(http.StatusOK, gin.H{
		"message":  chatMessage,
		"response": response,
	})
}

// 群组AI管理聊天
func ChatWithGroupAI(c *gin.Context) {
	// 获取当前用户
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "未授权"})
		return
	}

	// 解析请求参数
	var req struct {
		GroupID uint   `json:"group_id" binding:"required"`
		Message string `json:"message" binding:"required"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "参数错误"})
		return
	}

	// 检查用户是否在群组中
	var groupMember models.GroupMember
	if err := utils.DB.Where("group_id = ? AND user_id = ?", req.GroupID, userID).First(&groupMember).Error; err != nil {
		c.JSON(http.StatusForbidden, gin.H{"error": "您不是该群组成员"})
		return
	}

	// 获取用户AI设置
	var aiSettings models.AISettings
	if err := utils.DB.Where("user_id = ?", userID).First(&aiSettings).Error; err != nil {
		// 如果没有设置，使用默认设置
		aiSettings = models.AISettings{
			UserID:      userID.(uint),
			AIModel:     "gpt-3.5-turbo",
			Temperature: 0.7,
			MaxTokens:   2000,
			GroupPrompt: "你是一个群组管理助手。你可以帮助用户管理群组、回答群组相关问题、提供群组活动建议等。",
		}
	}

	// 获取聊天历史
	var history []models.AIChatMessage
	if err := utils.DB.Where("user_id = ? AND type = ? AND group_id = ?", userID, "group", req.GroupID).Order("created_at DESC").Limit(10).Find(&history).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "获取聊天历史失败"})
		return
	}

	// 转换历史消息格式
	var messages []utils.AIMessage
	for i := len(history) - 1; i >= 0; i-- {
		messages = append(messages, utils.AIMessage{Role: "user", Content: history[i].Content})
		messages = append(messages, utils.AIMessage{Role: "assistant", Content: history[i].Response})
	}

	// 添加系统提示
	messages = append([]utils.AIMessage{{Role: "system", Content: aiSettings.GroupPrompt}}, messages...)

	// 添加用户当前消息
	messages = append(messages, utils.AIMessage{Role: "user", Content: req.Message})

	// 调用AI聊天
	response, err := utils.ChatWithAI(messages, aiSettings.AIModel, aiSettings.Temperature, aiSettings.MaxTokens)
	if err != nil {
		// 尝试备用API
		response, err = utils.ChatWithHuggingFace(messages)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "AI聊天失败"})
			return
		}
	}

	// 保存聊天记录
	chatMessage := models.AIChatMessage{
		UserID:    userID.(uint),
		GroupID:   req.GroupID,
		Content:   req.Message,
		Response:  response,
		CreatedAt: time.Now().Unix(),
		Type:      "group",
	}

	if err := utils.DB.Create(&chatMessage).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "保存聊天记录失败"})
		return
	}

	// 返回结果
	c.JSON(http.StatusOK, gin.H{
		"message":  chatMessage,
		"response": response,
	})
}

// 游戏AI陪玩聊天
func ChatWithGameAI(c *gin.Context) {
	// 获取当前用户
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "未授权"})
		return
	}

	// 解析请求参数
	var req struct {
		GameID  uint   `json:"game_id" binding:"required"`
		Message string `json:"message" binding:"required"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "参数错误"})
		return
	}

	// 检查游戏是否存在
	var game models.Game
	if err := utils.DB.First(&game, req.GameID).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "游戏不存在"})
		return
	}

	// 获取用户AI设置
	var aiSettings models.AISettings
	if err := utils.DB.Where("user_id = ?", userID).First(&aiSettings).Error; err != nil {
		// 如果没有设置，使用默认设置
		aiSettings = models.AISettings{
			UserID:      userID.(uint),
			AIModel:     "gpt-3.5-turbo",
			Temperature: 0.8,
			MaxTokens:   2000,
			GamePrompt:  "你是一个游戏陪玩助手。你可以陪伴用户玩游戏、提供游戏建议、讨论游戏策略等。",
		}
	}

	// 获取聊天历史
	var history []models.AIChatMessage
	if err := utils.DB.Where("user_id = ? AND type = ? AND game_id = ?", userID, "game", req.GameID).Order("created_at DESC").Limit(10).Find(&history).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "获取聊天历史失败"})
		return
	}

	// 转换历史消息格式
	var messages []utils.AIMessage
	for i := len(history) - 1; i >= 0; i-- {
		messages = append(messages, utils.AIMessage{Role: "user", Content: history[i].Content})
		messages = append(messages, utils.AIMessage{Role: "assistant", Content: history[i].Response})
	}

	// 添加系统提示
	gamePrompt := aiSettings.GamePrompt + "\n游戏名称：" + game.Name + "\n游戏类型：" + game.Type + "\n游戏描述：" + game.Description
	messages = append([]utils.AIMessage{{Role: "system", Content: gamePrompt}}, messages...)

	// 添加用户当前消息
	messages = append(messages, utils.AIMessage{Role: "user", Content: req.Message})

	// 调用AI聊天
	response, err := utils.ChatWithAI(messages, aiSettings.AIModel, aiSettings.Temperature, aiSettings.MaxTokens)
	if err != nil {
		// 尝试备用API
		response, err = utils.ChatWithHuggingFace(messages)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "AI聊天失败"})
			return
		}
	}

	// 保存聊天记录
	chatMessage := models.AIChatMessage{
		UserID:    userID.(uint),
		Content:   req.Message,
		Response:  response,
		CreatedAt: time.Now().Unix(),
		Type:      "game",
	}

	if err := utils.DB.Create(&chatMessage).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "保存聊天记录失败"})
		return
	}

	// 返回结果
	c.JSON(http.StatusOK, gin.H{
		"message":  chatMessage,
		"response": response,
	})
}

// 更新AI设置
func UpdateAISettings(c *gin.Context) {
	// 获取当前用户
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "未授权"})
		return
	}

	// 解析请求参数
	var req models.AISettings
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "参数错误"})
		return
	}

	// 设置用户ID
	req.UserID = userID.(uint)
	req.UpdatedAt = time.Now().Unix()

	// 检查是否已有设置
	var existingSettings models.AISettings
	result := utils.DB.Where("user_id = ?", userID).First(&existingSettings)
	if result.Error == nil {
		// 更新现有设置
		if err := utils.DB.Model(&existingSettings).Updates(req).Error; err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "更新AI设置失败"})
			return
		}
	} else {
		// 创建新设置
		req.CreatedAt = time.Now().Unix()
		if err := utils.DB.Create(&req).Error; err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "创建AI设置失败"})
			return
		}
	}

	// 返回结果
	c.JSON(http.StatusOK, gin.H{
		"settings": req,
	})
}

// 获取AI设置
func GetAISettings(c *gin.Context) {
	// 获取当前用户
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "未授权"})
		return
	}

	// 查询AI设置
	var aiSettings models.AISettings
	if err := utils.DB.Where("user_id = ?", userID).First(&aiSettings).Error; err != nil {
		// 如果没有设置，返回默认设置
		aiSettings = models.AISettings{
			UserID:         userID.(uint),
			AIModel:        "gpt-3.5-turbo",
			Temperature:    0.7,
			MaxTokens:      2000,
			PersonalPrompt: "你是一个友好、乐于助人的个人助手。你可以帮助用户回答问题、提供建议、进行日常对话等。",
			GroupPrompt:    "你是一个群组管理助手。你可以帮助用户管理群组、回答群组相关问题、提供群组活动建议等。",
			GamePrompt:     "你是一个游戏陪玩助手。你可以陪伴用户玩游戏、提供游戏建议、讨论游戏策略等。",
			CreatedAt:      time.Now().Unix(),
			UpdatedAt:      time.Now().Unix(),
		}
	}

	// 返回结果
	c.JSON(http.StatusOK, gin.H{
		"settings": aiSettings,
	})
}
