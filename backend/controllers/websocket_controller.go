package controllers

import (
	"allinone_backend/models"
	"allinone_backend/utils"
	"encoding/json"
	"log"
	"net/http"
	"strconv"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/gorilla/websocket"
)

// WebSocket升级器
var upgrader = websocket.Upgrader{
	ReadBufferSize:  1024,
	WriteBufferSize: 1024,
	// 允许所有来源的跨域请求
	CheckOrigin: func(r *http.Request) bool {
		return true
	},
}

// WebSocket连接处理
func HandleWebSocket(c *gin.Context) {
	// 获取当前用户ID
	userIDStr, exists := c.GetQuery("user_id")
	if !exists {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "msg": "缺少user_id参数"})
		return
	}

	// 获取token
	token, exists := c.GetQuery("token")
	if !exists {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "msg": "缺少token参数"})
		return
	}

	// 验证token
	claims, err := utils.ParseToken(token)
	if err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"success": false, "msg": "无效的token"})
		return
	}

	// 验证用户ID
	userID, err := strconv.ParseUint(userIDStr, 10, 32)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "msg": "无效的user_id"})
		return
	}

	// 检查token中的用户ID是否与请求中的用户ID一致
	if claims.UserID != uint(userID) {
		c.JSON(http.StatusUnauthorized, gin.H{"success": false, "msg": "用户ID与token不匹配"})
		return
	}

	// 升级HTTP连接为WebSocket连接
	conn, err := upgrader.Upgrade(c.Writer, c.Request, nil)
	if err != nil {
		log.Println("升级WebSocket连接失败:", err)
		return
	}

	// 注册WebSocket连接
	utils.WebRTCServer.RegisterClient(uint(userID), conn)

	// 发送欢迎消息
	welcomeMsg := map[string]interface{}{
		"type":    "welcome",
		"message": "已连接到WebRTC信令服务器",
		"user_id": userID,
	}
	conn.WriteJSON(welcomeMsg)

	// 处理WebSocket连接
	go handleConnection(conn, uint(userID))
}

// 处理WebSocket连接
func handleConnection(conn *websocket.Conn, userID uint) {
	defer func() {
		// 注销WebSocket连接
		utils.WebRTCServer.UnregisterClient(userID)
		conn.Close()
	}()

	// 设置读取超时
	conn.SetReadDeadline(time.Now().Add(60 * time.Second))
	conn.SetPongHandler(func(string) error {
		conn.SetReadDeadline(time.Now().Add(60 * time.Second))
		return nil
	})

	// 启动心跳检测
	go func() {
		ticker := time.NewTicker(30 * time.Second)
		defer ticker.Stop()
		for {
			select {
			case <-ticker.C:
				if err := conn.WriteMessage(websocket.PingMessage, nil); err != nil {
					return
				}
			}
		}
	}()

	// 读取消息循环
	for {
		// 读取消息
		_, message, err := conn.ReadMessage()
		if err != nil {
			if websocket.IsUnexpectedCloseError(err, websocket.CloseGoingAway, websocket.CloseAbnormalClosure) {
				log.Printf("WebSocket错误: %v", err)
			}
			break
		}

		// 解析消息
		var data map[string]interface{}
		if err := json.Unmarshal(message, &data); err != nil {
			log.Printf("解析WebSocket消息失败: %v", err)
			continue
		}

		// 更新用户活跃时间
		utils.WebRTCServer.UpdateUserActivity(userID)

		// 处理不同类型的消息
		messageType, ok := data["type"].(string)
		if !ok {
			log.Println("WebSocket消息缺少type字段")
			continue
		}

		switch messageType {
		case "webrtc_signal":
			// 处理WebRTC信令
			handleWebRTCSignal(data, userID)
		case "call_invitation":
			// 处理通话邀请
			handleCallInvitation(data, userID)
		case "call_response":
			// 处理通话响应
			handleCallResponse(data, userID)
		case "call_ended":
			// 处理通话结束
			handleCallEnded(data, userID)
		case "ping":
			// 处理ping消息
			conn.WriteJSON(map[string]interface{}{
				"type": "pong",
				"time": time.Now().Unix(),
			})
		default:
			log.Printf("未知的WebSocket消息类型: %s", messageType)
		}
	}
}

