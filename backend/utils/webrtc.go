package utils

import (
	"encoding/json"
	"fmt"
	"log"
	"sync"
	"time"

	"github.com/gorilla/websocket"
)

// WebRTC信令服务器
type WebRTCSignalingServer struct {
	// 客户端连接映射表，键为用户ID，值为WebSocket连接
	Clients map[uint]*websocket.Conn
	// 互斥锁，用于保护clients映射表
	ClientsMutex sync.RWMutex
	// 在线用户映射表，键为用户ID，值为最后活跃时间
	OnlineUsers map[uint]int64
	// 互斥锁，用于保护onlineUsers映射表
	OnlineUsersMutex sync.RWMutex
}

// 创建新的WebRTC信令服务器
func NewWebRTCSignalingServer() *WebRTCSignalingServer {
	return &WebRTCSignalingServer{
		Clients:     make(map[uint]*websocket.Conn),
		OnlineUsers: make(map[uint]int64),
	}
}

// 全局WebRTC信令服务器实例
var WebRTCServer = NewWebRTCSignalingServer()

// 注册客户端
func (s *WebRTCSignalingServer) RegisterClient(userID uint, conn *websocket.Conn) {
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

	log.Printf("用户 %d 已连接到WebRTC信令服务器", userID)
}

// 注销客户端
func (s *WebRTCSignalingServer) UnregisterClient(userID uint) {
	s.ClientsMutex.Lock()
	defer s.ClientsMutex.Unlock()

	// 如果存在连接，关闭连接
	if conn, exists := s.Clients[userID]; exists {
		conn.Close()
		delete(s.Clients, userID)
	}

	// 更新在线用户
	s.OnlineUsersMutex.Lock()
	delete(s.OnlineUsers, userID)
	s.OnlineUsersMutex.Unlock()

	log.Printf("用户 %d 已断开与WebRTC信令服务器的连接", userID)
}

// 发送信令
func (s *WebRTCSignalingServer) SendSignal(fromUserID, toUserID uint, signalType, signal, callType string) error {
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

	log.Printf("已从用户 %d 发送信令到用户 %d", fromUserID, toUserID)
	return nil
}

// 发送通话邀请
func (s *WebRTCSignalingServer) SendCallInvitation(fromUserID, toUserID uint, callType string, callID uint) error {
	s.ClientsMutex.RLock()
	defer s.ClientsMutex.RUnlock()

	// 检查接收者是否在线
	toConn, exists := s.Clients[toUserID]
	if !exists {
		return fmt.Errorf("接收者不在线")
	}

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

	log.Printf("已从用户 %d 发送%s通话邀请到用户 %d", fromUserID, callType, toUserID)
	return nil
}

// 发送通话结束通知
func (s *WebRTCSignalingServer) SendCallEnded(fromUserID, toUserID uint, callType string, callID uint, reason string) error {
	s.ClientsMutex.RLock()
	defer s.ClientsMutex.RUnlock()

	// 检查接收者是否在线
	toConn, exists := s.Clients[toUserID]
	if !exists {
		return fmt.Errorf("接收者不在线")
	}

	// 构建结束消息
	message := map[string]interface{}{
		"type":      "call_ended",
		"from":      fromUserID,
		"call_type": callType,
		"call_id":   callID,
		"reason":    reason,
		"timestamp": time.Now().Unix(),
	}

	// 转换为JSON
	jsonMessage, err := json.Marshal(message)
	if err != nil {
		return err
	}

	// 发送通知
	err = toConn.WriteMessage(websocket.TextMessage, jsonMessage)
	if err != nil {
		return err
	}

	log.Printf("已从用户 %d 发送%s通话结束通知到用户 %d", fromUserID, callType, toUserID)
	return nil
}

// 检查用户是否在线
func (s *WebRTCSignalingServer) IsUserOnline(userID uint) bool {
	s.ClientsMutex.RLock()
	defer s.ClientsMutex.RUnlock()

	_, exists := s.Clients[userID]
	return exists
}

// 获取在线用户列表
func (s *WebRTCSignalingServer) GetOnlineUsers() map[uint]int64 {
	s.OnlineUsersMutex.RLock()
	defer s.OnlineUsersMutex.RUnlock()

	// 创建副本
	onlineUsers := make(map[uint]int64)
	for userID, lastActive := range s.OnlineUsers {
		onlineUsers[userID] = lastActive
	}

	return onlineUsers
}

// 更新用户活跃时间
func (s *WebRTCSignalingServer) UpdateUserActivity(userID uint) {
	s.OnlineUsersMutex.Lock()
	defer s.OnlineUsersMutex.Unlock()

	s.OnlineUsers[userID] = time.Now().Unix()
}

// 发送消息到用户
func (s *WebRTCSignalingServer) SendToUser(userID uint, message []byte) error {
	s.ClientsMutex.RLock()
	defer s.ClientsMutex.RUnlock()

	conn, exists := s.Clients[userID]
	if !exists {
		return fmt.Errorf("用户 %d 不在线", userID)
	}

	return conn.WriteMessage(websocket.TextMessage, message)
}

// 发送JSON消息到用户
func (s *WebRTCSignalingServer) SendJSONToUser(userID uint, message map[string]interface{}) error {
	s.ClientsMutex.RLock()
	defer s.ClientsMutex.RUnlock()

	conn, exists := s.Clients[userID]
	if !exists {
		return fmt.Errorf("用户 %d 不在线", userID)
	}

	return conn.WriteJSON(message)
}

// 发送通话响应
func (s *WebRTCSignalingServer) SendCallResponse(fromUserID, toUserID uint, callType string, callID uint, response string) error {
	s.ClientsMutex.RLock()
	defer s.ClientsMutex.RUnlock()

	// 检查接收者是否在线
	toConn, exists := s.Clients[toUserID]
	if !exists {
		return fmt.Errorf("接收者不在线")
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
		return err
	}

	// 发送响应
	err = toConn.WriteMessage(websocket.TextMessage, jsonMessage)
	if err != nil {
		return err
	}

	log.Printf("已从用户 %d 发送%s通话响应到用户 %d: %s", fromUserID, callType, toUserID, response)
	return nil
}
