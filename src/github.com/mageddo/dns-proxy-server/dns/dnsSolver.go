package dns

import "github.com/miekg/dns"

type DnsSolver interface {

	Solve(name string) *dns.Msg


}
