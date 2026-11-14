# Selftest fixture for go-service.yml. The build CONTEXT is the repository root (a Go service's
# Dockerfile copies its module out of src/), so these paths are root-relative — that is the
# convention this archetype is built around.
FROM docker.io/library/golang:1.26-alpine AS build
WORKDIR /src
COPY fixtures/go-app/src/go.mod ./
RUN go mod download
COPY fixtures/go-app/src/main.go ./
RUN CGO_ENABLED=0 go build -o /out/app .

FROM docker.io/library/alpine:3.22
COPY --from=build /out/app /app
ENV PORT=8080
EXPOSE 8080
CMD ["/app"]
