package statistic

import (
	"encoding/json"
	"net"
	"testing"
	"time"

	N "github.com/metacubex/mihomo/common/net"
	C "github.com/metacubex/mihomo/constant"

	"github.com/gofrs/uuid/v5"
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

func TestPendingTrackerKeepsStableIDAndPendingState(t *testing.T) {
	id := uuid.Must(uuid.NewV4())
	startedAt := time.Unix(1786400000, 0)
	trace := C.NewConnectionTrace()
	trace.Add("connect", "建立出站", "正在连接", "pending")
	tracker := NewPendingTrackerWithStart(id, &C.Metadata{
		Host:            "example.com",
		ConnectionTrace: trace,
	}, nil, startedAt)

	if tracker.ID() != id.String() {
		t.Fatalf("待连接记录 UUID = %s，期望 %s", tracker.ID(), id)
	}
	if tracker.Info().Trace[0].Status != "pending" {
		t.Fatalf("待连接记录未保留 pending 链路状态：%#v", tracker.Info().Trace)
	}
	if tracker.Info().Chain == nil {
		t.Fatal("待连接记录的 chains 不能为 null，否则 Dart 面板解析失败")
	}
	if !tracker.Info().Start.Equal(startedAt) {
		t.Fatalf("待连接记录创建时间 = %s，期望 %s", tracker.Info().Start, startedAt)
	}
}
