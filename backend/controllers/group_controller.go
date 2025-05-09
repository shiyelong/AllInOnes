package controllers

import (
	"net/http"
	"strconv"
	"time"

	"allinone_backend/models"
	"allinone_backend/utils"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

// GroupController 群组控制器
type GroupController struct{}

// CreateGroup 创建群组
func (g *GroupController) CreateGroup(c *gin.Context) {
	db := c.MustGet("db").(*gorm.DB)
	var req struct {
		Name    string `json:"name" binding:"required"`
		OwnerID uint   `json:"owner_id" binding:"required"`
		Avatar  string `json:"avatar"`
		Notice  string `json:"notice"`
		Members []uint `json:"members" binding:"required"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"success": false,
			"msg":     "参数错误: " + err.Error(),
		})
		return
	}

	// 验证创建者是否存在
	var owner models.User
	if err := db.First(&owner, req.OwnerID).Error; err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"success": false,
			"msg":     "创建者不存在",
		})
		return
	}

	// 创建群组
	group := models.Group{
		Name:      req.Name,
		OwnerID:   req.OwnerID,
		Avatar:    req.Avatar,
		Notice:    req.Notice,
		CreatedAt: time.Now().Unix(),
	}

	if err := db.Create(&group).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"success": false,
			"msg":     "创建群组失败: " + err.Error(),
		})
		return
	}

	// 添加群成员
	// 确保创建者在成员列表中
	memberExists := false
	for _, memberID := range req.Members {
		if memberID == req.OwnerID {
			memberExists = true
			break
		}
	}

	if !memberExists {
		req.Members = append(req.Members, req.OwnerID)
	}

	// 添加成员
	var members []models.GroupMember
	for _, memberID := range req.Members {
		role := "member"
		if memberID == req.OwnerID {
			role = "owner"
		}

		member := models.GroupMember{
			GroupID:  group.ID,
			UserID:   memberID,
			Role:     role,
			JoinedAt: time.Now().Unix(),
		}

		members = append(members, member)
	}

	if len(members) > 0 {
		if err := db.Create(&members).Error; err != nil {
			// 记录错误但继续
			utils.Logger.Errorf("添加群成员失败: %v", err)
		}
	}

	// 获取成员数量
	var memberCount int64
	db.Model(&models.GroupMember{}).Where("group_id = ?", group.ID).Count(&memberCount)

	// 返回创建的群组信息
	groupData := gin.H{
		"id":           group.ID,
		"name":         group.Name,
		"owner_id":     group.OwnerID,
		"avatar":       group.Avatar,
		"notice":       group.Notice,
		"created_at":   group.CreatedAt,
		"member_count": memberCount,
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"msg":     "群组创建成功",
		"data":    groupData,
	})
}

// GetGroupList 获取用户的群组列表
func (g *GroupController) GetGroupList(c *gin.Context) {
	db := c.MustGet("db").(*gorm.DB)
	userIDStr := c.Query("user_id")
	if userIDStr == "" {
		c.JSON(http.StatusBadRequest, gin.H{
			"success": false,
			"msg":     "用户ID不能为空",
		})
		return
	}

	userID, err := strconv.ParseUint(userIDStr, 10, 64)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"success": false,
			"msg":     "用户ID格式错误",
		})
		return
	}

	// 查询用户所在的群组
	var groupMembers []models.GroupMember
	if err := db.Where("user_id = ?", userID).Find(&groupMembers).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"success": false,
			"msg":     "获取群组列表失败: " + err.Error(),
		})
		return
	}

	// 获取群组详情
	var groups []gin.H
	for _, member := range groupMembers {
		var group models.Group
		if err := db.First(&group, member.GroupID).Error; err != nil {
			continue // 跳过不存在的群组
		}

		// 获取成员数量
		var memberCount int64
		db.Model(&models.GroupMember{}).Where("group_id = ?", group.ID).Count(&memberCount)

		// 构建群组信息
		groupInfo := gin.H{
			"id":           group.ID,
			"name":         group.Name,
			"owner_id":     group.OwnerID,
			"avatar":       group.Avatar,
			"notice":       group.Notice,
			"created_at":   group.CreatedAt,
			"member_count": memberCount,
			"role":         member.Role,
		}

		groups = append(groups, groupInfo)
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"msg":     "获取群组列表成功",
		"data":    groups,
	})
}

// GetGroupInfo 获取群组信息
func (g *GroupController) GetGroupInfo(c *gin.Context) {
	db := c.MustGet("db").(*gorm.DB)
	groupIDStr := c.Query("group_id")
	if groupIDStr == "" {
		c.JSON(http.StatusBadRequest, gin.H{
			"success": false,
			"msg":     "群组ID不能为空",
		})
		return
	}

	groupID, err := strconv.ParseUint(groupIDStr, 10, 64)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"success": false,
			"msg":     "群组ID格式错误",
		})
		return
	}

	// 查询群组信息
	var group models.Group
	if err := db.First(&group, groupID).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"success": false,
			"msg":     "获取群组信息失败: " + err.Error(),
		})
		return
	}

	// 获取成员数量
	var memberCount int64
	db.Model(&models.GroupMember{}).Where("group_id = ?", group.ID).Count(&memberCount)

	// 构建群组信息
	groupInfo := gin.H{
		"id":           group.ID,
		"name":         group.Name,
		"owner_id":     group.OwnerID,
		"avatar":       group.Avatar,
		"notice":       group.Notice,
		"created_at":   group.CreatedAt,
		"member_count": memberCount,
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"msg":     "获取群组信息成功",
		"data":    groupInfo,
	})
}

// GetGroupMembers 获取群组成员列表
func (g *GroupController) GetGroupMembers(c *gin.Context) {
	db := c.MustGet("db").(*gorm.DB)
	groupIDStr := c.Query("group_id")
	if groupIDStr == "" {
		c.JSON(http.StatusBadRequest, gin.H{
			"success": false,
			"msg":     "群组ID不能为空",
		})
		return
	}

	groupID, err := strconv.ParseUint(groupIDStr, 10, 64)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"success": false,
			"msg":     "群组ID格式错误",
		})
		return
	}

	// 查询群组成员
	var groupMembers []models.GroupMember
	if err := db.Where("group_id = ?", groupID).Find(&groupMembers).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"success": false,
			"msg":     "获取群组成员失败: " + err.Error(),
		})
		return
	}

	// 获取成员详情
	var members []gin.H
	for _, member := range groupMembers {
		var user models.User
		if err := db.First(&user, member.UserID).Error; err != nil {
			continue // 跳过不存在的用户
		}

		// 构建成员信息
		memberInfo := gin.H{
			"user_id":    user.ID,
			"nickname":   user.Nickname,
			"avatar":     user.Avatar,
			"role":       member.Role,
			"joined_at":  member.JoinedAt,
			"group_nick": member.Nickname, // 群内昵称
		}

		members = append(members, memberInfo)
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"msg":     "获取群组成员成功",
		"data":    members,
	})
}

// UpdateGroup 更新群组信息
func (g *GroupController) UpdateGroup(c *gin.Context) {
	db := c.MustGet("db").(*gorm.DB)
	var req struct {
		GroupID uint   `json:"group_id" binding:"required"`
		Name    string `json:"name"`
		Notice  string `json:"notice"`
		Avatar  string `json:"avatar"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"success": false,
			"msg":     "参数错误: " + err.Error(),
		})
		return
	}

	// 获取当前群组信息
	var group models.Group
	if err := db.First(&group, req.GroupID).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"success": false,
			"msg":     "群组不存在",
		})
		return
	}

	// 更新群组信息
	updates := map[string]interface{}{
		"updated_at": time.Now().Unix(),
	}

	if req.Name != "" {
		updates["name"] = req.Name
	}

	if req.Notice != "" {
		updates["notice"] = req.Notice
	}

	if req.Avatar != "" {
		updates["avatar"] = req.Avatar
	}

	if err := db.Model(&models.Group{}).Where("id = ?", req.GroupID).Updates(updates).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"success": false,
			"msg":     "更新群组信息失败: " + err.Error(),
		})
		return
	}

	// 获取更新后的群组信息
	if err := db.First(&group, req.GroupID).Error; err != nil {
		c.JSON(http.StatusOK, gin.H{
			"success": true,
			"msg":     "群组信息更新成功，但获取详情失败",
		})
		return
	}

	// 获取成员数量
	var memberCount int64
	db.Model(&models.GroupMember{}).Where("group_id = ?", group.ID).Count(&memberCount)

	// 构建群组信息
	groupInfo := gin.H{
		"id":           group.ID,
		"name":         group.Name,
		"owner_id":     group.OwnerID,
		"avatar":       group.Avatar,
		"notice":       group.Notice,
		"created_at":   group.CreatedAt,
		"updated_at":   group.UpdatedAt,
		"member_count": memberCount,
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"msg":     "群组信息更新成功",
		"data":    groupInfo,
	})
}

