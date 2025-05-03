package routes

import (
	"allinone_backend/controllers"

	"github.com/gin-gonic/gin"
)

func RegisterFriendsRoutes(r *gin.RouterGroup) {
	friends := r.Group("/friends")
	{
		friends.POST("/add", controllers.AddFriend)
		friends.GET("/list", controllers.GetFriends)
		friends.POST("/block", controllers.BlockFriend)
		friends.POST("/unblock", controllers.UnblockFriend)
		friends.GET("/requests", controllers.GetFriendRequests)
		friends.POST("/agree", controllers.AgreeFriendRequest)
		friends.POST("/reject", controllers.RejectFriendRequest)
		friends.POST("/batch/agree", controllers.BatchAgreeFriendRequests)
		friends.POST("/batch/reject", controllers.BatchRejectFriendRequests)
		friends.GET("/search", controllers.SearchUsers)
		friends.GET("/mode", controllers.GetFriendAddMode)
		friends.POST("/mode", controllers.SetFriendAddMode)
	}
}
