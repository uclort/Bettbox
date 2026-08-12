package adapter

import (
	"context"
	"encoding/json"
	"fmt"
	"net"
	"net/url"
	"strings"
	"time"

	"github.com/metacubex/mihomo/common/atomic"
	"github.com/metacubex/mihomo/common/queue"
	"github.com/metacubex/mihomo/common/utils"
	"github.com/metacubex/mihomo/common/xsync"
	"github.com/metacubex/mihomo/component/ca"
	C "github.com/metacubex/mihomo/constant"
	"github.com/metacubex/mihomo/log"

	"github.com/metacubex/http"
)

var UnifiedDelay = atomic.NewBool(false)

const defaultHistoriesNum = 10

type internalProxyState struct {
	alive   atomic.Bool
	history *queue.Queue[C.DelayHistory]
}

type Proxy struct {
	C.ProxyAdapter
	alive   atomic.Bool
	retired atomic.Bool
	history *queue.Queue[C.DelayHistory]
	extra   xsync.Map[string, *internalProxyState]
}

// Adapter implements C.Proxy
func (p *Proxy) Adapter() C.ProxyAdapter {
	return p.ProxyAdapter
}

// AliveForTestUrl implements C.Proxy
func (p *Proxy) AliveForTestUrl(url string) bool {
	if state, ok := p.extra.Load(url); ok {
		return state.alive.Load()
	}

	return p.alive.Load()
}

// DialContext implements C.ProxyAdapter
func (p *Proxy) DialContext(ctx context.Context, metadata *C.Metadata) (C.Conn, error) {
	conn, err := p.ProxyAdapter.DialContext(ctx, metadata)
	return conn, err
}

// ListenPacketContext implements C.ProxyAdapter
func (p *Proxy) ListenPacketContext(ctx context.Context, metadata *C.Metadata) (C.PacketConn, error) {
	pc, err := p.ProxyAdapter.ListenPacketContext(ctx, metadata)
	return pc, err
}

// DelayHistory implements C.Proxy
func (p *Proxy) DelayHistory() []C.DelayHistory {
	queueM := p.history.Copy()
	histories := []C.DelayHistory{}
	for _, item := range queueM {
		histories = append(histories, item)
	}
	return histories
}

// DelayHistoryForTestUrl implements C.Proxy
func (p *Proxy) DelayHistoryForTestUrl(url string) []C.DelayHistory {
	var queueM []C.DelayHistory

	if state, ok := p.extra.Load(url); ok {
		queueM = state.history.Copy()
	}
	histories := []C.DelayHistory{}
	for _, item := range queueM {
		histories = append(histories, item)
	}
	return histories
}

// ExtraDelayHistories return all delay histories for each test URL
// implements C.Proxy
func (p *Proxy) ExtraDelayHistories() map[string]C.ProxyState {
	histories := map[string]C.ProxyState{}

	p.extra.Range(func(k string, v *internalProxyState) bool {
		testUrl := k
		state := v

		queueM := state.history.Copy()
		var history []C.DelayHistory

		for _, item := range queueM {
			history = append(history, item)
		}

		histories[testUrl] = C.ProxyState{
			Alive:   state.alive.Load(),
			History: history,
		}
		return true
	})
	return histories
}

// LastDelayForTestUrl return last history record of the specified URL. if proxy is not alive, return the max value of uint16.
// implements C.Proxy
func (p *Proxy) LastDelayForTestUrl(url string) (delay uint16) {
	var maxDelay uint16 = 0xffff

	alive := false
	var history C.DelayHistory

	if state, ok := p.extra.Load(url); ok {
		alive = state.alive.Load()
		history = state.history.Last()
	}

	if !alive || history.Delay == 0 {
		return maxDelay
	}
	return history.Delay
}

