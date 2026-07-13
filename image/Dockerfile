FROM debian:13

ENV DEBIAN_FRONTEND=noninteractive LANG=C.UTF-8 LC_ALL=C.UTF-8

# ── Layer 1: BASE (identical to arinanoX) ────────────────────
RUN apt-get update && apt-get install -y --no-install-recommends \
    dialog locales ca-certificates sudo \
    curl wget zip unzip jq tree less && \
    apt-get upgrade -y -o Dpkg::Options::='--force-confold' && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# ── Layer 2: SXMO SHELL (X11/dwm) + BROWSER ──────────────────
RUN apt-get update && apt-get install -y --no-install-recommends \
    sxmo-utils \
    dwm dmenu stterm lisgd svkbd-x11 wvkbd \
    dbus-x11 pulseaudio-utils netcat-openbsd x11-xserver-utils \
    firefox-esr firefox-esr-mobile-config \
    fonts-noto fonts-noto-color-emoji \
    mesa-utils glmark2 libgl1 librsvg2-common \
    xdotool gnupg yad && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# ── Layer 3: DEV TOOLS + NODE.JS (reuse from arinanoX) ──────
RUN apt-get update && apt-get install -y --no-install-recommends \
    git python3-pip python3-venv python3-dev \
    build-essential cmake pkg-config \
    htop tmux openssh-client && \
    apt-get clean && rm -rf /var/lib/apt/lists/* && \
    curl -fsSL https://deb.nodesource.com/setup_22.x | bash - && \
    apt-get install -y nodejs && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# ── Layer 4: USER + CONFIG ───────────────────────────────────
RUN useradd -m -s /bin/bash admin && \
    echo "admin:admin" | chpasswd && \
    echo "admin ALL=(ALL:ALL) NOPASSWD: ALL" > /etc/sudoers.d/admin && \
    chmod 0440 /etc/sudoers.d/admin

COPY configs-target/home/ /home/

RUN chown -R admin:admin /home/admin && \
    chmod +x /home/admin/.arinanotouch/tools/*.sh && \
    sed -i 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen && locale-gen

ENV LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8
CMD ["/bin/bash"]
