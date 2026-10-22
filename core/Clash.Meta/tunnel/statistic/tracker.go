package statistic

import (
	"io"
	"net"
	"strings"
	"time"

	"github.com/metacubex/mihomo/common/atomic"
	"github.com/metacubex/mihomo/common/buf"
	N "github.com/metacubex/mihomo/common/net"
	"github.com/metacubex/mihomo/common/utils"
	C "github.com/metacubex/mihomo/constant"

	"github.com/gofrs/uuid/v5"
)

type Tracker interface {
	ID() string
	Close() error
	Info() *TrackerInfo
	C.Connection
}

type TrackerInfo struct {
	UUID                  uuid.UUID                `json:"id"`
	Metadata              *C.Metadata              `json:"metadata"`
	UploadTotal           atomic.Int64             `json:"upload"`
	DownloadTotal         atomic.Int64             `json:"download"`
	Start                 time.Time                `json:"start"`
	Chain                 C.Chain                  `json:"chains"`
	ProviderChain         C.Chain                  `json:"providerChains"`
	Rule                  string                   `json:"rule"`
	RulePayload           string                   `json:"rulePayload"`
	OutboundLocalAddress  string                   `json:"outboundLocalAddress,omitempty"`
	OutboundRemoteAddress string                   `json:"outboundRemoteAddress,omitempty"`
	Trace                 []C.ConnectionTraceEvent `json:"trace,omitempty"`
	IsDirect              bool                     `json:"-"`
}

type tcpTracker struct {
	C.Conn `json:"-"`
	*TrackerInfo
	manager *Manager

	pushToManager bool        `json:"-"`
	closed        atomic.Bool `json:"-"`
}

func (tt *tcpTracker) ID() string {
	return tt.UUID.String()
}

func (tt *tcpTracker) Info() *TrackerInfo {
	return tt.TrackerInfo
}

func (tt *tcpTracker) Read(b []byte) (int, error) {
	n, err := tt.Conn.Read(b)
	download := int64(n)
	if tt.pushToManager {
		tt.manager.PushDownloaded(tt.IsDirect, download)
	}
	tt.DownloadTotal.Add(download)
	return n, err
}

func (tt *tcpTracker) ReadBuffer(buffer *buf.Buffer) (err error) {
	err = tt.Conn.ReadBuffer(buffer)
	download := int64(buffer.Len())
	if tt.pushToManager {
		tt.manager.PushDownloaded(tt.IsDirect, download)
	}
	tt.DownloadTotal.Add(download)
	return
}

func (tt *tcpTracker) UnwrapReader() (io.Reader, []N.CountFunc) {
	return tt.Conn, []N.CountFunc{func(download int64) {
		if tt.pushToManager {
			tt.manager.PushDownloaded(tt.IsDirect, download)
		}
		tt.DownloadTotal.Add(download)
	}}
}

func (tt *tcpTracker) Write(b []byte) (int, error) {
	n, err := tt.Conn.Write(b)
	upload := int64(n)
	if tt.pushToManager {
		tt.manager.PushUploaded(tt.IsDirect, upload)
	}
	tt.UploadTotal.Add(upload)
	return n, err
}

func (tt *tcpTracker) WriteBuffer(buffer *buf.Buffer) (err error) {
	upload := int64(buffer.Len())
	err = tt.Conn.WriteBuffer(buffer)
	if tt.pushToManager {
		tt.manager.PushUploaded(tt.IsDirect, upload)
	}
	tt.UploadTotal.Add(upload)
	return
}

func (tt *tcpTracker) UnwrapWriter() (io.Writer, []N.CountFunc) {
	return tt.Conn, []N.CountFunc{func(upload int64) {
		if tt.pushToManager {
			tt.manager.PushUploaded(tt.IsDirect, upload)
		}
		tt.UploadTotal.Add(upload)
	}}
}

func (tt *tcpTracker) Close() error {
	if tt.closed.CompareAndSwap(false, true) {
		tt.manager.Leave(tt)
	}
	return tt.Conn.Close()
}

