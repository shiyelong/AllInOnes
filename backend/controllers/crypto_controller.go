package controllers

import (
	"allinone_backend/models"
	"allinone_backend/utils"
	"net/http"
	"strconv"
	"time"

	"github.com/gin-gonic/gin"
)

// 添加虚拟货币钱包
func AddCryptoWallet(c *gin.Context) {
	// 获取当前用户ID
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"success": false, "msg": "未授权"})
		return
	}

	// 解析请求参数
	var req struct {
		CurrencyType string `json:"currency_type" binding:"required"`
		Address      string `json:"address" binding:"required"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "msg": "参数错误"})
		return
	}

	// 检查货币类型是否支持
	supportedCurrencies := map[string]bool{
		"BTC":  true,
		"ETH":  true,
		"USDT": true,
		"BNB":  true,
		"XRP":  true,
		"ADA":  true,
		"SOL":  true,
		"DOGE": true,
	}

	if !supportedCurrencies[req.CurrencyType] {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "msg": "不支持的虚拟货币类型"})
		return
	}

	// 检查地址是否已存在
	var existingWallet models.CryptoWallet
	if err := utils.DB.Where("address = ? AND currency_type = ?", req.Address, req.CurrencyType).First(&existingWallet).Error; err == nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "msg": "该地址已绑定"})
		return
	}

	// 创建虚拟货币钱包
	wallet := models.CryptoWallet{
		UserID:       userID.(uint),
		CurrencyType: req.CurrencyType,
		Address:      req.Address,
		Balance:      0,
		CreatedAt:    time.Now().Unix(),
		UpdatedAt:    time.Now().Unix(),
	}

	if err := utils.DB.Create(&wallet).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "msg": "添加虚拟货币钱包失败"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"msg":     "虚拟货币钱包添加成功",
		"data":    wallet,
	})
}

// 获取虚拟货币钱包列表
func GetCryptoWallets(c *gin.Context) {
	// 获取当前用户ID
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"success": false, "msg": "未授权"})
		return
	}

	// 查询虚拟货币钱包列表
	var wallets []models.CryptoWallet
	if err := utils.DB.Where("user_id = ?", userID).Find(&wallets).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "msg": "获取虚拟货币钱包列表失败"})
		return
	}

	// 对地址进行掩码处理
	for i := range wallets {
		wallets[i].Address = utils.MaskAddress(wallets[i].Address)
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"data":    wallets,
	})
}

// 删除虚拟货币钱包
func DeleteCryptoWallet(c *gin.Context) {
	// 获取当前用户ID
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"success": false, "msg": "未授权"})
		return
	}

	// 获取钱包ID
	walletIDStr := c.Param("id")
	walletID, err := strconv.ParseUint(walletIDStr, 10, 32)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "msg": "无效的钱包ID"})
		return
	}

	// 检查钱包是否存在且属于当前用户
	var wallet models.CryptoWallet
	if err := utils.DB.Where("id = ? AND user_id = ?", walletID, userID).First(&wallet).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"success": false, "msg": "钱包不存在或不属于当前用户"})
		return
	}

	// 检查钱包余额
	if wallet.Balance > 0 {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "msg": "钱包余额不为0，无法删除"})
		return
	}

	// 删除钱包
	if err := utils.DB.Delete(&wallet).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "msg": "删除钱包失败"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"msg":     "钱包删除成功",
	})
}

// 虚拟货币充值
func DepositCrypto(c *gin.Context) {
	// 获取当前用户ID
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"success": false, "msg": "未授权"})
		return
	}

	// 解析请求参数
	var req struct {
		WalletID    uint    `json:"wallet_id" binding:"required"`
		Amount      float64 `json:"amount" binding:"required"`
		TxHash      string  `json:"tx_hash" binding:"required"`
		FromAddress string  `json:"from_address" binding:"required"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "msg": "参数错误"})
		return
	}

	// 检查金额
	if req.Amount <= 0 {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "msg": "充值金额必须大于0"})
		return
	}

	// 检查钱包是否存在且属于当前用户
	var wallet models.CryptoWallet
	if err := utils.DB.Where("id = ? AND user_id = ?", req.WalletID, userID).First(&wallet).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"success": false, "msg": "钱包不存在或不属于当前用户"})
		return
	}

	// 检查交易哈希是否已存在
	var existingTx models.CryptoTransaction
	if err := utils.DB.Where("tx_hash = ?", req.TxHash).First(&existingTx).Error; err == nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "msg": "交易哈希已存在"})
		return
	}

	// 创建交易记录
	now := time.Now().Unix()
	tx := models.CryptoTransaction{
		WalletID:     req.WalletID,
		UserID:       userID.(uint),
		Type:         "deposit",
		Amount:       req.Amount,
		Fee:          0,
		Status:       0, // pending
		TxHash:       req.TxHash,
		FromAddress:  req.FromAddress,
		ToAddress:    wallet.Address,
		CreatedAt:    now,
		CompletedAt:  0,
	}

	if err := utils.DB.Create(&tx).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "msg": "创建交易记录失败"})
		return
	}

	// 模拟异步处理充值
	// 在实际应用中，这应该是一个异步任务
	go func() {
		time.Sleep(5 * time.Second)

		// 更新交易状态
		utils.DB.Model(&tx).Updates(map[string]interface{}{
			"status":      1, // completed
			"completed_at": time.Now().Unix(),
		})

		// 更新钱包余额
		utils.DB.Model(&wallet).Update("balance", wallet.Balance+req.Amount)
	}()

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"msg":     "充值请求已提交，等待确认",
		"data":    tx,
	})
}

