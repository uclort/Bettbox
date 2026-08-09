package tunnel

import (
	"sync/atomic"
	"testing"

	"github.com/metacubex/mihomo/common/utils"
	C "github.com/metacubex/mihomo/constant"
	P "github.com/metacubex/mihomo/constant/provider"
)

type lifecycleProvider struct {
	name   string
	closed atomic.Int32
}

func (p *lifecycleProvider) Name() string               { return p.name }
func (p *lifecycleProvider) VehicleType() P.VehicleType { return P.Inline }
func (p *lifecycleProvider) Type() P.ProviderType       { return P.Proxy }
func (p *lifecycleProvider) Initial() error             { return nil }
func (p *lifecycleProvider) Update() error              { return nil }
func (p *lifecycleProvider) Proxies() []C.Proxy         { return nil }
func (p *lifecycleProvider) Count() int                 { return 0 }
func (p *lifecycleProvider) Touch()                     {}
func (p *lifecycleProvider) HealthCheck()               {}
func (p *lifecycleProvider) Version() uint32            { return 0 }
func (p *lifecycleProvider) HealthCheckURL() string     { return "" }
func (p *lifecycleProvider) Close() error               { p.closed.Add(1); return nil }
func (p *lifecycleProvider) RegisterHealthCheckTask(string, utils.IntRanges[uint16], string, uint) {
}

func TestUpdateProxiesClosesOnlyReplacedProviders(t *testing.T) {
	configMux.Lock()
	originalProxies, originalProviders := proxies, providers
	proxies = nil
	providers = nil
	configMux.Unlock()
	t.Cleanup(func() {
		configMux.Lock()
		proxies, providers = originalProxies, originalProviders
		configMux.Unlock()
	})

	stale := &lifecycleProvider{name: "stale"}
	shared := &lifecycleProvider{name: "shared"}
	UpdateProxies(nil, map[string]P.ProxyProvider{
		"stale":  stale,
		"shared": shared,
	})
	UpdateProxies(nil, map[string]P.ProxyProvider{
		"shared": shared,
		"fresh":  &lifecycleProvider{name: "fresh"},
	})

	if got := stale.closed.Load(); got != 1 {
		t.Fatalf("stale provider close count = %d, want 1", got)
	}
	if got := shared.closed.Load(); got != 0 {
		t.Fatalf("shared provider close count = %d, want 0", got)
	}
}
