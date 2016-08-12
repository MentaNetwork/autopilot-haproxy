FROM haproxy:1.6-alpine
MAINTAINER Menta Network <dev@mentanetwork.com>

ENV HAPROXY_STATS_AUTH=dev:pass \
    CONTAINERPILOT=file:///etc/containerpilot.json \
    CONTAINERPILOT_VERSION=2.3.0 \
    CONTAINERPILOT_SHA1=ec9dbedaca9f4a7a50762f50768cbc42879c7208 \
    CONSUL_TEMPLATE_VERSION=0.15.0 \
    CONSUL_TEMPLATE_SHA1=b7561158d2074c3c68ff62ae6fc1eafe8db250894043382fb31f0c78150c513a

# This consul template is processed by contianerpilot on preStart
COPY docker/supervisor-service.ini /etc/supervisor.d/supervisor-service.ini
COPY docker/haproxy.cfg.ctmpl /etc/haproxy/haproxy.cfg.ctmpl
COPY docker/manage.sh /usr/local/bin/manage.sh
COPY containerpilot.json /etc/
COPY docker/errorfiles /etc/haproxy/errorfiles

RUN apk update && \
    apk add curl supervisor && \
    touch /run/supervisor.sock

# Releases at https://github.com/joyent/containerpilot/releases
RUN curl --retry 5 -Lso /tmp/containerpilot.tar.gz \
    "https://github.com/joyent/containerpilot/releases/download/${CONTAINERPILOT_VERSION}/containerpilot-${CONTAINERPILOT_VERSION}.tar.gz" && \
    echo "${CONTAINERPILOT_SHA1}  /tmp/containerpilot.tar.gz" | sha1sum -c && \
    tar zxf /tmp/containerpilot.tar.gz -C /bin && \
    rm /tmp/containerpilot.tar.gz

# Releases at https://releases.hashicorp.com/consul-template/
RUN curl --retry 5 -Lso /tmp/consul-template.zip \
    "https://releases.hashicorp.com/consul-template/${CONSUL_TEMPLATE_VERSION}/consul-template_${CONSUL_TEMPLATE_VERSION}_linux_amd64.zip" && \
    echo "${CONSUL_TEMPLATE_SHA1}  /tmp/consul-template.zip" | sha256sum -c && \
    unzip /tmp/consul-template.zip -d /usr/local/bin && \
    rm /tmp/consul-template.zip

EXPOSE 80

# Start with ContainerPilot so that the load balancer gets updated
# with the frontend IPs dynamically
CMD ["containerpilot", \
    "supervisord", "-c", "/etc/supervisor.d/supervisor-service.ini"]
