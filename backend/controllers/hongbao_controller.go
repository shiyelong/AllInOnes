package controllers

import (
	"github.com/gin-gonic/gin"
	"net/http"
	"time"
	"gorm.io/gorm"
	"allinone_backend/models"
)

// 发红包接口示例
func SendHongbao(c *gin.Context) {
	var req struct {
		SenderID   uint    `json:"sender_id"`
		ReceiverID uint    `json:"receiver_id"`
		Amount    float64 `json:"amount"`
		Remark    string  `json:"remark"`
		PayMethod string  `json:"pay_method"` // unionpay, bitcoin, ethereum, international_card
		PayAccount string `json:"pay_account"` // 支付账号或钱包地址
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "msg": "参数错误"})
		return
	}

	// 校验支付方式
	switch req.PayMethod {
	case "unionpay":
		// ok
	case "bitcoin":
		// ok
	case "ethereum":
		// ok
	case "international_card":
		// ok
	default:
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "msg": "不支持的支付方式"})
		return
	}

	db := c.MustGet("db").(*gorm.DB)
	payment := models.HongbaoPayment{
		SenderID: req.SenderID,
		ReceiverID: req.ReceiverID,
		Amount: req.Amount,
		Remark: req.Remark,
		PayMethod: models.PaymentChannel(req.PayMethod),
		PayAccount: req.PayAccount,
		Status: "pending",
		CreatedAt: time.Now().Unix(),
	}
	// 生产环境：预留各支付渠道对接点
	switch req.PayMethod {
	case "unionpay":
		// TODO: 对接银联转账API，成功后写入流水号
		payment.Status = "success"
		payment.TxHash = "unionpay-mock-tx"
	case "bitcoin":
		// TODO: 对接比特币节点转账，成功后写入TxHash
		payment.Status = "success"
		payment.TxHash = "btc-mock-tx"
	case "ethereum":
		// TODO: 对接以太坊节点转账，成功后写入TxHash
		payment.Status = "success"
		payment.TxHash = "eth-mock-tx"
	case "international_card":
		// TODO: 对接国际银行卡支付API，成功后写入流水号
		payment.Status = "success"
		payment.TxHash = "intlcard-mock-tx"
	}
	db.Create(&payment)

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"msg": "红包已发送",
		"data": payment,
	})
}
