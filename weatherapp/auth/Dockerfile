# build stage: compiles the LOCAL source (2021 git-cloned GitHub here instead)
FROM golang:1.27.1-alpine3.24 AS builder
WORKDIR /src
COPY src/authdb/ ./authdb/
COPY src/main/go.mod src/main/go.sum ./main/
WORKDIR /src/main
RUN go mod download
COPY src/main/ ./
RUN CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /out/auth .

# final stage: a small image that runs as a non-root user
FROM alpine:3.24.2
RUN apk --no-cache add ca-certificates \
    && adduser -D -H -u 10001 app
COPY --from=builder /out/auth /app
USER 10001
EXPOSE 8080
LABEL Name=auth Version=2.1.0
ENTRYPOINT ["/app"]
