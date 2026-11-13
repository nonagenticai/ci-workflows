# Selftest fixture for image-only.yml: no language toolchain, no service — just a tiny image
# with a build arg ENV that the smoke can assert, so the workflow's build+smoke path is real.
FROM busybox:1.37

ARG GREETING=hello
ENV GREETING=$GREETING

CMD ["sh", "-c", "echo \"$GREETING\" && sleep infinity"]
