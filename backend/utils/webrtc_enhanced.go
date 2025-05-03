package utils

import (
	"encoding/json"
	"fmt"
	"sync"
	"time"

	"github.com/gorilla/websocket"
)

// WebRTC信令消息类型
const (
	SignalTypeOffer     = "offer"
	SignalTypeAnswer    = "answer"
	SignalTypeCandidate = "candidate"
	SignalTypeHangup    = "hangup"
)

// 通话类型
const (
	CallTypeVoice = "voice"
	CallTypeVideo = "video"
)

// 通话状态
const (
	CallStatusPending   = 0 // 未接通
	CallStatusConnected = 1 // 已接通
	CallStatusRejected  = 2 // 已拒绝
	CallStatusMissed    = 3 // 未接听
)

// WebRTC信令服务器增强版
type EnhancedWebRTCServerImpl struct {
	// 客户端连接
	Clients      map[uint]*websocket.Conn
	ClientsMutex sync.RWMutex

	// 在线用户
	OnlineUsers      map[uint]int64 // 用户ID -> 最后活跃时间戳
	OnlineUsersMutex sync.RWMutex

	// 活跃通话
	ActiveCalls      map[uint]map[uint]uint // 主叫ID -> 被叫ID -> 通话ID
	ActiveCallsMutex sync.RWMutex

	// 信令处理器
	SignalHandlers map[string]func(fromUserID, toUserID uint, signal string, callType string) error
}

// 创建新的WebRTC信令服务器
func NewEnhancedWebRTCServer() *EnhancedWebRTCServerImpl {
	server := &EnhancedWebRTCServerImpl{
		Clients:        make(map[uint]*websocket.Conn),
		OnlineUsers:    make(map[uint]int64),
		ActiveCalls:    make(map[uint]map[uint]uint),
		SignalHandlers: make(map[string]func(fromUserID, toUserID uint, signal string, callType string) error),
	}

	// 注册信令处理器
	server.registerSignalHandlers()

	// 启动心跳检测
	go server.startHeartbeatChecker()

	return server
}

// 注册信令处理器
func (s *EnhancedWebRTCServerImpl) registerSignalHandlers() {
	// Offer信令处理
	s.SignalHandlers[SignalTypeOffer] = func(fromUserID, toUserID uint, signal string, callType string) error {
		// 检查是否已有活跃通话
		s.ActiveCallsMutex.Lock()
		if _, exists := s.ActiveCalls[fromUserID]; !exists {
			s.ActiveCalls[fromUserID] = make(map[uint]uint)
		}
		s.ActiveCallsMutex.Unlock()

		// 转发Offer信令
		return s.SendSignal(fromUserID, toUserID, SignalTypeOffer, signal, callType)
	}

	// Answer信令处理
	s.SignalHandlers[SignalTypeAnswer] = func(fromUserID, toUserID uint, signal string, callType string) error {
		// 检查是否有对应的通话
		s.ActiveCallsMutex.RLock()
		callMap, exists := s.ActiveCalls[toUserID]
		if !exists || callMap[fromUserID] == 0 {
			s.ActiveCallsMutex.RUnlock()
			return fmt.Errorf("没有找到对应的通话")
		}
		s.ActiveCallsMutex.RUnlock()

		// 转发Answer信令
		return s.SendSignal(fromUserID, toUserID, SignalTypeAnswer, signal, callType)
	}

	// Candidate信令处理
	s.SignalHandlers[SignalTypeCandidate] = func(fromUserID, toUserID uint, signal string, callType string) error {
		// 转发Candidate信令
		return s.SendSignal(fromUserID, toUserID, SignalTypeCandidate, signal, callType)
	}

	// Hangup信令处理
	s.SignalHandlers[SignalTypeHangup] = func(fromUserID, toUserID uint, signal string, callType string) error {
		// 清理活跃通话
		s.ActiveCallsMutex.Lock()
		if callMap, exists := s.ActiveCalls[fromUserID]; exists {
			delete(callMap, toUserID)
			if len(callMap) == 0 {
				delete(s.ActiveCalls, fromUserID)
			}
		}
		if callMap, exists := s.ActiveCalls[toUserID]; exists {
			delete(callMap, fromUserID)
			if len(callMap) == 0 {
				delete(s.ActiveCalls, toUserID)
			}
		}
		s.ActiveCallsMutex.Unlock()

		// 转发Hangup信令
		return s.SendSignal(fromUserID, toUserID, SignalTypeHangup, signal, callType)
	}
}

// 启动心跳检测
func (s *EnhancedWebRTCServerImpl) startHeartbeatChecker() {
	ticker := time.NewTicker(30 * time.Second)
	defer ticker.Stop()

	for range ticker.C {
		s.checkHeartbeats()
	}
}

