package adapter

import (
	"context"
	"testing"
	"time"
)

func TestURLTestTraceAndLogURL(t *testing.T) {
	want := URLTestTrace{ID: "request", Source: "test", BatchID: "batch", ConcurrencyLimit: 8, Background: true, Timeout: 5 * time.Second}
	got := URLTestTraceFromContext(WithURLTestTrace(context.Background(), want))
	if got != want {
		t.Fatalf("trace mismatch: got %+v, want %+v", got, want)
	}

	gotURL := urlForLog("https://user:password@example.com/generate_204?token=secret#fragment")
	if wantURL := "https://example.com/generate_204"; gotURL != wantURL {
		t.Fatalf("log URL mismatch: got %q, want %q", gotURL, wantURL)
	}
}
