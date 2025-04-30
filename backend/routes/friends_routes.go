package routes

import (
	"github.com/gin-gonic/gin"
	"allinone_backend/controllers"
)

func RegisterFriendsRoutes(r *gin.Engine) {
	r.POST("/friend/add", controllers.AddFriend)
	r.GET("/friend/list", controllers.GetFriends)
	r.POST("/friend/block", controllers.BlockFriend)
	r.POST("/friend/unblock", controllers.UnblockFriend)
}
