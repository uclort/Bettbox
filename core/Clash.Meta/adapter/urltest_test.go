package adapter_test

import (
	"context"
	"errors"
	"net/http"
	"net/http/httptest"
	"sync"
	"sync/atomic"
	"testing"
	"time"

	"github.com/metacubex/mihomo/adapter"
	"github.com/metacubex/mihomo/adapter/outbound"
)

func TestURLTestSharesConcurrentNodeRequest(t *testing.T) {
	adapter.UnifiedDelay.Store(false)
	t.Cleanup(func() { adapter.UnifiedDelay.Store(false) })

	var requests atomic.Int32
	started := make(chan struct{})
	release := make(chan struct{})
	var startOnce sync.Once
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		requests.Add(1)
		startOnce.Do(func() { close(started) })
		<-release
		w.WriteHeader(http.StatusNoContent)
	}))
	t.Cleanup(server.Close)

	proxy := adapter.NewProxy(outbound.NewDirect())
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()

	results := make(chan error, 2)
	go func() {
		_, err := proxy.URLTest(ctx, server.URL, nil)
		results <- err
	}()
	<-started
	go func() {
		_, err := proxy.URLTest(ctx, server.URL, nil)
		results <- err
	}()

	time.Sleep(50 * time.Millisecond)
	close(release)
	for i := 0; i < 2; i++ {
		if err := <-results; err != nil {
			t.Fatalf("URLTest failed: %v", err)
		}
	}
	if got := requests.Load(); got != 1 {
		t.Fatalf("request count = %d, want 1", got)
	}
}

func TestURLTestKeepsSharedRequestForRemainingCaller(t *testing.T) {
	adapter.UnifiedDelay.Store(false)
	t.Cleanup(func() { adapter.UnifiedDelay.Store(false) })

	var requests atomic.Int32
	started := make(chan struct{})
	release := make(chan struct{})
	var startOnce sync.Once
	var releaseOnce sync.Once
	releaseRequest := func() { releaseOnce.Do(func() { close(release) }) }
	t.Cleanup(releaseRequest)
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		requests.Add(1)
		startOnce.Do(func() { close(started) })
		<-release
		w.WriteHeader(http.StatusNoContent)
	}))
	t.Cleanup(server.Close)

	proxy := adapter.NewProxy(outbound.NewDirect())
	shortCtx, shortCancel := context.WithTimeout(context.Background(), 50*time.Millisecond)
	defer shortCancel()
	longCtx, longCancel := context.WithTimeout(context.Background(), time.Second)
	defer longCancel()

	shortResult := make(chan error, 1)
	longResult := make(chan error, 1)
	go func() {
		_, err := proxy.URLTest(shortCtx, server.URL, nil)
		shortResult <- err
	}()
	<-started
	go func() {
		_, err := proxy.URLTest(longCtx, server.URL, nil)
		longResult <- err
	}()

	if err := <-shortResult; !errors.Is(err, context.DeadlineExceeded) {
		t.Fatalf("short caller error = %v, want context deadline exceeded", err)
	}
	releaseRequest()
	if err := <-longResult; err != nil {
		t.Fatalf("remaining caller failed: %v", err)
	}
	if got := requests.Load(); got != 1 {
		t.Fatalf("request count = %d, want 1", got)
	}
}

func TestURLTestUsesSingleGETForHTTPUnifiedDelay(t *testing.T) {
	adapter.UnifiedDelay.Store(true)
	t.Cleanup(func() { adapter.UnifiedDelay.Store(false) })

	var requests atomic.Int32
	var method atomic.Value
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, req *http.Request) {
		requests.Add(1)
		method.Store(req.Method)
		w.WriteHeader(http.StatusNoContent)
	}))
	t.Cleanup(server.Close)

	proxy := adapter.NewProxy(outbound.NewDirect())
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()
	if _, err := proxy.URLTest(ctx, server.URL, nil); err != nil {
		t.Fatalf("URLTest failed: %v", err)
	}
	if got := requests.Load(); got != 1 {
		t.Fatalf("request count = %d, want 1", got)
	}
	if got := method.Load(); got != http.MethodGet {
		t.Fatalf("request method = %v, want GET", got)
	}
}