// 处理WebRTC信令
func handleWebRTCSignal(data map[string]interface{}, fromUserID uint) {
	// 获取接收者ID
	toUserIDFloat, ok := data["to"].(float64)
	if !ok {
		log.Println("WebRTC信令缺少to字段")
		return
	}
	toUserID := uint(toUserIDFloat)

	// 获取信令类型
	signalType, ok := data["signal_type"].(string)
	if !ok {
		log.Println("WebRTC信令缺少signal_type字段")
		return
	}

	// 获取信令数据
	signal, ok := data["signal"].(string)
	if !ok {
		log.Println("WebRTC信令缺少signal字段")
		return
	}

	// 获取通话类型
	callType, ok := data["call_type"].(string)
	if !ok {
		callType = "video" // 默认为视频通话
	}

	// 发送信令
	err := utils.WebRTCServer.SendSignal(fromUserID, toUserID, signalType, signal, callType)
	if err != nil {
		log.Printf("发送WebRTC信令失败: %v", err)
	}
}

// 处理通话邀请
func handleCallInvitation(data map[string]interface{}, fromUserID uint) {
	// 获取接收者ID
	toUserIDFloat, ok := data["to"].(float64)
	if !ok {
		log.Println("通话邀请缺少to字段")
		return
	}
	toUserID := uint(toUserIDFloat)

	// 获取通话类型
	callType, ok := data["call_type"].(string)
	if !ok {
		callType = "video" // 默认为视频通话
	}

	// 创建通话记录
	var callID uint
	if callType == "video" {
		// 创建视频通话记录
		videoCall := models.VideoCallRecord{
			CallerID:   fromUserID,
			ReceiverID: toUserID,
			StartTime:  time.Now().Unix(),
			Status:     0, // 未接通
		}
		if err := utils.DB.Create(&videoCall).Error; err != nil {
			log.Printf("创建视频通话记录失败: %v", err)
			return
		}
		callID = videoCall.ID
	} else {
		// 创建语音通话记录
		voiceCall := models.VoiceCallRecord{
			CallerID:   fromUserID,
			ReceiverID: toUserID,
			StartTime:  time.Now().Unix(),
			Status:     0, // 未接通
		}
		if err := utils.DB.Create(&voiceCall).Error; err != nil {
			log.Printf("创建语音通话记录失败: %v", err)
			return
		}
		callID = voiceCall.ID
	}

	// 发送通话邀请
	err := utils.WebRTCServer.SendCallInvitation(fromUserID, toUserID, callType, callID)
	if err != nil {
		log.Printf("发送通话邀请失败: %v", err)
	}
}

