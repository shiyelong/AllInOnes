package routes

import (
	"github.com/gin-gonic/gin"
)

// RegisterSquareRoutes 注册广场相关路由
func RegisterSquareRoutes(r *gin.RouterGroup) {
	square := r.Group("/square")
	{
		// 获取广场动态列表
		square.GET("/posts", func(c *gin.Context) {
			c.JSON(200, gin.H{
				"success": true,
				"msg":     "获取广场动态列表成功",
				"data": []gin.H{
					{
						"id":         1,
						"user_id":    1,
						"user_name":  "用户1",
						"user_avatar": "https://picsum.photos/200/300",
						"content":    "这是一条广场动态",
						"images":     []string{"https://picsum.photos/200/300"},
						"video_url":  "",
						"tags":       []string{"标签1", "标签2"},
						"created_at": 1625123456,
						"likes":      10,
						"comments":   5,
					},
				},
			})
		})

		// 发布广场动态
		square.POST("/posts/create", func(c *gin.Context) {
			c.JSON(200, gin.H{
				"success": true,
				"msg":     "发布广场动态成功",
			})
		})

		// 点赞广场动态
		square.POST("/posts/like/:id", func(c *gin.Context) {
			c.JSON(200, gin.H{
				"success": true,
				"msg":     "点赞成功",
			})
		})

		// 评论广场动态
		square.POST("/posts/comment/:id", func(c *gin.Context) {
			c.JSON(200, gin.H{
				"success": true,
				"msg":     "评论成功",
			})
		})
	}
}
