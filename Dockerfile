FROM dart:stable

WORKDIR /app

# Install project dependencies.
# If dependency_overrides contains local path entries, remove that block so
# docker builds resolve package versions from pub instead of local filesystem.
COPY pubspec.* ./
RUN if grep -q "^dependency_overrides:" pubspec.yaml; then \
      awk 'BEGIN{skip=0} /^dependency_overrides:/ {skip=1; next} skip && /^[^[:space:]]/ {skip=0} !skip {print}' pubspec.yaml > pubspec.docker.yaml && \
      mv pubspec.docker.yaml pubspec.yaml; \
    fi
RUN dart pub get

# Copy app source and refresh lock-resolved dependencies
COPY . .
RUN dart pub get --offline

ENV FLINT_HOT=0
ARG APP_PORT=3030
ENV PORT=$APP_PORT
EXPOSE $APP_PORT

CMD ["dart", "run", "lib/main.dart"]
