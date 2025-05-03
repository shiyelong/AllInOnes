package routes

import (
	"allinone_backend/controllers"

	"github.com/gin-gonic/gin"
)

func RegisterChatRoutes(r *gin.RouterGroup) {
	chat := r.Group("/chat")
	{
		chat.POST("/single", controllers.SendMessage) // 兼容旧接口
		chat.POST("/group", controllers.GroupChat)
		chat.GET("/recent", controllers.GetRecentChats)
		chat.GET("/sync", controllers.SyncMessages)
		chat.GET("/messages", controllers.GetMessagesByUser)

		// 获取聊天列表
		chat.GET("/list", func(c *gin.Context) {
			c.JSON(200, gin.H{
				"success": true,
				"msg":     "获取聊天列表成功",
				"data": []gin.H{
					{
						"id":            1,
						"type":          "single", // single或group
						"target_id":     2,
						"target_name":   "用户2",
						"target_avatar": "https://picsum.photos/200/300",
						"last_message":  "你好",
						"unread":        2,
						"updated_at":    1625123456,
					},
				},
			})
		})

		// 获取聊天消息
		chat.GET("/messages/:id", func(c *gin.Context) {
			c.JSON(200, gin.H{
				"success": true,
				"msg":     "获取聊天消息成功",
				"data": []gin.H{
					{
						"id":         1,
						"sender_id":  1,
						"content":    "你好",
						"type":       "text", // text, image, voice, video
						"created_at": 1625123456,
					},
					{
						"id":         2,
						"sender_id":  2,
						"content":    "你好，有什么事吗？",
						"type":       "text",
						"created_at": 1625123457,
					},
				},
			})
		})

		// 发送聊天消息
		chat.POST("/send", controllers.SendMessage)

		// 红包相关
		redpacket := chat.Group("/redpacket")
		{
			redpacket.POST("/send", controllers.SendRedPacket)
			redpacket.POST("/grab", controllers.GrabRedPacket)
			redpacket.GET("/detail", controllers.GetRedPacketDetail)

			// 新版红包接口（集成钱包系统）
			redpacket.POST("/send/wallet", controllers.SendRedPacketWithWallet)
			redpacket.POST("/grab/wallet", controllers.GrabRedPacketWithWallet)
		}

		// 语音视频通话
		call := chat.Group("/call")
		{
			call.POST("/voice/start", controllers.StartVoiceCall)
			call.POST("/voice/end", controllers.EndVoiceCall)
			call.POST("/voice/reject", controllers.RejectVoiceCall)
			call.POST("/video/start", controllers.StartVideoCall)
			call.POST("/video/end", controllers.EndVideoCall)
			call.POST("/video/reject", controllers.RejectVideoCall)
			call.GET("/history", controllers.GetCallHistory)
		}

		// 文件上传
		chat.POST("/upload", controllers.UploadFileEnhanced)

		// 表情包
		emoticon := chat.Group("/emoticon")
		{
			emoticon.GET("/packages", controllers.GetEmoticonPackages)
			emoticon.GET("/list", controllers.GetEmoticons)
		}
	}
}
