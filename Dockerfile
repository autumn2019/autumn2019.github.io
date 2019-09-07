FROM alpine:3.6

# public/ 目录为静态资源的目录
# /usr/share/nginx/html/ 为nginx的默认目录

COPY public/ /usr/share/nginx/html/


VOLUME /usr/share/nginx/html