// 检查心跳
func (s *EnhancedWebRTCServerImpl) checkHeartbeats() {
	now := time.Now().Unix()
	timeout := int64(60) // 60秒超时

	// 检查在线用户
	s.OnlineUsersMutex.Lock()
	for userID, lastActive := range s.OnlineUsers {
		if now-lastActive > timeout {
			// 用户超时，清理连接
			s.OnlineUsersMutex.Unlock()
			s.ClientsMutex.Lock()
			if conn, exists := s.Clients[userID]; exists {
				conn.Close()
				delete(s.Clients, userID)
				Logger.Infof("用户 %d 心跳超时，已断开连接", userID)
			}
			s.ClientsMutex.Unlock()
			s.OnlineUsersMutex.Lock()
			delete(s.OnlineUsers, userID)
		}
	}
	s.OnlineUsersMutex.Unlock()

	// 清理活跃通话（超过5分钟的通话）
	// 5分钟超时
	_ = int64(300)
	s.ActiveCallsMutex.Lock()
	for fromUserID, callMap := range s.ActiveCalls {
		for toUserID := range callMap {
			// 这里简化处理，实际应该记录通话开始时间
			// 如果需要更精确的控制，可以在ActiveCalls中存储更多信息
			delete(callMap, toUserID)
			Logger.Infof("清理超时通话: %d -> %d", fromUserID, toUserID)
		}
		if len(callMap) == 0 {
			delete(s.ActiveCalls, fromUserID)
		}
	}
	s.ActiveCallsMutex.Unlock()
}

// 注册客户端
func (s *EnhancedWebRTCServerImpl) RegisterClient(userID uint, conn *websocket.Conn) {
	s.ClientsMutex.Lock()
	defer s.ClientsMutex.Unlock()

	// 如果已存在连接，关闭旧连接
	if oldConn, exists := s.Clients[userID]; exists {
		oldConn.Close()
	}

	// 注册新连接
	s.Clients[userID] = conn

	// 更新在线用户
	s.OnlineUsersMutex.Lock()
	s.OnlineUsers[userID] = time.Now().Unix()
	s.OnlineUsersMutex.Unlock()

	Logger.Infof("用户 %d 已连接到WebRTC信令服务器", userID)
}

// 处理客户端消息
func (s *EnhancedWebRTCServerImpl) HandleClientMessage(userID uint, messageType int, message []byte) {
	// 更新用户活跃时间
	s.OnlineUsersMutex.Lock()
	s.OnlineUsers[userID] = time.Now().Unix()
	s.OnlineUsersMutex.Unlock()

	// 解析消息
	var data map[string]interface{}
	if err := json.Unmarshal(message, &data); err != nil {
		Logger.Errorf("解析WebRTC消息失败: %v", err)
		return
	}

	// 处理不同类型的消息
	msgType, ok := data["type"].(string)
	if !ok {
		Logger.Errorf("WebRTC消息缺少type字段")
		return
	}

	switch msgType {
	case "webrtc_signal":
		s.handleSignalMessage(userID, data)
	case "heartbeat":
		// 心跳消息，已在函数开始处更新了活跃时间
		s.sendHeartbeatResponse(userID)
	default:
		Logger.Errorf("未知的WebRTC消息类型: %s", msgType)
	}
}

// 处理信令消息
func (s *EnhancedWebRTCServerImpl) handleSignalMessage(userID uint, data map[string]interface{}) {
	// 获取必要字段
	toUserID, ok := data["to"].(float64)
	if !ok {
		Logger.Errorf("WebRTC信令消息缺少to字段")
		return
	}

	signalType, ok := data["signal_type"].(string)
	if !ok {
		Logger.Errorf("WebRTC信令消息缺少signal_type字段")
		return
	}

	signal, ok := data["signal"].(string)
	if !ok {
		Logger.Errorf("WebRTC信令消息缺少signal字段")
		return
	}

	callType, ok := data["call_type"].(string)
	if !ok {
		callType = "voice" // 默认为语音通话
	}

	// 调用对应的信令处理器
	if handler, exists := s.SignalHandlers[signalType]; exists {
		if err := handler(userID, uint(toUserID), signal, callType); err != nil {
			Logger.Errorf("处理WebRTC信令失败: %v", err)
		}
	} else {
		Logger.Errorf("未知的WebRTC信令类型: %s", signalType)
	}
}

// 发送心跳响应
func (s *EnhancedWebRTCServerImpl) sendHeartbeatResponse(userID uint) {
	s.ClientsMutex.RLock()
	defer s.ClientsMutex.RUnlock()

	conn, exists := s.Clients[userID]
	if !exists {
		return
	}

	message := map[string]interface{}{
		"type":      "heartbeat_response",
		"timestamp": time.Now().Unix(),
	}

	jsonMessage, err := json.Marshal(message)
	if err != nil {
		Logger.Errorf("序列化心跳响应失败: %v", err)
		return
	}

	if err := conn.WriteMessage(websocket.TextMessage, jsonMessage); err != nil {
		Logger.Errorf("发送心跳响应失败: %v", err)
	}
}

