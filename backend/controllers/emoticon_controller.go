package controllers

import (
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"
)

// 表情包数据结构
type EmoticonPackage struct {
	ID          int    `json:"id"`
	Name        string `json:"name"`
	Description string `json:"description"`
	Cover       string `json:"cover"`
	Count       int    `json:"count"`
}

type Emoticon struct {
	ID        int    `json:"id"`
	PackageID int    `json:"package_id"`
	Name      string `json:"name"`
	URL       string `json:"url"`
}

// 模拟数据
var emoticonPackages = []EmoticonPackage{
	{
		ID:          1,
		Name:        "基础表情",
		Description: "基础表情包",
		Cover:       "https://picsum.photos/200/200",
		Count:       20,
	},
	{
		ID:          2,
		Name:        "可爱动物",
		Description: "可爱动物表情包",
		Cover:       "https://picsum.photos/200/201",
		Count:       15,
	},
}

var emoticons = []Emoticon{
	{
		ID:        1,
		PackageID: 1,
		Name:      "微笑",
		URL:       "https://picsum.photos/100/100",
	},
	{
		ID:        2,
		PackageID: 1,
		Name:      "大笑",
		URL:       "https://picsum.photos/100/101",
	},
	{
		ID:        3,
		PackageID: 1,
		Name:      "哭泣",
		URL:       "https://picsum.photos/100/102",
	},
	{
		ID:        4,
		PackageID: 2,
		Name:      "小猫",
		URL:       "https://picsum.photos/100/103",
	},
	{
		ID:        5,
		PackageID: 2,
		Name:      "小狗",
		URL:       "https://picsum.photos/100/104",
	},
}

// 获取表情包列表
func GetEmoticonPackages(c *gin.Context) {
	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"data":    emoticonPackages,
	})
}

// 获取表情列表
func GetEmoticons(c *gin.Context) {
	packageIDStr := c.DefaultQuery("package_id", "0")
	packageID, _ := strconv.Atoi(packageIDStr)

	var result []Emoticon
	if packageID == 0 {
		// 返回所有表情
		result = emoticons
	} else {
		// 返回指定包的表情
		for _, e := range emoticons {
			if e.PackageID == packageID {
				result = append(result, e)
			}
		}
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"data":    result,
	})
}
