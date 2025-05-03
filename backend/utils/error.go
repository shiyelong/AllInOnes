package utils

// AppError 应用错误
type AppError struct {
	Code    int
	Message string
}

func (e *AppError) Error() string {
	return e.Message
}
