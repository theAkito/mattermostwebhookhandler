#########################################################################
# Copyright (C) 2023 Akito <the@akito.ooo>                              #
#                                                                       #
# This program is free software: you can redistribute it and/or modify  #
# it under the terms of the GNU General Public License as published by  #
# the Free Software Foundation, either version 3 of the License, or     #
# (at your option) any later version.                                   #
#                                                                       #
# This program is distributed in the hope that it will be useful,       #
# but WITHOUT ANY WARRANTY; without even the implied warranty of        #
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the          #
# GNU General Public License for more details.                          #
#                                                                       #
# You should have received a copy of the GNU General Public License     #
# along with this program.  If not, see <http://www.gnu.org/licenses/>. #
#########################################################################

FROM nimlang/nim:1.6.12-alpine AS build

WORKDIR /app

COPY . .

RUN \
  nimble install -dy && \
  nimble docker_build_prod

FROM alpine
COPY --from=build /app/app /
RUN apk --no-cache add libcurl && rm -rf /var/cache/apk/*
ENTRYPOINT ["/app"]
