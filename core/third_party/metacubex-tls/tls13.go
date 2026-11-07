// Copyright 2024 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// Package tls13 implements the TLS 1.3 Key Schedule as specified in RFC 8446,
// Section 7.1 and allowed by FIPS 140-3 IG 2.4.B Resolution 7.
package tls

import (
	"encoding/binary"
	"hash"

	"github.com/metacubex/hkdf"
)

// We don't set the service indicator in this package but we delegate that to
// the underlying functions because the TLS 1.3 KDF does not have a standard of
// its own.

// tls13ExpandLabel implements HKDF-Expand-Label from RFC 8446, Section 7.1.
func tls13ExpandLabel[H hash.Hash](hash func() H, secret []byte, label string, context []byte, length int) []byte {
	if len("tls13 ")+len(label) > 255 || len(context) > 255 {
		// It should be impossible for this to panic: labels are fixed strings,
		// and context is either a fixed-length computed hash, or parsed from a
		// field which has the same length limitation.
		//
		// Another reasonable approach might be to return a randomized slice if
		// we encounter an error, which would break the connection, but avoid
		// panicking. This would perhaps be safer but significantly more
		// confusing to users.
		panic("tls13: label or context too long")
	}
	hkdfLabel := make([]byte, 0, 2+1+len("tls13 ")+len(label)+1+len(context))
	hkdfLabel = binary.BigEndian.AppendUint16(hkdfLabel, uint16(length))
	hkdfLabel = append(hkdfLabel, byte(len("tls13 ")+len(label)))
	hkdfLabel = append(hkdfLabel, "tls13 "...)
	hkdfLabel = append(hkdfLabel, label...)
	hkdfLabel = append(hkdfLabel, byte(len(context)))
	hkdfLabel = append(hkdfLabel, context...)
	b, err := hkdf.Expand(hash, secret, string(hkdfLabel), length)
	if err != nil {
		panic(err)
	}
	return b
}

func tls13extract[H hash.Hash](hash func() H, newSecret, currentSecret []byte) []byte {
	if newSecret == nil {
		newSecret = make([]byte, hash().Size())
	}
	b, err := hkdf.Extract(hash, newSecret, currentSecret)
	if err != nil {
		panic(err)
	}
	return b
}

func tls13deriveSecret[H hash.Hash](hash func() H, secret []byte, label string, transcript hash.Hash) []byte {
	if transcript == nil {
		transcript = hash()
	}
	return tls13ExpandLabel(hash, secret, label, transcript.Sum(nil), transcript.Size())
}

const (
	resumptionBinderLabel         = "res binder"
	clientEarlyTrafficLabel       = "c e traffic"
	clientHandshakeTrafficLabel   = "c hs traffic"
	serverHandshakeTrafficLabel   = "s hs traffic"
	clientApplicationTrafficLabel = "c ap traffic"
	serverApplicationTrafficLabel = "s ap traffic"
	earlyExporterLabel            = "e exp master"
	exporterLabel                 = "exp master"
	resumptionLabel               = "res master"
)

type tls13EarlySecret struct {
	secret []byte
	hash   func() hash.Hash
}

func tls13NewEarlySecret[H hash.Hash](h func() H, psk []byte) *tls13EarlySecret {
	return &tls13EarlySecret{
		secret: tls13extract(h, psk, nil),
		hash:   func() hash.Hash { return h() },
	}
}

func (s *tls13EarlySecret) ResumptionBinderKey() []byte {
	return tls13deriveSecret(s.hash, s.secret, resumptionBinderLabel, nil)
}

// ClientEarlyTrafficSecret derives the client_early_traffic_secret from the
// early secret and the transcript up to the ClientHello.
func (s *tls13EarlySecret) ClientEarlyTrafficSecret(transcript hash.Hash) []byte {
	return tls13deriveSecret(s.hash, s.secret, clientEarlyTrafficLabel, transcript)
}

