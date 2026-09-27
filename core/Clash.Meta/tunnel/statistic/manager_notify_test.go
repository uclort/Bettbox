package statistic

import (
	"reflect"
	"testing"

	C "github.com/metacubex/mihomo/constant"
)

type notifyTracker struct {
	id string
	*TrackerInfo
}

func (t *notifyTracker) ID() string                            { return t.id }
func (t *notifyTracker) Close() error                          { return nil }
func (t *notifyTracker) Info() *TrackerInfo                    { return t.TrackerInfo }
func (t *notifyTracker) Chains() C.Chain                       { return nil }
func (t *notifyTracker) ProviderChains() C.Chain               { return nil }
func (t *notifyTracker) AppendToChains(adapter C.ProxyAdapter) {}
func (t *notifyTracker) RemoteDestination() string             { return "" }

func TestManagerNotifiesOnJoinAndLeave(t *testing.T) {
	previous := DefaultRequestNotify
	defer func() { DefaultRequestNotify = previous }()

	var events []string
	DefaultRequestNotify = func(tracker Tracker) {
		events = append(events, tracker.ID())
	}
	manager := &Manager{}
	tracker := &notifyTracker{id: "connection", TrackerInfo: &TrackerInfo{}}

	manager.Join(tracker)
	manager.Leave(tracker)

	if !reflect.DeepEqual(events, []string{"connection", "connection"}) {
		t.Fatalf("连接生命周期通知 = %v，期望加入和离开各一次", events)
	}
}
