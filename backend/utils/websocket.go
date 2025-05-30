package utils

import (
	"encoding/json"
	"log"
	"sync"

	"github.com/gorilla/websocket"
)

// WebSocketConnection 表示一个WebSocket连接
type WebSocketConnection struct {
	Conn      *websocket.Conn
	UserID    uint
	mu        sync.Mutex
	isClosing bool
}

// WebSocketManager 管理所有WebSocket连接
type WebSocketManager struct {
	connections map[uint]*WebSocketConnection
	mu          sync.RWMutex
}

var (
	// 全局WebSocket管理器
	wsManager     *WebSocketManager
	wsManagerOnce sync.Once
)

// GetWebSocketManager 获取全局WebSocket管理器实例
func GetWebSocketManager() *WebSocketManager {
	wsManagerOnce.Do(func() {
		wsManager = &WebSocketManager{
			connections: make(map[uint]*WebSocketConnection),
		}
	})
	return wsManager
}

// AddConnection 添加一个新的WebSocket连接
func (m *WebSocketManager) AddConnection(userID uint, conn *websocket.Conn) *WebSocketConnection {
	m.mu.Lock()
	defer m.mu.Unlock()

	// 如果已存在连接，先关闭旧连接
	if oldConn, exists := m.connections[userID]; exists {
		oldConn.mu.Lock()
		oldConn.isClosing = true
		oldConn.mu.Unlock()
		oldConn.Conn.Close()
	}

	// 创建新连接
	wsConn := &WebSocketConnection{
		Conn:      conn,
		UserID:    userID,
		isClosing: false,
	}
	m.connections[userID] = wsConn
	return wsConn
}

// RemoveConnection 移除一个WebSocket连接
func (m *WebSocketManager) RemoveConnection(userID uint) {
	m.mu.Lock()
	defer m.mu.Unlock()

	if conn, exists := m.connections[userID]; exists {
		conn.mu.Lock()
		conn.isClosing = true
		conn.mu.Unlock()
		conn.Conn.Close()
		delete(m.connections, userID)
	}
}

// GetConnection 获取指定用户的WebSocket连接
func (m *WebSocketManager) GetConnection(userID uint) *WebSocketConnection {
	m.mu.RLock()
	defer m.mu.RUnlock()

	return m.connections[userID]
}

// SendToUser 向指定用户发送消息
func (m *WebSocketManager) SendToUser(userID uint, message interface{}) bool {
	m.mu.RLock()
	conn, exists := m.connections[userID]
	m.mu.RUnlock()

	if !exists || conn == nil {
		return false
	}

	conn.mu.Lock()
	defer conn.mu.Unlock()

	if conn.isClosing {
		return false
	}

	// 将消息转换为JSON
	jsonMessage, err := json.Marshal(message)
	if err != nil {
		log.Printf("Error marshaling message: %v", err)
		return false
	}

	// 发送消息
	err = conn.Conn.WriteMessage(websocket.TextMessage, jsonMessage)
	if err != nil {
		log.Printf("Error sending message to user %d: %v", userID, err)
		return false
	}

	return true
}

// BroadcastMessage 向所有连接的用户广播消息
func (m *WebSocketManager) BroadcastMessage(message interface{}) {
	m.mu.RLock()
	defer m.mu.RUnlock()

	// 将消息转换为JSON
	jsonMessage, err := json.Marshal(message)
	if err != nil {
		log.Printf("Error marshaling broadcast message: %v", err)
		return
	}

	// 向所有连接的用户发送消息
	for userID, conn := range m.connections {
		conn.mu.Lock()
		if !conn.isClosing {
			err := conn.Conn.WriteMessage(websocket.TextMessage, jsonMessage)
			if err != nil {
				log.Printf("Error broadcasting to user %d: %v", userID, err)
			}
		}
		conn.mu.Unlock()
	}
}

// PushMessageToUser 向指定用户推送消息的便捷函数
func PushMessageToUser(userID uint, message interface{}) bool {
	return GetWebSocketManager().SendToUser(userID, message)
}

// BroadcastMessageToAll 向所有用户广播消息的便捷函数
func BroadcastMessageToAll(message interface{}) {
	GetWebSocketManager().BroadcastMessage(message)
}
