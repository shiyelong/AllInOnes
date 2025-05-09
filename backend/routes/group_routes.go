package routes

import (
	"allinone_backend/controllers"

	"github.com/gin-gonic/gin"
)

func RegisterGroupRoutes(r *gin.RouterGroup) {
	// 创建群组控制器实例
	groupController := &controllers.GroupController{}

	group := r.Group("/group")
	{
		// 创建群组
		group.POST("/create", groupController.CreateGroup)

		// 获取群组列表
		group.GET("/list", groupController.GetGroupList)

		// 获取群组信息
		group.GET("/info", groupController.GetGroupInfo)

		// 获取群组成员
		group.GET("/members", groupController.GetGroupMembers)

		// 更新群组信息
		group.POST("/update", groupController.UpdateGroup)

		// 退出群组
		group.POST("/leave", groupController.LeaveGroup)

		// 添加群成员
		group.POST("/add_member", groupController.AddGroupMember)

		// 移除群成员
		group.POST("/remove_member", groupController.RemoveGroupMember)
	}
}
