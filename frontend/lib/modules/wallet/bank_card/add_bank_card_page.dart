import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:frontend/common/api.dart';
import 'package:frontend/common/theme.dart';
import 'package:frontend/common/animations.dart';
import 'package:frontend/common/persistence.dart';
import 'package:frontend/services/wallet_service.dart';

class AddBankCardPage extends StatefulWidget {
  const AddBankCardPage({Key? key}) : super(key: key);

  @override
  _AddBankCardPageState createState() => _AddBankCardPageState();
}

class _AddBankCardPageState extends State<AddBankCardPage> {
  final _formKey = GlobalKey<FormState>();
  final _cardNumberController = TextEditingController();
  final _cardholderNameController = TextEditingController();
  final _expiryDateController = TextEditingController();
  final _idNumberController = TextEditingController();
  final _phoneNumberController = TextEditingController();

  String _selectedBankName = '招商银行';
  String _selectedCardType = '借记卡';
  String _selectedCountry = '中国';
  bool _isDefault = true;
  bool _isLoading = false;
  String? _errorMessage;
  bool _success = false;

  final List<String> _bankNames = [
    '招商银行',
    '工商银行',
    '建设银行',
    '农业银行',
    '中国银行',
    '交通银行',
    '邮储银行',
    '浦发银行',
    '中信银行',
    '光大银行',
    '民生银行',
    '华夏银行',
    '广发银行',
    '平安银行',
    '兴业银行',
  ];

  final List<String> _cardTypes = [
    '借记卡',
    '信用卡',
  ];

  final List<String> _countries = [
    '中国',
    '美国',
    '英国',
    '加拿大',
    '澳大利亚',
    '日本',
    '韩国',
    '新加坡',
    '德国',
    '法国',
  ];

  @override
  void initState() {
    super.initState();
    // 初始化表单
  }

  @override
  void dispose() {
    _cardNumberController.dispose();
    _cardholderNameController.dispose();
    _expiryDateController.dispose();
    _idNumberController.dispose();
    _phoneNumberController.dispose();
    super.dispose();
  }

  // 格式化银行卡号（每4位添加一个空格）
  String _formatCardNumber(String text) {
    if (text.isEmpty) return '';

    // 移除所有非数字字符
    final digitsOnly = text.replaceAll(RegExp(r'\D'), '');

    // 每4位添加一个空格
    final buffer = StringBuffer();
    for (int i = 0; i < digitsOnly.length; i++) {
      if (i > 0 && i % 4 == 0) {
        buffer.write(' ');
      }
      buffer.write(digitsOnly[i]);
    }

    return buffer.toString();
  }

  // 格式化有效期（MM/YY）
  String _formatExpiryDate(String text) {
    if (text.isEmpty) return '';

    // 移除所有非数字字符
    final digitsOnly = text.replaceAll(RegExp(r'\D'), '');

    // 格式化为MM/YY
    if (digitsOnly.length <= 2) {
      return digitsOnly;
    } else {
      return '${digitsOnly.substring(0, 2)}/${digitsOnly.substring(2, min(digitsOnly.length, 4))}';
    }
  }

  int min(int a, int b) => a < b ? a : b;

