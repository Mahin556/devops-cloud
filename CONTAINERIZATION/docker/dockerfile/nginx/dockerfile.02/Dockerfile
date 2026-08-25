FROM nginx:alpine

COPY index.html /usr/share/nginx/html/index.html

RUN apk add --no-cache curl

HEALTHCHECK --interval=30s --timeout=3s --retries=3 \
  CMD curl -f http://localhost/ || exit 1

EXPOSE 80

CMD ["sh", "-c", "sleep 360 & nginx -g 'daemon off;'"]