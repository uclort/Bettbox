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
	C "github.com/metacubex/mihomo/constant"
)

func TestURLTestKeepsConcurrentNodeRequestsIndependent(t *testing.T) {
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
	if got := requests.Load(); got != 2 {
		t.Fatalf("request count = %d, want 2", got)
	}
}

func TestURLTestStartsNewRequestAfterCompletion(t *testing.T) {
	adapter.UnifiedDelay.Store(false)
	t.Cleanup(func() { adapter.UnifiedDelay.Store(false) })

	var requests atomic.Int32
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		requests.Add(1)
		w.WriteHeader(http.StatusNoContent)
	}))
	t.Cleanup(server.Close)

	proxy := adapter.NewProxy(outbound.NewDirect())
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()
	for i := 0; i < 2; i++ {
		if _, err := proxy.URLTest(ctx, server.URL, nil); err != nil {
			t.Fatalf("URLTest failed: %v", err)
		}
	}
	if got := requests.Load(); got != 2 {
		t.Fatalf("request count = %d, want 2", got)
	}
}

func TestURLTestDoesNotReuseFailure(t *testing.T) {
	adapter.UnifiedDelay.Store(false)
	t.Cleanup(func() { adapter.UnifiedDelay.Store(false) })

	var requests atomic.Int32
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		if requests.Add(1) == 1 {
			panic(http.ErrAbortHandler)
		}
		w.WriteHeader(http.StatusNoContent)
	}))
	t.Cleanup(server.Close)

	proxy := adapter.NewProxy(outbound.NewDirect())
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()
	if _, err := proxy.URLTest(ctx, server.URL, nil); err == nil {
		t.Fatal("first URLTest unexpectedly succeeded")
	}
	if _, err := proxy.URLTest(ctx, server.URL, nil); err != nil {
		t.Fatalf("second URLTest failed: %v", err)
	}
	if got := requests.Load(); got != 2 {
		t.Fatalf("request count = %d, want 2", got)
	}
}

func TestURLTestKeepsDistinctNodeInstancesIndependent(t *testing.T) {
	adapter.UnifiedDelay.Store(false)
	t.Cleanup(func() { adapter.UnifiedDelay.Store(false) })

	var requests atomic.Int32
	started := make(chan struct{}, 2)
	release := make(chan struct{})
	var releaseOnce sync.Once
	releaseRequests := func() { releaseOnce.Do(func() { close(release) }) }
	t.Cleanup(releaseRequests)
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		requests.Add(1)
		started <- struct{}{}
		<-release
		w.WriteHeader(http.StatusNoContent)
	}))
	t.Cleanup(server.Close)

	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()
	results := make(chan error, 2)
	for i := 0; i < 2; i++ {
		proxy := adapter.NewProxy(outbound.NewDirect())
		go func() {
			_, err := proxy.URLTest(ctx, server.URL, nil)
			results <- err
		}()
	}

	for i := 0; i < 2; i++ {
		<-started
	}
	releaseRequests()
	for i := 0; i < 2; i++ {
		if err := <-results; err != nil {
			t.Fatalf("URLTest failed: %v", err)
		}
	}
	if got := requests.Load(); got != 2 {
		t.Fatalf("request count = %d, want 2", got)
	}
}

func TestURLTestRejectsReplacedProxy(t *testing.T) {
	proxy := adapter.NewProxy(outbound.NewDirect())
	adapter.CancelURLTests([]C.Proxy{proxy})
	if _, err := proxy.URLTest(context.Background(), "http://example.com", nil); !errors.Is(err, context.Canceled) {
		t.Fatalf("URLTest error = %v, want context canceled", err)
	}
}

func TestURLTestHasNoGlobalConcurrencyLimit(t *testing.T) {
	adapter.UnifiedDelay.Store(false)
	t.Cleanup(func() { adapter.UnifiedDelay.Store(false) })

	const count = 32
	started := make(chan struct{}, count)
	release := make(chan struct{})
	var once sync.Once
	t.Cleanup(func() { once.Do(func() { close(release) }) })
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		started <- struct{}{}
		<-release
		w.WriteHeader(http.StatusNoContent)
	}))
	t.Cleanup(server.Close)

	results := make(chan error, count)
	for i := 0; i < count; i++ {
		proxy := adapter.NewProxy(outbound.NewDirect())
		go func() {
			ctx := adapter.WithURLTestTrace(context.Background(), adapter.URLTestTrace{Timeout: 2 * time.Second})
			_, err := proxy.URLTest(ctx, server.URL, nil)
			results <- err
		}()
	}
	for i := 0; i < count; i++ {
		select {
		case <-started:
		case <-time.After(time.Second):
			t.Fatalf("only %d/%d requests started concurrently", i, count)
		}
	}
	once.Do(func() { close(release) })
	for i := 0; i < count; i++ {
		if err := <-results; err != nil {
			t.Fatalf("URLTest failed: %v", err)
		}
	}
}

func TestURLTestTraceTimeoutAppliesPerRequest(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		time.Sleep(200 * time.Millisecond)
		w.WriteHeader(http.StatusNoContent)
	}))
	t.Cleanup(server.Close)

	proxy := adapter.NewProxy(outbound.NewDirect())
	ctx := adapter.WithURLTestTrace(context.Background(), adapter.URLTestTrace{Timeout: 50 * time.Millisecond})
	if _, err := proxy.URLTest(ctx, server.URL, nil); !errors.Is(err, context.DeadlineExceeded) {
		t.Fatalf("URLTest error = %v, want context deadline exceeded", err)
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
