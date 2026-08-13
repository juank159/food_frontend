# Sirve los archivos web ya compilados localmente con flutter build web.
# El build se hace en tu Mac antes del git push — no se compila Flutter aquí.
# Deploy en ~30 segundos en vez de 5 minutos.
FROM nginx:1.27-alpine

COPY build/web /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