  // 添加银行卡
  Future<void> _addBankCard() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _success = false;
    });

    try {
      // 获取用户ID
      final userInfo = await Persistence.getUserInfoAsync();
      final userId = userInfo?.id;

      if (userId == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = '获取用户信息失败，请重新登录';
        });
        return;
      }

      // 准备请求数据
      final data = {
        'card_number': _cardNumberController.text.replaceAll(' ', ''),
        'bank_name': _selectedBankName,
        'cardholder_name': _cardholderNameController.text,
        'card_type': _selectedCardType,
        'country': _selectedCountry,
        'is_default': _isDefault,
        'id_number': _idNumberController.text,
        'phone_number': _phoneNumberController.text,
      };

      // 只有信用卡才需要有效期
      if (_selectedCardType == '信用卡') {
        data['expiry_date'] = _expiryDateController.text;
      }

      try {
        // 使用钱包服务添加银行卡
        final walletService = WalletService();
        final response = await walletService.addBankCard(data);

        if (response['success'] == true) {
          setState(() {
            _isLoading = false;
            _success = true;
          });

          // 显示成功消息
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('银行卡添加成功'),
              backgroundColor: Colors.green,
            ),
          );

          // 延迟后返回上一页
          await Future.delayed(Duration(seconds: 2));
          if (mounted) {
            Navigator.of(context).pop(true);
          }
          return;
        } else if (response['msg'] != null) {
          setState(() {
            _isLoading = false;
            _errorMessage = response['msg'];
          });
          return;
        }
      } catch (serviceError) {
        debugPrint('钱包服务添加银行卡失败，尝试直接API调用: $serviceError');
      }

      // 如果钱包服务失败，尝试直接API调用
      final response = await Api.post('/wallet/bank-card', data: data);

      if (response['success'] == true) {
        setState(() {
          _isLoading = false;
          _success = true;
        });

        // 显示成功消息
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('银行卡添加成功'),
            backgroundColor: Colors.green,
          ),
        );

        // 延迟后返回上一页
        await Future.delayed(Duration(seconds: 2));
        if (mounted) {
          Navigator.of(context).pop(true);
        }
      } else {
        // 如果API调用失败，显示错误信息
        debugPrint('API添加银行卡失败: ${response['msg']}');

        setState(() {
          _isLoading = false;
          _errorMessage = response['msg'] ?? '添加银行卡失败，请稍后重试';
        });

        // 显示错误消息
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_errorMessage ?? '添加银行卡失败，请稍后重试'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      debugPrint('添加银行卡异常: $e');

      // 显示错误信息
      setState(() {
        _isLoading = false;
        _errorMessage = '添加银行卡失败: $e';
      });

      // 显示错误消息
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('添加银行卡失败，请稍后重试'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text('添加银行卡'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 银行卡信息卡片
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  color: isDarkMode ? Color(0xFF1A237E) : Color(0xFF12B7F5),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _selectedBankName,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              _selectedCardType,
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 20),
                        Text(
                          _cardNumberController.text.isEmpty
                              ? '0000 0000 0000 0000'
                              : _cardNumberController.text,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                          ),
                        ),
                        SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '持卡人',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  _cardholderNameController.text.isEmpty
                                      ? '持卡人姓名'
                                      : _cardholderNameController.text,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                            if (_selectedCardType == '信用卡')
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '有效期',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    _expiryDateController.text.isEmpty
                                        ? 'MM/YY'
                                        : _expiryDateController.text,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 24),

                // 表单字段
                Text(
                  '银行卡信息',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 16),

                // 银行名称
                DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    labelText: '银行名称',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.account_balance),
                  ),
                  value: _selectedBankName,
                  items: _bankNames.map((String bank) {
                    return DropdownMenuItem<String>(
                      value: bank,
                      child: Text(bank),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      setState(() {
                        _selectedBankName = newValue;
                      });
                    }
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return '请选择银行';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 16),

                // 银行卡号
                TextFormField(
                  controller: _cardNumberController,
                  decoration: InputDecoration(
                    labelText: '银行卡号',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.credit_card),
                    hintText: '请输入16-19位银行卡号',
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(19),
                    TextInputFormatter.withFunction((oldValue, newValue) {
                      return TextEditingValue(
                        text: _formatCardNumber(newValue.text),
                        selection: TextSelection.collapsed(
                          offset: _formatCardNumber(newValue.text).length,
                        ),
                      );
                    }),
                  ],
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return '请输入银行卡号';
                    }
                    final digitsOnly = value.replaceAll(' ', '');
                    if (digitsOnly.length < 16 || digitsOnly.length > 19) {
                      return '银行卡号长度应为16-19位';
                    }
                    return null;
                  },
                  onChanged: (value) {
                    setState(() {});
                  },
                ),
                SizedBox(height: 16),

                // 持卡人姓名
                TextFormField(
                  controller: _cardholderNameController,
                  decoration: InputDecoration(
                    labelText: '持卡人姓名',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                    hintText: '请输入持卡人姓名',
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return '请输入持卡人姓名';
                    }
                    return null;
                  },
                  onChanged: (value) {
                    setState(() {});
                  },
                ),
                SizedBox(height: 16),

                // 有效期 - 只有信用卡需要
                if (_selectedCardType == '信用卡')
                  TextFormField(
                    controller: _expiryDateController,
                    decoration: InputDecoration(
                      labelText: '有效期 (MM/YY)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.date_range),
                      hintText: 'MM/YY',
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(4),
                      TextInputFormatter.withFunction((oldValue, newValue) {
                        return TextEditingValue(
                          text: _formatExpiryDate(newValue.text),
                          selection: TextSelection.collapsed(
                            offset: _formatExpiryDate(newValue.text).length,
                          ),
                        );
                      }),
                    ],
                    validator: (value) {
                      if (_selectedCardType == '信用卡') {
                        if (value == null || value.isEmpty) {
                          return '请输入有效期';
                        }
                        if (value.length < 5) {
                          return '请输入完整的有效期 (MM/YY)';
                        }
                        final parts = value.split('/');
                        if (parts.length != 2) {
                          return '有效期格式不正确';
                        }
                        final month = int.tryParse(parts[0]);
                        if (month == null || month < 1 || month > 12) {
                          return '月份不正确';
                        }
                      }
                      return null;
                    },
                    onChanged: (value) {
                      setState(() {});
                    },
                  ),
                if (_selectedCardType == '信用卡')
                  SizedBox(height: 16),

                // 身份证号
                TextFormField(
                  controller: _idNumberController,
                  decoration: InputDecoration(
                    labelText: '身份证号',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.badge),
                    hintText: '请输入18位身份证号',
                  ),
                  keyboardType: TextInputType.text,
                  inputFormatters: [
                    LengthLimitingTextInputFormatter(18),
                  ],
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return '请输入身份证号';
                    }
                    if (value.length != 18) {
                      return '身份证号应为18位';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 16),

                // 手机号
                TextFormField(
                  controller: _phoneNumberController,
                  decoration: InputDecoration(
                    labelText: '手机号',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.phone),
                    hintText: '请输入11位手机号',
                  ),
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(11),
                  ],
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return '请输入手机号';
                    }
                    if (value.length != 11) {
                      return '手机号应为11位';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 16),

                // 卡类型
                DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    labelText: '卡类型',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.credit_score),
                  ),
                  value: _selectedCardType,
                  items: _cardTypes.map((String type) {
                    return DropdownMenuItem<String>(
                      value: type,
                      child: Text(type),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      setState(() {
                        _selectedCardType = newValue;
                        // 如果切换到借记卡，清除有效期
                        if (newValue == '借记卡') {
                          _expiryDateController.clear();
                        }
                      });
                    }
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return '请选择卡类型';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 16),

                // 国家
                DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    labelText: '国家',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.public),
                  ),
                  value: _selectedCountry,
                  items: _countries.map((String country) {
                    return DropdownMenuItem<String>(
                      value: country,
                      child: Text(country),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      setState(() {
                        _selectedCountry = newValue;
                      });
                    }
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return '请选择国家';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 16),

                // 设为默认卡
                SwitchListTile(
                  title: Text('设为默认卡'),
                  value: _isDefault,
                  onChanged: (bool value) {
                    setState(() {
                      _isDefault = value;
                    });
                  },
                  secondary: Icon(Icons.star),
                ),
                SizedBox(height: 16),

                // 错误信息
                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 14,
                      ),
                    ),
                  ),

                // 提交按钮
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading || _success ? null : _addBankCard,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: _isLoading
                        ? CircularProgressIndicator(color: Colors.white)
                        : _success
                            ? Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.check_circle, color: Colors.white),
                                  SizedBox(width: 8),
                                  Text(
                                    '添加成功',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              )
                            : Text(
                                '添加银行卡',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                  ),
                ),
                SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
