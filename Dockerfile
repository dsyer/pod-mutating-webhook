FROM alpine:latest

ADD pod-mutating-webhook /pod-mutating-webhook
ENTRYPOINT ["./pod-mutating-webhook"]