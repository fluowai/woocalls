# Stage 1: Build client frontend
FROM node:22-alpine AS client-builder
WORKDIR /app/client
COPY client/package*.json ./
RUN npm ci
COPY client/ ./
RUN npm run build

# Stage 2: Build Go backend
FROM golang:alpine AS server-builder
RUN apk add --no-cache git ca-certificates
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /app/wacalls-server ./cmd/server

# Stage 3: Minimal runtime container
FROM alpine:latest AS runner
RUN apk add --no-cache ca-certificates tzdata
WORKDIR /app

COPY --from=client-builder /app/client/dist /app/client/dist
COPY --from=server-builder /app/wacalls-server /app/wacalls-server

RUN mkdir -p /data
VOLUME /data

EXPOSE 8080
ENV PORT=8080

ENTRYPOINT ["/app/wacalls-server"]
CMD ["-addr", ":8080", "-db", "/data/wacalls.db", "-static", "/app/client/dist"]