// 发送信令
func (s *EnhancedWebRTCServerImpl) SendSignal(fromUserID, toUserID uint, signalType, signal, callType string) error {
	s.ClientsMutex.RLock()
	defer s.ClientsMutex.RUnlock()

	// 检查接收者是否在线
	toConn, exists := s.Clients[toUserID]
	if !exists {
		return fmt.Errorf("接收者不在线")
	}

	// 构建信令消息
	message := map[string]interface{}{
		"type":        "webrtc_signal",
		"from":        fromUserID,
		"signal_type": signalType,
		"signal":      signal,
		"call_type":   callType,
		"timestamp":   time.Now().Unix(),
	}

	// 转换为JSON
	jsonMessage, err := json.Marshal(message)
	if err != nil {
		return err
	}

	// 发送信令
	err = toConn.WriteMessage(websocket.TextMessage, jsonMessage)
	if err != nil {
		return err
	}

	Logger.Infof("已从用户 %d 发送信令到用户 %d: 类型=%s, 通话类型=%s", fromUserID, toUserID, signalType, callType)
	return nil
}

// 发送通话邀请
func (s *EnhancedWebRTCServerImpl) SendCallInvitation(fromUserID, toUserID uint, callType string, callID uint) error {
	s.ClientsMutex.RLock()
	defer s.ClientsMutex.RUnlock()

	// 检查接收者是否在线
	toConn, exists := s.Clients[toUserID]
	if !exists {
		return fmt.Errorf("接收者不在线")
	}

	// 记录活跃通话
	s.ActiveCallsMutex.Lock()
	if _, exists := s.ActiveCalls[fromUserID]; !exists {
		s.ActiveCalls[fromUserID] = make(map[uint]uint)
	}
	s.ActiveCalls[fromUserID][toUserID] = callID
	s.ActiveCallsMutex.Unlock()

	// 构建邀请消息
	message := map[string]interface{}{
		"type":      "call_invitation",
		"from":      fromUserID,
		"call_type": callType,
		"call_id":   callID,
		"timestamp": time.Now().Unix(),
	}

	// 转换为JSON
	jsonMessage, err := json.Marshal(message)
	if err != nil {
		return err
	}

	// 发送邀请
	err = toConn.WriteMessage(websocket.TextMessage, jsonMessage)
	if err != nil {
		return err
	}

	Logger.Infof("已从用户 %d 发送%s通话邀请到用户 %d, 通话ID=%d", fromUserID, callType, toUserID, callID)
	return nil
}

// 发送通话状态更新
func (s *EnhancedWebRTCServerImpl) SendCallStatusUpdate(fromUserID, toUserID uint, callID uint, status int) error {
	s.ClientsMutex.RLock()
	defer s.ClientsMutex.RUnlock()

	// 检查接收者是否在线
	toConn, exists := s.Clients[toUserID]
	if !exists {
		return fmt.Errorf("接收者不在线")
	}

	// 构建状态更新消息
	message := map[string]interface{}{
		"type":      "call_status",
		"from":      fromUserID,
		"call_id":   callID,
		"status":    status,
		"timestamp": time.Now().Unix(),
	}

	// 转换为JSON
	jsonMessage, err := json.Marshal(message)
	if err != nil {
		return err
	}

	// 发送状态更新
	err = toConn.WriteMessage(websocket.TextMessage, jsonMessage)
	if err != nil {
		return err
	}

	Logger.Infof("已从用户 %d 发送通话状态更新到用户 %d: 通话ID=%d, 状态=%d", fromUserID, toUserID, callID, status)
	return nil
}

// 获取在线用户列表
func (s *EnhancedWebRTCServerImpl) GetOnlineUsers() []uint {
	s.OnlineUsersMutex.RLock()
	defer s.OnlineUsersMutex.RUnlock()

	users := make([]uint, 0, len(s.OnlineUsers))
	for userID := range s.OnlineUsers {
		users = append(users, userID)
	}
	return users
}

// 检查用户是否在线
func (s *EnhancedWebRTCServerImpl) IsUserOnline(userID uint) bool {
	s.OnlineUsersMutex.RLock()
	defer s.OnlineUsersMutex.RUnlock()

	_, exists := s.OnlineUsers[userID]
	return exists
}

// 关闭客户端连接
func (s *EnhancedWebRTCServerImpl) CloseClient(userID uint) {
	s.ClientsMutex.Lock()
	if conn, exists := s.Clients[userID]; exists {
		conn.Close()
		delete(s.Clients, userID)
	}
	s.ClientsMutex.Unlock()

	s.OnlineUsersMutex.Lock()
	delete(s.OnlineUsers, userID)
	s.OnlineUsersMutex.Unlock()

	// 清理活跃通话
	s.ActiveCallsMutex.Lock()
	delete(s.ActiveCalls, userID)
	for fromUserID, callMap := range s.ActiveCalls {
		delete(callMap, userID)
		if len(callMap) == 0 {
			delete(s.ActiveCalls, fromUserID)
		}
	}
	s.ActiveCallsMutex.Unlock()

	Logger.Infof("用户 %d 已断开连接", userID)
}

// 全局增强版WebRTC信令服务器实例
var EnhancedWebRTCServerInstance = NewEnhancedWebRTCServer()
