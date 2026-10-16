package statistic

import (
	"encoding/json"
	"net"
	"testing"

	N "github.com/metacubex/mihomo/common/net"
	C "github.com/metacubex/mihomo/constant"
)

type traceTestConn struct{ N.ExtendedConn }

func (c traceTestConn) Chains() C.Chain                       { return C.Chain{"DIRECT"} }
func (c traceTestConn) ProviderChains() C.Chain               { return nil }
func (c traceTestConn) AppendToChains(adapter C.ProxyAdapter) {}
func (c traceTestConn) RemoteDestination() string             { return "example.com:443" }

func TestTCPTrackerExportsSocketAddressesAndTrace(t *testing.T) {
	local, remote := net.Pipe()
	defer local.Close()
	defer remote.Close()
	trace := C.NewConnectionTrace()
	trace.Add("dns", "解析完成", "example.com", "success")
	tracker := NewTCPTracker(traceTestConn{N.NewDeadlineConn(local)}, &Manager{}, &C.Metadata{
		Host:            "example.com",
		ConnectionTrace: trace,
	}, nil, 0, 0, false)
	defer tracker.Close()
	data, err := json.Marshal(tracker.Info())
	if err != nil {
		t.Fatal(err)
	}
	var item map[string]any
	if err := json.Unmarshal(data, &item); err != nil {
		t.Fatal(err)
	}
	if item["outboundLocalAddress"] != local.LocalAddr().String() ||
		item["outboundRemoteAddress"] != local.RemoteAddr().String() ||
		len(item["trace"].([]any)) != 1 {
		t.Fatalf("面板所需的真实套接字地址或 DNS 事件丢失：%s", data)
	}
}