// MarshalJSON implements C.ProxyAdapter
func (p *Proxy) MarshalJSON() ([]byte, error) {
	inner, err := p.ProxyAdapter.MarshalJSON()
	if err != nil {
		return inner, err
	}

	mapping := map[string]any{}
	_ = json.Unmarshal(inner, &mapping)
	mapping["history"] = p.DelayHistory()
	mapping["extra"] = p.ExtraDelayHistories()
	mapping["alive"] = p.alive.Load()
	mapping["name"] = p.Name()
	mapping["udp"] = p.SupportUDP()
	mapping["uot"] = p.SupportUOT()

	proxyInfo := p.ProxyInfo()
	mapping["xudp"] = proxyInfo.XUDP
	mapping["tfo"] = proxyInfo.TFO
	mapping["mptcp"] = proxyInfo.MPTCP
	mapping["smux"] = proxyInfo.SMUX
	mapping["interface"] = proxyInfo.Interface
	mapping["routing-mark"] = proxyInfo.RoutingMark
	mapping["provider-name"] = proxyInfo.ProviderName
	mapping["dialer-proxy"] = proxyInfo.DialerProxy

	return json.Marshal(mapping)
}

// URLTest get the delay for the specified URL
// implements C.Proxy
func (p *Proxy) URLTest(ctx context.Context, url string, expectedStatus utils.IntRanges[uint16]) (t uint16, err error) {
	if p.retired.Load() {
		return 0, context.Canceled
	}
	if timeout := URLTestTraceFromContext(ctx).Timeout; timeout > 0 {
		if deadline, ok := ctx.Deadline(); !ok || time.Until(deadline) > timeout {
			var cancel context.CancelFunc
			ctx, cancel = context.WithTimeout(ctx, timeout)
			defer cancel()
		}
	}
	// BETTBOX-CUSTOM: 每次测速都独立发起，不排队、不合并、不复用结果。
	return p.urlTest(ctx, url, expectedStatus)
}

// CancelURLTests prevents replaced proxy instances from accepting new tests or publishing stale hooks.
func CancelURLTests(proxies []C.Proxy) {
	for _, proxy := range proxies {
		if target, ok := proxy.(*Proxy); ok {
			target.retired.Store(true)
		}
	}
}

