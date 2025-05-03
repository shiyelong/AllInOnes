package main

import (
	"allinone_backend/utils"
	"fmt"
	"log"
)

func main() {
	// 初始化数据库
	if err := utils.InitDB(); err != nil {
		log.Fatalf("数据库初始化失败: %v", err)
	}

	// 测试银行卡号验证
	testCardNumber := "6225887654321234"
	fmt.Printf("测试银行卡号 %s 是否有效: %v\n", testCardNumber, utils.IsValidCardNumber(testCardNumber))

	// 测试掩码银行卡号
	maskedCardNumber := utils.MaskCardNumber(testCardNumber)
	fmt.Printf("掩码后的银行卡号: %s\n", maskedCardNumber)

	// 测试银行卡验证请求
	request := utils.BankCardVerifyRequest{
		CardNumber:     testCardNumber,
		CardholderName: "测试用户",
		IDNumber:       "110101199001011234",
		PhoneNumber:    "15210888310",
	}

	response, err := utils.VerifyBankCard(request)
	if err != nil {
		fmt.Printf("验证银行卡失败: %v\n", err)
	} else {
		fmt.Printf("验证银行卡结果: 成功=%v, 银行=%s, 卡类型=%s\n",
			response.Data.IsValid, response.Data.BankName, response.Data.CardType)
	}

	fmt.Println("测试完成")
}
