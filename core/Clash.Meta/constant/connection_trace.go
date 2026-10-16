package constant

import (
	"context"
	"sync"
	"time"
)

// BETTBOX-CUSTOM: 为网络面板保存与单条连接严格关联的内核链路事件。
const maxConnectionTraceEvents = 64

type ConnectionTraceEvent struct {
	Timestamp int64  `json:"timestamp"`
	Stage     string `json:"stage"`
	Title     string `json:"title"`
	Detail    string `json:"detail"`
	Status    string `json:"status,omitempty"`
}

type ConnectionTrace struct {
	mu     sync.Mutex
	events []ConnectionTraceEvent
}

func NewConnectionTrace() *ConnectionTrace {
	return &ConnectionTrace{events: make([]ConnectionTraceEvent, 0, 12)}
}

func (t *ConnectionTrace) Add(stage, title, detail, status string) {
	if t == nil {
		return
	}
	t.mu.Lock()
	defer t.mu.Unlock()
	if len(t.events) >= maxConnectionTraceEvents {
		return
	}
	t.events = append(t.events, ConnectionTraceEvent{
		Timestamp: time.Now().UnixMilli(),
		Stage:     stage,
		Title:     title,
		Detail:    detail,
		Status:    status,
	})
}

func (t *ConnectionTrace) Events() []ConnectionTraceEvent {
	if t == nil {
		return nil
	}
	t.mu.Lock()
	defer t.mu.Unlock()
	return append([]ConnectionTraceEvent(nil), t.events...)
}

type connectionTraceContextKey struct{}

func WithConnectionTrace(ctx context.Context, trace *ConnectionTrace) context.Context {
	return context.WithValue(ctx, connectionTraceContextKey{}, trace)
}

func AddConnectionTrace(ctx context.Context, stage, title, detail, status string) {
	trace, _ := ctx.Value(connectionTraceContextKey{}).(*ConnectionTrace)
	trace.Add(stage, title, detail, status)
}
