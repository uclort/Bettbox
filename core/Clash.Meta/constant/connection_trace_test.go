package constant

import (
	"context"
	"testing"
)

func TestConnectionTraceContextAndLimit(t *testing.T) {
	trace := NewConnectionTrace()
	ctx := WithConnectionTrace(context.Background(), trace)
	for i := 0; i < maxConnectionTraceEvents+1; i++ {
		AddConnectionTrace(ctx, "dns", "query", "example.com", "success")
	}

	events := trace.Events()
	if len(events) != maxConnectionTraceEvents {
		t.Fatalf("期望 %d 条事件，实际 %d 条", maxConnectionTraceEvents, len(events))
	}
	if events[0].Stage != "dns" || events[0].Status != "success" {
		t.Fatalf("首条事件异常：%#v", events[0])
	}
}
