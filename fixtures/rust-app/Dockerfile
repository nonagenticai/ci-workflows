# The image half of rust-service.yml's selftest. Deliberately compiles nothing: the compile is
# proved by the checks job, and a `cargo build` inside the image would only make the selftest
# slower without exercising any workflow code. What this DOES prove is the image job's buildx
# builder, its gha cache, its build-arg plumbing and its smoke contract.
FROM alpine:3.22

ARG GREETING=hello
ENV GREETING=${GREETING}

CMD ["true"]