// LeaveGroup 退出群组
func (g *GroupController) LeaveGroup(c *gin.Context) {
	db := c.MustGet("db").(*gorm.DB)
	var req struct {
		GroupID uint `json:"group_id" binding:"required"`
		UserID  uint `json:"user_id" binding:"required"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"success": false,
			"msg":     "参数错误: " + err.Error(),
		})
		return
	}

	// 检查是否是群主
	var member models.GroupMember
	if err := db.Where("group_id = ? AND user_id = ?", req.GroupID, req.UserID).First(&member).Error; err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"success": false,
			"msg":     "您不是该群组成员",
		})
		return
	}

	if member.Role == "owner" {
		c.JSON(http.StatusBadRequest, gin.H{
			"success": false,
			"msg":     "群主不能退出群组，请先转让群主身份",
		})
		return
	}

	// 退出群组
	if err := db.Where("group_id = ? AND user_id = ?", req.GroupID, req.UserID).Delete(&models.GroupMember{}).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"success": false,
			"msg":     "退出群组失败: " + err.Error(),
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"msg":     "退出群组成功",
	})
}

// AddGroupMember 添加群成员
func (g *GroupController) AddGroupMember(c *gin.Context) {
	db := c.MustGet("db").(*gorm.DB)
	var req struct {
		GroupID   uint   `json:"group_id" binding:"required"`
		UserIDs   []uint `json:"user_ids" binding:"required"`
		InviterID uint   `json:"inviter_id" binding:"required"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"success": false,
			"msg":     "参数错误: " + err.Error(),
		})
		return
	}

	// 检查邀请者是否是群成员
	var inviter models.GroupMember
	if err := db.Where("group_id = ? AND user_id = ?", req.GroupID, req.InviterID).First(&inviter).Error; err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"success": false,
			"msg":     "只有群成员才能邀请新成员",
		})
		return
	}

	// 添加成员
	successCount := 0
	for _, userID := range req.UserIDs {
		// 检查是否已经是群成员
		var existingMember models.GroupMember
		if err := db.Where("group_id = ? AND user_id = ?", req.GroupID, userID).First(&existingMember).Error; err == nil {
			// 已经是成员，跳过
			continue
		}

		member := models.GroupMember{
			GroupID:   req.GroupID,
			UserID:    userID,
			Role:      "member",
			JoinedAt:  time.Now().Unix(),
			InvitedBy: req.InviterID,
		}

		if err := db.Create(&member).Error; err != nil {
			utils.Logger.Errorf("添加群成员失败: %v", err)
			continue
		}

		successCount++
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"msg":     "成功添加 " + strconv.Itoa(successCount) + " 名成员",
	})
}

