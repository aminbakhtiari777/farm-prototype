# Lightweight Farm Town game server (Godot 4.7.2 headless).
# Build: docker build -t farm-town-server -f server/Dockerfile .
# Run:   docker run --rm -p 9080:9080 -p 9081:9081 \
#          -e FARM_SERVER_HOST=YOUR_SERVER_HOST -v farm-data:/opt/farm/data farm-town-server
FROM ubuntu:24.04
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    ca-certificates curl unzip libx11-6 libxcursor1 libxinerama1 libxrandr2 libxi6 libgl1 \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /opt/farm
# Godot 4.7.2 official Linux binary
RUN curl -sSL -o godot.zip https://github.com/godotengine/godot/releases/download/4.7.2-stable/Godot_v4.7.2-stable_linux.x86_64.zip \
 && unzip -q godot.zip && mv Godot_v4.7.2-stable_linux.x86_64 godot && rm godot.zip && chmod +x godot
COPY . /opt/farm/game
RUN mkdir -p /opt/farm/content /opt/farm/data \
 && /opt/farm/godot --headless --path /opt/farm/game --import || true
ENV FARM_SERVER_PORT=9080 FARM_SERVER_HEALTH_PORT=9081 FARM_SERVER_BIND=0.0.0.0
ENV FARM_CONTENT=/opt/farm/content FARM_DATA=/opt/farm/data GODOT=/opt/farm/godot
EXPOSE 9080 9081
HEALTHCHECK --interval=30s --timeout=5s --retries=3 CMD curl -fsS http://127.0.0.1:9081/health || exit 1
WORKDIR /opt/farm/game
CMD ["bash", "tools/start_server.sh"]