type tls13HandshakeSecret struct {
	secret []byte
	hash   func() hash.Hash
}

func (s *tls13EarlySecret) HandshakeSecret(sharedSecret []byte) *tls13HandshakeSecret {
	derived := tls13deriveSecret(s.hash, s.secret, "derived", nil)
	return &tls13HandshakeSecret{
		secret: tls13extract(s.hash, sharedSecret, derived),
		hash:   s.hash,
	}
}

// ClientHandshakeTrafficSecret derives the client_handshake_traffic_secret from
// the handshake secret and the transcript up to the ServerHello.
func (s *tls13HandshakeSecret) ClientHandshakeTrafficSecret(transcript hash.Hash) []byte {
	return tls13deriveSecret(s.hash, s.secret, clientHandshakeTrafficLabel, transcript)
}

// ServerHandshakeTrafficSecret derives the server_handshake_traffic_secret from
// the handshake secret and the transcript up to the ServerHello.
func (s *tls13HandshakeSecret) ServerHandshakeTrafficSecret(transcript hash.Hash) []byte {
	return tls13deriveSecret(s.hash, s.secret, serverHandshakeTrafficLabel, transcript)
}

type tls13MasterSecret struct {
	secret []byte
	hash   func() hash.Hash
}

func (s *tls13HandshakeSecret) MasterSecret() *tls13MasterSecret {
	derived := tls13deriveSecret(s.hash, s.secret, "derived", nil)
	return &tls13MasterSecret{
		secret: tls13extract(s.hash, nil, derived),
		hash:   s.hash,
	}
}

// ClientApplicationTrafficSecret derives the client_application_traffic_secret_0
// from the master secret and the transcript up to the server Finished.
func (s *tls13MasterSecret) ClientApplicationTrafficSecret(transcript hash.Hash) []byte {
	return tls13deriveSecret(s.hash, s.secret, clientApplicationTrafficLabel, transcript)
}

// ServerApplicationTrafficSecret derives the server_application_traffic_secret_0
// from the master secret and the transcript up to the server Finished.
func (s *tls13MasterSecret) ServerApplicationTrafficSecret(transcript hash.Hash) []byte {
	return tls13deriveSecret(s.hash, s.secret, serverApplicationTrafficLabel, transcript)
}

// ResumptionMasterSecret derives the resumption_master_secret from the master secret
// and the transcript up to the client Finished.
func (s *tls13MasterSecret) ResumptionMasterSecret(transcript hash.Hash) []byte {
	return tls13deriveSecret(s.hash, s.secret, resumptionLabel, transcript)
}

type tls13ExporterMasterSecret struct {
	secret []byte
	hash   func() hash.Hash
}

// ExporterMasterSecret derives the exporter_master_secret from the master secret
// and the transcript up to the server Finished.
func (s *tls13MasterSecret) ExporterMasterSecret(transcript hash.Hash) *tls13ExporterMasterSecret {
	return &tls13ExporterMasterSecret{
		secret: tls13deriveSecret(s.hash, s.secret, exporterLabel, transcript),
		hash:   s.hash,
	}
}

// EarlyExporterMasterSecret derives the exporter_master_secret from the early secret
// and the transcript up to the ClientHello.
func (s *tls13EarlySecret) EarlyExporterMasterSecret(transcript hash.Hash) *tls13ExporterMasterSecret {
	return &tls13ExporterMasterSecret{
		secret: tls13deriveSecret(s.hash, s.secret, earlyExporterLabel, transcript),
		hash:   s.hash,
	}
}

func (s *tls13ExporterMasterSecret) Exporter(label string, context []byte, length int) []byte {
	secret := tls13deriveSecret(s.hash, s.secret, label, nil)
	h := s.hash()
	h.Write(context)
	return tls13ExpandLabel(s.hash, secret, "exporter", h.Sum(nil), length)
}

func tls13TestingOnlyExporterSecret(s *tls13ExporterMasterSecret) []byte {
	return s.secret
}