func (tt *tcpTracker) Upstream() any {
	return tt.Conn
}

func NewTCPTracker(conn C.Conn, manager *Manager, metadata *C.Metadata, rule C.Rule, uploadTotal int64, downloadTotal int64, pushToManager bool) *tcpTracker {
	return NewTCPTrackerWithID(conn, manager, metadata, rule, uploadTotal, downloadTotal, pushToManager, uuid.Nil, time.Time{})
}

func NewTCPTrackerWithID(conn C.Conn, manager *Manager, metadata *C.Metadata, rule C.Rule, uploadTotal int64, downloadTotal int64, pushToManager bool, id uuid.UUID, start time.Time) *tcpTracker {
	metadata.RemoteDst = conn.RemoteDestination()
	outboundLocalAddress := ""
	outboundRemoteAddress := ""
	if address := conn.LocalAddr(); address != nil {
		outboundLocalAddress = address.String()
	}
	if address := conn.RemoteAddr(); address != nil {
		outboundRemoteAddress = address.String()
	}

	chains := conn.Chains()
	lastChain := chains.Last()
	isDirect := strings.ToUpper(lastChain) == "DIRECT" || (IsDirectFunc != nil && IsDirectFunc(lastChain))

	tt := &tcpTracker{
		Conn:    conn,
		manager: manager,
		TrackerInfo: &TrackerInfo{
			UUID:                  trackerUUID(id),
			Start:                 trackerStartTime(id, start),
			Metadata:              metadata,
			Chain:                 chains,
			ProviderChain:         conn.ProviderChains(),
			Rule:                  "",
			OutboundLocalAddress:  outboundLocalAddress,
			OutboundRemoteAddress: outboundRemoteAddress,
			Trace:                 metadata.ConnectionTrace.Events(),
			UploadTotal:           atomic.NewInt64(uploadTotal),
			DownloadTotal:         atomic.NewInt64(downloadTotal),
			IsDirect:              isDirect,
		},
		pushToManager: pushToManager,
	}

	if pushToManager {
		if uploadTotal > 0 {
			manager.PushUploaded(isDirect, uploadTotal)
		}
		if downloadTotal > 0 {
			manager.PushDownloaded(isDirect, downloadTotal)
		}
	}

	if rule != nil {
		tt.TrackerInfo.Rule = rule.RuleType().String()
		tt.TrackerInfo.RulePayload = rule.Payload()
	}

	manager.Join(tt)
	return tt
}

type udpTracker struct {
	C.PacketConn `json:"-"`
	*TrackerInfo
	manager *Manager

	pushToManager bool        `json:"-"`
	closed        atomic.Bool `json:"-"`
}

func (ut *udpTracker) ID() string {
	return ut.UUID.String()
}

func (ut *udpTracker) Info() *TrackerInfo {
	return ut.TrackerInfo
}

func (ut *udpTracker) ReadFrom(b []byte) (int, net.Addr, error) {
	n, addr, err := ut.PacketConn.ReadFrom(b)
	download := int64(n)
	if ut.pushToManager {
		ut.manager.PushDownloaded(ut.IsDirect, download)
	}
	ut.DownloadTotal.Add(download)
	return n, addr, err
}

func (ut *udpTracker) WaitReadFrom() (data []byte, put func(), addr net.Addr, err error) {
	data, put, addr, err = ut.PacketConn.WaitReadFrom()
	download := int64(len(data))
	if ut.pushToManager {
		ut.manager.PushDownloaded(ut.IsDirect, download)
	}
	ut.DownloadTotal.Add(download)
	return
}

func (ut *udpTracker) WriteTo(b []byte, addr net.Addr) (int, error) {
	n, err := ut.PacketConn.WriteTo(b, addr)
	upload := int64(n)
	if ut.pushToManager {
		ut.manager.PushUploaded(ut.IsDirect, upload)
	}
	ut.UploadTotal.Add(upload)
	return n, err
}

