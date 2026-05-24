#!/bin/sh
set -eu

iptables -P OUTPUT ACCEPT
iptables -F OUTPUT

exit 0
