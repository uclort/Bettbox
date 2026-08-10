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

func TestURLTestTimeoutStartsAfterQueue(t *testing.T) {
	adapter.UnifiedDelay.Store(false)
	t.Cleanup(func() { adapter.UnifiedDelay.Store(false) })

	blockStarted := make(chan struct{})
	releaseBlock := make(chan struct{})
	var startOnce sync.Once
	var releaseOnce sync.Once
	t.Cleanup(func() { releaseOnce.Do(func() { close(releaseBlock) }) })
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, req *http.Request) {
		if req.URL.Path == "/block" {
			startOnce.Do(func() { close(blockStarted) })
			<-releaseBlock
		}
		w.WriteHeader(http.StatusNoContent)
	}))
	t.Cleanup(server.Close)

	blocker := adapter.NewProxy(outbound.NewDirect())
	target := adapter.NewProxy(outbound.NewDirect())
	blockerResult := make(chan error, 1)
	go func() {
		ctx := adapter.WithURLTestTrace(context.Background(), adapter.URLTestTrace{
			ConcurrencyLimit: 1,
			Timeout:          2 * time.Second,
		})
		_, err := blocker.URLTest(ctx, server.URL+"/block", nil)
		blockerResult <- err
	}()
	<-blockStarted

	targetResult := make(chan error, 1)
	go func() {
		ctx := adapter.WithURLTestTrace(context.Background(), adapter.URLTestTrace{
			ConcurrencyLimit: 1,
			Timeout:          100 * time.Millisecond,
		})
		_, err := target.URLTest(ctx, server.URL+"/target", nil)
		targetResult <- err
	}()

	select {
	case err := <-targetResult:
		t.Fatalf("queued URLTest finished before receiving a slot: %v", err)
	case <-time.After(150 * time.Millisecond):
	}
	releaseOnce.Do(func() { close(releaseBlock) })
	if err := <-blockerResult; err != nil {
		t.Fatalf("blocker URLTest failed: %v", err)
	}
	if err := <-targetResult; err != nil {
		t.Fatalf("queued URLTest failed after receiving a slot: %v", err)
	}
}

func TestURLTestBackgroundIsNotStarvedByForegroundQueue(t *testing.T) {
	adapter.UnifiedDelay.Store(false)
	t.Cleanup(func() { adapter.UnifiedDelay.Store(false) })

	blockStarted := make(chan struct{}, 16)
	releaseBlocks := make(chan struct{})
	backgroundStarted := make(chan struct{})
	releaseBackground := make(chan struct{})
	manualStarted := make(chan struct{})
	var releaseBlocksOnce sync.Once
	var releaseBackgroundOnce sync.Once
	t.Cleanup(func() {
		releaseBlocksOnce.Do(func() { close(releaseBlocks) })
		releaseBackgroundOnce.Do(func() { close(releaseBackground) })
	})
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, req *http.Request) {
		switch req.URL.Path {
		case "/block":
			blockStarted <- struct{}{}
			<-releaseBlocks
		case "/background":
			close(backgroundStarted)
			<-releaseBackground
		case "/manual":
			close(manualStarted)
		}
		w.WriteHeader(http.StatusNoContent)
	}))
	t.Cleanup(server.Close)

	results := make(chan error, 18)
	for i := 0; i < 16; i++ {
		proxy := adapter.NewProxy(outbound.NewDirect())
		go func() {
			ctx := adapter.WithURLTestTrace(context.Background(), adapter.URLTestTrace{
				ConcurrencyLimit: 16,
				Timeout:          3 * time.Second,
			})
			_, err := proxy.URLTest(ctx, server.URL+"/block", nil)
			results <- err
		}()
	}
	for i := 0; i < 16; i++ {
		<-blockStarted
	}

	manual := adapter.NewProxy(outbound.NewDirect())
	go func() {
		ctx := adapter.WithURLTestTrace(context.Background(), adapter.URLTestTrace{
			ConcurrencyLimit: 16,
			Timeout:          3 * time.Second,
		})
		_, err := manual.URLTest(ctx, server.URL+"/manual", nil)
		results <- err
	}()
	background := adapter.NewProxy(outbound.NewDirect())
	go func() {
		ctx := adapter.WithURLTestTrace(context.Background(), adapter.URLTestTrace{
			Background: true,
			Timeout:    3 * time.Second,
		})
		_, err := background.URLTest(ctx, server.URL+"/background", nil)
		results <- err
	}()

	releaseBlocks <- struct{}{}
	select {
	case <-backgroundStarted:
	case <-time.After(time.Second):
		t.Fatal("background URLTest stayed behind the foreground queue")
	}
	select {
	case <-manualStarted:
		t.Fatal("foreground URLTest started before the queued background test released its slot")
	default:
	}

	releaseBackgroundOnce.Do(func() { close(releaseBackground) })
	select {
	case <-manualStarted:
	case <-time.After(time.Second):
		t.Fatal("foreground URLTest did not resume after background completion")
	}
	releaseBlocksOnce.Do(func() { close(releaseBlocks) })
	for i := 0; i < 18; i++ {
		if err := <-results; err != nil {
			t.Fatalf("URLTest failed: %v", err)
		}
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
