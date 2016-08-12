#!/bin/sh

info() {
    echo "INFO reload.sh - ${@}"
}

waitForConsul() {
    while ! curl $CONSUL:8500/v1/status/leader 2>&1 | grep 8300; do
        info 'Waiting for a consul leader...';
        sleep 1
    done
    info 'Consul leader found.'
}

# Render HAProxy configuration template using values from Consul,
# but do not reload because it has't started yet
preStart() {
    waitForConsul
    consul-template \
        -once \
        -dedup \
        -consul $CONSUL:8500 \
        -template '/etc/haproxy/haproxy.cfg.ctmpl:/etc/haproxy/haproxy.cfg'
    info 'preStart template done.'
}

# Render HAProxy configuration template using values from Consul,
# then gracefully reload the service
onChange() {
    consul-template \
        -once \
        -dedup \
        -consul $CONSUL:8500 \
        -template '/etc/haproxy/haproxy.cfg.ctmpl:/etc/haproxy/haproxy.cfg:sh /usr/local/bin/reload.sh reload'
    info 'onChange template done.'
}

# Reloads the service through supervisor without downtime
reload() {
    info 'Reloading HAProxy...'
    supervisorctl -c /etc/supervisor.d/supervisor-service.ini restart haproxy:* || \
        (info 'HAProxy NOT reloaded.'; exit 1;)
    info 'HAProxy reloaded.'
}

help() {
    info 'Usage: ./reload.sh preStart  => first-run configuration for HAProxy'
    info '       ./reload.sh onChange  => [default] update HAProxy config on upstream changes'
}

until
    cmd=$1
    if [ -z "$cmd" ]; then
        onChange
    fi
    shift 1
    $cmd "$@"
    [ "$?" -ne 127 ]
do
    onChange
    exit
done