// RemoveGroupMember 移除群成员
func (g *GroupController) RemoveGroupMember(c *gin.Context) {
	db := c.MustGet("db").(*gorm.DB)
	var req struct {
		GroupID    uint `json:"group_id" binding:"required"`
		UserID     uint `json:"user_id" binding:"required"`
		OperatorID uint `json:"operator_id" binding:"required"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"success": false,
			"msg":     "参数错误: " + err.Error(),
		})
		return
	}

	// 检查操作者权限
	var operator models.GroupMember
	if err := db.Where("group_id = ? AND user_id = ?", req.GroupID, req.OperatorID).First(&operator).Error; err != nil {
		c.JSON(http.StatusForbidden, gin.H{
			"success": false,
			"msg":     "您不是该群组成员",
		})
		return
	}

	if operator.Role != "owner" && operator.Role != "admin" {
		c.JSON(http.StatusForbidden, gin.H{
			"success": false,
			"msg":     "只有群主或管理员才能移除成员",
		})
		return
	}

	// 检查被移除者
	var target models.GroupMember
	if err := db.Where("group_id = ? AND user_id = ?", req.GroupID, req.UserID).First(&target).Error; err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"success": false,
			"msg":     "要移除的成员不存在",
		})
		return
	}

	// 检查被移除者是否是群主
	if target.Role == "owner" {
		c.JSON(http.StatusForbidden, gin.H{
			"success": false,
			"msg":     "不能移除群主",
		})
		return
	}

	// 检查被移除者是否是管理员且操作者不是群主
	if target.Role == "admin" && operator.Role != "owner" {
		c.JSON(http.StatusForbidden, gin.H{
			"success": false,
			"msg":     "只有群主才能移除管理员",
		})
		return
	}

	// 移除成员
	if err := db.Where("group_id = ? AND user_id = ?", req.GroupID, req.UserID).Delete(&models.GroupMember{}).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"success": false,
			"msg":     "移除成员失败: " + err.Error(),
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"msg":     "成员移除成功",
	})
}