// 虚拟货币提现
func WithdrawCrypto(c *gin.Context) {
	// 获取当前用户ID
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"success": false, "msg": "未授权"})
		return
	}

	// 解析请求参数
	var req struct {
		WalletID   uint    `json:"wallet_id" binding:"required"`
		Amount     float64 `json:"amount" binding:"required"`
		ToAddress  string  `json:"to_address" binding:"required"`
		Fee        float64 `json:"fee"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "msg": "参数错误"})
		return
	}

	// 检查金额
	if req.Amount <= 0 {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "msg": "提现金额必须大于0"})
		return
	}

	// 检查钱包是否存在且属于当前用户
	var wallet models.CryptoWallet
	if err := utils.DB.Where("id = ? AND user_id = ?", req.WalletID, userID).First(&wallet).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"success": false, "msg": "钱包不存在或不属于当前用户"})
		return
	}

	// 检查余额是否足够
	totalAmount := req.Amount + req.Fee
	if wallet.Balance < totalAmount {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "msg": "钱包余额不足"})
		return
	}

	// 创建交易记录
	now := time.Now().Unix()
	tx := models.CryptoTransaction{
		WalletID:     req.WalletID,
		UserID:       userID.(uint),
		Type:         "withdraw",
		Amount:       req.Amount,
		Fee:          req.Fee,
		Status:       0, // pending
		TxHash:       "",
		FromAddress:  wallet.Address,
		ToAddress:    req.ToAddress,
		CreatedAt:    now,
		CompletedAt:  0,
	}

	if err := utils.DB.Create(&tx).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "msg": "创建交易记录失败"})
		return
	}

	// 更新钱包余额
	if err := utils.DB.Model(&wallet).Update("balance", wallet.Balance-totalAmount).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "msg": "更新钱包余额失败"})
		return
	}

	// 模拟异步处理提现
	// 在实际应用中，这应该是一个异步任务
	go func() {
		time.Sleep(5 * time.Second)

		// 生成随机交易哈希
		txHash := utils.GenerateRandomHash()

		// 更新交易状态
		utils.DB.Model(&tx).Updates(map[string]interface{}{
			"status":      1, // completed
			"completed_at": time.Now().Unix(),
			"tx_hash":     txHash,
		})
	}()

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"msg":     "提现请求已提交，等待处理",
		"data":    tx,
	})
}

// 获取虚拟货币交易记录
func GetCryptoTransactions(c *gin.Context) {
	// 获取当前用户ID
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"success": false, "msg": "未授权"})
		return
	}

	// 解析请求参数
	walletIDStr := c.Query("wallet_id")
	typeStr := c.Query("type") // deposit, withdraw, all
	limitStr := c.DefaultQuery("limit", "20")
	offsetStr := c.DefaultQuery("offset", "0")

	// 转换参数
	limit, _ := strconv.Atoi(limitStr)
	offset, _ := strconv.Atoi(offsetStr)

	// 构建查询
	query := utils.DB.Where("user_id = ?", userID)

	// 按钱包ID筛选
	if walletIDStr != "" {
		walletID, err := strconv.ParseUint(walletIDStr, 10, 32)
		if err == nil {
			query = query.Where("wallet_id = ?", walletID)
		}
	}

	// 按类型筛选
	if typeStr != "" && typeStr != "all" {
		query = query.Where("type = ?", typeStr)
	}

	// 查询交易记录
	var transactions []models.CryptoTransaction
	if err := query.Order("created_at DESC").Limit(limit).Offset(offset).Find(&transactions).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "msg": "获取交易记录失败"})
		return
	}

	// 查询钱包信息
	var walletIDs []uint
	for _, tx := range transactions {
		walletIDs = append(walletIDs, tx.WalletID)
	}

	var wallets []models.CryptoWallet
	utils.DB.Where("id IN ?", walletIDs).Find(&wallets)

	// 构建钱包映射
	walletMap := make(map[uint]models.CryptoWallet)
	for _, wallet := range wallets {
		walletMap[wallet.ID] = wallet
	}

	// 构造响应数据
	var result []gin.H
	for _, tx := range transactions {
		wallet, exists := walletMap[tx.WalletID]
		currencyType := ""
		if exists {
			currencyType = wallet.CurrencyType
		}

		result = append(result, gin.H{
			"id":           tx.ID,
			"wallet_id":    tx.WalletID,
			"type":         tx.Type,
			"amount":       tx.Amount,
			"fee":          tx.Fee,
			"status":       tx.Status,
			"tx_hash":      tx.TxHash,
			"from_address": tx.FromAddress,
			"to_address":   tx.ToAddress,
			"created_at":   tx.CreatedAt,
			"completed_at": tx.CompletedAt,
			"currency_type": currencyType,
		})
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"data":    result,
	})
}