func (ut *udpTracker) Close() error {
	if ut.closed.CompareAndSwap(false, true) {
		ut.manager.Leave(ut)
	}
	return ut.PacketConn.Close()
}

func (ut *udpTracker) Upstream() any {
	return ut.PacketConn
}

func NewUDPTracker(conn C.PacketConn, manager *Manager, metadata *C.Metadata, rule C.Rule, uploadTotal int64, downloadTotal int64, pushToManager bool) *udpTracker {
	return NewUDPTrackerWithID(conn, manager, metadata, rule, uploadTotal, downloadTotal, pushToManager, uuid.Nil, time.Time{})
}

func NewUDPTrackerWithID(conn C.PacketConn, manager *Manager, metadata *C.Metadata, rule C.Rule, uploadTotal int64, downloadTotal int64, pushToManager bool, id uuid.UUID, start time.Time) *udpTracker {
	metadata.RemoteDst = conn.RemoteDestination()
	outboundLocalAddress := ""
	if address := conn.LocalAddr(); address != nil {
		outboundLocalAddress = address.String()
	}

	chains := conn.Chains()
	lastChain := chains.Last()
	isDirect := strings.ToUpper(lastChain) == "DIRECT" || (IsDirectFunc != nil && IsDirectFunc(lastChain))

	ut := &udpTracker{
		PacketConn: conn,
		manager:    manager,
		TrackerInfo: &TrackerInfo{
			UUID:                  trackerUUID(id),
			Start:                 trackerStartTime(id, start),
			Metadata:              metadata,
			Chain:                 chains,
			ProviderChain:         conn.ProviderChains(),
			Rule:                  "",
			OutboundLocalAddress:  outboundLocalAddress,
			OutboundRemoteAddress: metadata.RemoteDst,
			Trace:                 metadata.ConnectionTrace.Events(),
			UploadTotal:           atomic.NewInt64(uploadTotal),
			DownloadTotal:         atomic.NewInt64(downloadTotal),
			IsDirect:              isDirect,
		},
		pushToManager: pushToManager,
	}

	if pushToManager {
		if uploadTotal > 0 {
			manager.PushUploaded(isDirect, uploadTotal)
		}
		if downloadTotal > 0 {
			manager.PushDownloaded(isDirect, downloadTotal)
		}
	}

	if rule != nil {
		ut.TrackerInfo.Rule = rule.RuleType().String()
		ut.TrackerInfo.RulePayload = rule.Payload()
	}

	manager.Join(ut)
	return ut
}

func trackerUUID(id uuid.UUID) uuid.UUID {
	if id != uuid.Nil {
		return id
	}
	return utils.NewUUIDV4()
}

func trackerStartTime(id uuid.UUID, start time.Time) time.Time {
	if id != uuid.Nil && !start.IsZero() {
		return start
	}
	return time.Now()
}

// BETTBOX-CUSTOM: 出站套接字建立前先发布待连接记录，成功后沿用同一 UUID 替换。
func NewPendingTrackerWithStart(id uuid.UUID, metadata *C.Metadata, rule C.Rule, start time.Time) Tracker {
	info := &TrackerInfo{
		UUID:     id,
		Start:    start,
		Metadata: metadata,
		Chain:    C.Chain{},
		Trace:    metadata.ConnectionTrace.Events(),
	}
	if rule != nil {
		info.Rule = rule.RuleType().String()
		info.RulePayload = rule.Payload()
	}
	return &pendingTracker{TrackerInfo: info}
}

type pendingTracker struct {
	*TrackerInfo
}

func (pt *pendingTracker) ID() string { return pt.UUID.String() }

func (pt *pendingTracker) Close() error { return nil }

func (pt *pendingTracker) Info() *TrackerInfo { return pt.TrackerInfo }

func (pt *pendingTracker) Chains() C.Chain { return C.Chain{} }

func (pt *pendingTracker) ProviderChains() C.Chain { return C.Chain{} }

func (pt *pendingTracker) AppendToChains(C.ProxyAdapter) {}

func (pt *pendingTracker) RemoteDestination() string { return "" }
