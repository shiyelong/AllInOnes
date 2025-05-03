package routes

import (
	"github.com/gin-gonic/gin"
)

// RegisterMomentsRoutes 注册朋友圈相关路由
func RegisterMomentsRoutes(r *gin.RouterGroup) {
	moments := r.Group("/moments")
	{
		// 获取朋友圈动态列表
		moments.GET("", func(c *gin.Context) {
			c.JSON(200, gin.H{
				"success": true,
				"msg":     "获取朋友圈动态列表成功",
				"data": []gin.H{
					{
						"id":        1,
						"user_id":   1,
						"content":   "这是一条朋友圈动态",
						"images":    []string{"https://picsum.photos/200/300"},
						"created_at": 1625123456,
						"likes":     10,
						"comments":  5,
					},
				},
			})
		})

		// 发布朋友圈动态
		moments.POST("/post", func(c *gin.Context) {
			c.JSON(200, gin.H{
				"success": true,
				"msg":     "发布朋友圈动态成功",
			})
		})

		// 点赞朋友圈动态
		moments.POST("/like/:id", func(c *gin.Context) {
			c.JSON(200, gin.H{
				"success": true,
				"msg":     "点赞成功",
			})
		})

		// 评论朋友圈动态
		moments.POST("/comment/:id", func(c *gin.Context) {
			c.JSON(200, gin.H{
				"success": true,
				"msg":     "评论成功",
			})
		})
	}
}