func (p *Proxy) urlTest(ctx context.Context, url string, expectedStatus utils.IntRanges[uint16]) (t uint16, err error) {
	trace := URLTestTraceFromContext(ctx)
	if trace.ID == "" {
		trace.ID = utils.NewUUIDV4().String()
	}
	if trace.Source == "" {
		trace.Source = "mihomo"
	}
	proxyInfo := p.ProxyInfo()
	testURL := urlForLog(url)
	testStarted := time.Now()
	deadlineIn := int64(-1)
	if deadline, ok := ctx.Deadline(); ok {
		deadlineIn = time.Until(deadline).Milliseconds()
	}
	stage := "parse-url"
	statusCode := 0
	var satisfied bool

	log.Infoln("[DELAY-TEST][NETWORK] id=%s source=%s batch=%s phase=start proxy=%q type=%s address=%q provider=%q interface=%q url=%q deadline-in=%dms unified=%t",
		trace.ID, trace.Source, trace.BatchID, p.Name(), p.Type(), p.Addr(), proxyInfo.ProviderName, proxyInfo.Interface, testURL, deadlineIn, UnifiedDelay.Load())

	defer func() {
		if UrlTestHook != nil && !p.retired.Load() {
			UrlTestHook(url, p.Name(), t)
		}

		alive := err == nil
		record := C.DelayHistory{Time: time.Now()}
		if alive {
			record.Delay = t
		}

		p.alive.Store(alive)
		p.history.Put(record)
		if p.history.Len() > defaultHistoriesNum {
			p.history.Pop()
		}

		state, _ := p.extra.LoadOrStoreFn(url, func() *internalProxyState {
			return &internalProxyState{
				history: queue.New[C.DelayHistory](defaultHistoriesNum),
				alive:   atomic.NewBool(true),
			}
		})

		if !satisfied {
			record.Delay = 0
			alive = false
		}

		state.alive.Store(alive)
		state.history.Put(record)
		if state.history.Len() > defaultHistoriesNum {
			state.history.Pop()
		}

		elapsed := time.Since(testStarted).Milliseconds()
		contextErr := ctx.Err()
		if err != nil {
			log.Warnln("[DELAY-TEST][NETWORK] id=%s source=%s batch=%s phase=finish outcome=error stage=%s proxy=%q type=%s provider=%q url=%q elapsed=%dms delay=%dms status=%d alive=%t context-error=%v error-type=%T error=%v",
				trace.ID, trace.Source, trace.BatchID, stage, p.Name(), p.Type(), proxyInfo.ProviderName, testURL, elapsed, t, statusCode, alive, contextErr, err, err)
		} else if !satisfied {
			log.Warnln("[DELAY-TEST][NETWORK] id=%s source=%s batch=%s phase=finish outcome=unexpected-status stage=%s proxy=%q type=%s provider=%q url=%q elapsed=%dms delay=%dms status=%d alive=%t context-error=%v",
				trace.ID, trace.Source, trace.BatchID, stage, p.Name(), p.Type(), proxyInfo.ProviderName, testURL, elapsed, t, statusCode, alive, contextErr)
		} else {
			log.Infoln("[DELAY-TEST][NETWORK] id=%s source=%s batch=%s phase=finish outcome=success stage=%s proxy=%q type=%s provider=%q url=%q elapsed=%dms delay=%dms status=%d alive=%t context-error=%v",
				trace.ID, trace.Source, trace.BatchID, stage, p.Name(), p.Type(), proxyInfo.ProviderName, testURL, elapsed, t, statusCode, alive, contextErr)
		}

	}()

	unifiedDelay := UnifiedDelay.Load()

	addr, err := urlToMetadata(url)
	if err != nil {
		return
	}

	stage = "dial"
	start := time.Now()
	instance, err := p.DialContext(ctx, &addr)
	if err != nil {
		return
	}
	defer func() {
		_ = instance.Close()
	}()

	stage = "create-request"
	method := http.MethodHead
	if strings.HasPrefix(strings.ToLower(url), "http://") {
		method = http.MethodGet
	}
	req, err := http.NewRequest(method, url, nil)
	if err != nil {
		return
	}
	req = req.WithContext(ctx)

	stage = "tls-config"
	tlsConfig, err := ca.GetTLSConfig(ca.Option{})
	if err != nil {
		return
	}

	transport := &http.Transport{
		DialContext: func(context.Context, string, string) (net.Conn, error) {
			return instance, nil
		},
		// from http.DefaultTransport
		MaxIdleConns:          100,
		IdleConnTimeout:       90 * time.Second,
		TLSHandshakeTimeout:   10 * time.Second,
		ExpectContinueTimeout: 1 * time.Second,
		TLSClientConfig:       tlsConfig,
	}

	client := http.Client{
		Timeout:   30 * time.Second,
		Transport: transport,
		CheckRedirect: func(req *http.Request, via []*http.Request) error {
			return http.ErrUseLastResponse
		},
	}

	defer client.CloseIdleConnections()

	stage = "http-" + strings.ToLower(method)
	resp, err := client.Do(req)

	if err != nil {
		return
	}

	_ = resp.Body.Close()

	// HTTP 测速端点常被代理线路劫持或主动断开复用连接，不能发送第二次请求。
	if unifiedDelay && strings.HasPrefix(strings.ToLower(url), "https://") {
		stage = "second-http-" + strings.ToLower(method)
		second := time.Now()
		var ignoredErr error
		var secondResp *http.Response
		secondResp, ignoredErr = client.Do(req)
		if ignoredErr == nil {
			resp = secondResp
			_ = resp.Body.Close()
			start = second
		}
	}

	stage = "validate-status"
	if resp != nil {
		statusCode = resp.StatusCode
	}
	satisfied = resp != nil && (expectedStatus == nil || expectedStatus.Check(uint16(resp.StatusCode)))
	t = uint16(time.Since(start) / time.Millisecond)
	stage = "complete"
	return
}

func urlForLog(rawURL string) string {
	parsed, err := url.Parse(rawURL)
	if err != nil {
		return "<invalid-url>"
	}
	parsed.User = nil
	parsed.RawQuery = ""
	parsed.Fragment = ""
	return parsed.String()
}

func NewProxy(adapter C.ProxyAdapter) *Proxy {
	return &Proxy{
		ProxyAdapter: adapter,
		history:      queue.New[C.DelayHistory](defaultHistoriesNum),
		alive:        atomic.NewBool(true),
	}
}

func urlToMetadata(rawURL string) (addr C.Metadata, err error) {
	u, err := url.Parse(rawURL)
	if err != nil {
		return
	}

	port := u.Port()
	if port == "" {
		switch u.Scheme {
		case "https":
			port = "443"
		case "http":
			port = "80"
		default:
			err = fmt.Errorf("%s scheme not Support", rawURL)
			return
		}
	}

	err = addr.SetRemoteAddress(net.JoinHostPort(u.Hostname(), port))
	return
}
