FROM golang:1.21.3-alpine as builder
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download go.opentelemetry.io/otel
COPY ./cmd/sampleapp/*.go ./
RUN go build -trimpath -ldflags="-w -s" -o "otel-sample"

FROM gcr.io/distroless/static-debian11
COPY --from=builder /app/otel-sample /otel-sample
CMD ["/otel-sample"]