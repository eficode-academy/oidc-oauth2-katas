FROM node:16.4.2-alpine3.12

RUN mkdir -p /apps/client-nodejs /apps/client-nodejs-v2 /apps/object-store /apps/object-store-v2 /apps/hazard-service /apps/cdn /apps/cdn/dist /apps/bff

COPY client-nodejs /apps/client-nodejs
RUN cd /apps/client-nodejs && npm install

COPY client-nodejs-v2 /apps/client-nodejs-v2
RUN cd /apps/client-nodejs-v2 && npm install

COPY object-store /apps/object-store
RUN cd /apps/object-store && npm install

COPY object-store-v2 /apps/object-store-v2
RUN cd /apps/object-store-v2 && npm install

COPY hazard-service /apps/hazard-service
RUN cd /apps/hazard-service && npm install

COPY spa/cdn /apps/cdn
RUN cd /apps/cdn && npm install
COPY spa/spa-app-vanilla-js/dist /apps/cdn/dist

COPY spa/bff /apps/bff
RUN cd /apps/bff && npm install

EXPOSE 5000

WORKDIR /apps/client-nodejs
CMD [ "npm", "start" ]
