FROM registry.access.redhat.com/ubi9/ubi-minimal:9.2-750.1697625013

USER 0
RUN microdnf install -y zsh
