FROM debian:12

# Create a user with UID 1000
RUN useradd -m -u 1000 -s /bin/bash appuser

# Note: the vim package does not include Python3 support,
# so we need to install vim-nox (no X)

# Install necessary packages
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
	ca-certificates \
	vim-nox \
	python3-pip \
	python3-venv \
	curl \
	git && \
    rm -rf /var/lib/apt/lists/*

# Install vim-plug
COPY install-plugins.sh /usr/local/bin/install-vim-plugins
COPY entrypoint.sh /usr/local/bin/vim-entrypoint
RUN chmod 755 /usr/local/bin/install-vim-plugins /usr/local/bin/vim-entrypoint

# Switch to the new user
USER appuser

# Create .vim dir with user permissions
RUN mkdir -p ~/.vim
COPY --chown=appuser:appuser .vimrc /home/appuser/.vimrc

# Set the working directory
WORKDIR /home/appuser

# Install plugins (VIM_PLUG_REF allows pinning the vim-plug revision)
ARG VIM_PLUG_REF=master
RUN /usr/local/bin/install-vim-plugins

ENTRYPOINT ["/usr/local/bin/vim-entrypoint"]
CMD []

