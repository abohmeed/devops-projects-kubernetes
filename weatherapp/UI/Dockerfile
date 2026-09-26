FROM node:24.21.0-alpine3.24
ENV NODE_ENV=production
WORKDIR /usr/src/app
COPY package.json package-lock.json ./
RUN npm ci --omit=dev && npm cache clean --force
COPY app.js ./
COPY public ./public
# the image's built-in non-root "node" user (uid 1000)
USER 1000
EXPOSE 3000
ENTRYPOINT ["node"]
CMD ["app.js"]
