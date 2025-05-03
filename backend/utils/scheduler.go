package utils

import (
	"time"
)

// 定时任务管理器
type Scheduler struct {
	tasks map[string]*Task
}

// 定时任务
type Task struct {
	Name     string
	Interval time.Duration
	Func     func()
	ticker   *time.Ticker
	stop     chan bool
}

// 全局定时任务管理器
var SchedulerManager = NewScheduler()

// 创建定时任务管理器
func NewScheduler() *Scheduler {
	return &Scheduler{
		tasks: make(map[string]*Task),
	}
}

// 添加定时任务
func (s *Scheduler) AddTask(name string, interval time.Duration, f func()) {
	task := &Task{
		Name:     name,
		Interval: interval,
		Func:     f,
		stop:     make(chan bool),
	}
	s.tasks[name] = task
}

// 启动所有定时任务
func (s *Scheduler) StartAll() {
	for _, task := range s.tasks {
		go s.startTask(task)
	}
}

// 启动单个定时任务
func (s *Scheduler) startTask(task *Task) {
	task.ticker = time.NewTicker(task.Interval)
	Logger.Infof("启动定时任务: %s, 间隔: %v", task.Name, task.Interval)

	for {
		select {
		case <-task.ticker.C:
			Logger.Infof("执行定时任务: %s", task.Name)
			func() {
				defer func() {
					if r := recover(); r != nil {
						Logger.Errorf("定时任务 %s 执行出错: %v", task.Name, r)
					}
				}()
				task.Func()
			}()
		case <-task.stop:
			task.ticker.Stop()
			Logger.Infof("停止定时任务: %s", task.Name)
			return
		}
	}
}

// 停止定时任务
func (s *Scheduler) StopTask(name string) {
	if task, exists := s.tasks[name]; exists {
		task.stop <- true
		delete(s.tasks, name)
	}
}

// 停止所有定时任务
func (s *Scheduler) StopAll() {
	for name, task := range s.tasks {
		task.stop <- true
		delete(s.tasks, name)
	}
}