// 处理通话响应
func handleCallResponse(data map[string]interface{}, fromUserID uint) {
	// 获取接收者ID
	toUserIDFloat, ok := data["to"].(float64)
	if !ok {
		log.Println("通话响应缺少to字段")
		return
	}
	toUserID := uint(toUserIDFloat)

	// 获取通话ID
	callIDFloat, ok := data["call_id"].(float64)
	if !ok {
		log.Println("通话响应缺少call_id字段")
		return
	}
	callID := uint(callIDFloat)

	// 获取通话类型
	callType, ok := data["call_type"].(string)
	if !ok {
		callType = "video" // 默认为视频通话
	}

	// 获取响应类型
	response, ok := data["response"].(string)
	if !ok {
		log.Println("通话响应缺少response字段")
		return
	}

	// 更新通话记录
	if callType == "video" {
		// 更新视频通话记录
		var videoCall models.VideoCallRecord
		if err := utils.DB.First(&videoCall, callID).Error; err != nil {
			log.Printf("获取视频通话记录失败: %v", err)
			return
		}

		if response == "accepted" {
			videoCall.Status = 1 // 已接通
		} else {
			videoCall.Status = 2 // 已拒绝
			videoCall.EndTime = time.Now().Unix()
		}

		if err := utils.DB.Save(&videoCall).Error; err != nil {
			log.Printf("更新视频通话记录失败: %v", err)
			return
		}
	} else {
		// 更新语音通话记录
		var voiceCall models.VoiceCallRecord
		if err := utils.DB.First(&voiceCall, callID).Error; err != nil {
			log.Printf("获取语音通话记录失败: %v", err)
			return
		}

		if response == "accepted" {
			voiceCall.Status = 1 // 已接通
		} else {
			voiceCall.Status = 2 // 已拒绝
			voiceCall.EndTime = time.Now().Unix()
		}

		if err := utils.DB.Save(&voiceCall).Error; err != nil {
			log.Printf("更新语音通话记录失败: %v", err)
			return
		}
	}

	// 构建响应消息
	message := map[string]interface{}{
		"type":      "call_response",
		"from":      fromUserID,
		"call_type": callType,
		"call_id":   callID,
		"response":  response,
		"timestamp": time.Now().Unix(),
	}

	// 转换为JSON
	jsonMessage, err := json.Marshal(message)
	if err != nil {
		log.Printf("转换通话响应消息失败: %v", err)
		return
	}

	// 获取接收者连接
	utils.WebRTCServer.ClientsMutex.RLock()
	toConn, exists := utils.WebRTCServer.Clients[toUserID]
	utils.WebRTCServer.ClientsMutex.RUnlock()

	if !exists {
		log.Printf("接收者不在线")
		return
	}

	// 发送响应
	err = toConn.WriteMessage(websocket.TextMessage, jsonMessage)
	if err != nil {
		log.Printf("发送通话响应失败: %v", err)
	}
}

// 处理通话结束
func handleCallEnded(data map[string]interface{}, fromUserID uint) {
	// 获取接收者ID
	toUserIDFloat, ok := data["to"].(float64)
	if !ok {
		log.Println("通话结束通知缺少to字段")
		return
	}
	toUserID := uint(toUserIDFloat)

	// 获取通话ID
	callIDFloat, ok := data["call_id"].(float64)
	if !ok {
		log.Println("通话结束通知缺少call_id字段")
		return
	}
	callID := uint(callIDFloat)

	// 获取通话类型
	callType, ok := data["call_type"].(string)
	if !ok {
		callType = "video" // 默认为视频通话
	}

	// 获取结束原因
	reason, ok := data["reason"].(string)
	if !ok {
		reason = "normal" // 默认为正常结束
	}

	// 更新通话记录
	now := time.Now().Unix()
	if callType == "video" {
		// 更新视频通话记录
		var videoCall models.VideoCallRecord
		if err := utils.DB.First(&videoCall, callID).Error; err != nil {
			log.Printf("获取视频通话记录失败: %v", err)
			return
		}

		videoCall.EndTime = now
		if videoCall.Status == 1 { // 如果已接通
			videoCall.Duration = int(now - videoCall.StartTime)
		}

		if err := utils.DB.Save(&videoCall).Error; err != nil {
			log.Printf("更新视频通话记录失败: %v", err)
			return
		}
	} else {
		// 更新语音通话记录
		var voiceCall models.VoiceCallRecord
		if err := utils.DB.First(&voiceCall, callID).Error; err != nil {
			log.Printf("获取语音通话记录失败: %v", err)
			return
		}

		voiceCall.EndTime = now
		if voiceCall.Status == 1 { // 如果已接通
			voiceCall.Duration = int(now - voiceCall.StartTime)
		}

		if err := utils.DB.Save(&voiceCall).Error; err != nil {
			log.Printf("更新语音通话记录失败: %v", err)
			return
		}
	}

	// 发送通话结束通知
	err := utils.WebRTCServer.SendCallEnded(fromUserID, toUserID, callType, callID, reason)
	if err != nil {
		log.Printf("发送通话结束通知失败: %v", err)
	}
}
