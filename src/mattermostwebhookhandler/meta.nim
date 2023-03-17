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

##[
  Project Metadata
]##

import os
from logging import Level

const
  debug              * {.booldefine.} = false
  lineEnd            * {.booldefine.} = '\n'
  defaultDateFormat  * {.strdefine.}  = "yyyy-MM-dd'T'HH:mm:ss'.'fffffffff'+02:00'"
  dateFormatFileName * {.strdefine.}  = "yyyy-MM-dd'T'HH-mm-ss"
  dateFormatReadable * {.strdefine.}  = "yyyy/MM/dd HH:mm:ss"
  logMsgPrefix       * {.strdefine.}  = "[$levelname]:[$datetime]"
  logMsgInter        * {.strdefine.}  = " ~ "
  logMsgSuffix       * {.strdefine.}  = " -> "
  appVersion         * {.strdefine.}  = "0.1.0"
  configName         * {.strdefine.}  = "mattermostwebhookhandler.json"
  configPath         * {.strdefine.}  = ""
  configIndentation  * {.intdefine.}  = 2
  headerUserAgent    * = "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:103.0) Gecko/20100101 Firefox/103.0"
  headerKeyUserAgent     * = "user-agent"
  headerKeyCookie        * = "Cookie"
  headerKeyAuth          * = "Authorization"
  headerKeyContentType   * = "Content-Type"
  headerKeyAccept        * = "Accept"
  headerValueContentType * = "application/json"

let
  params          * = commandLineParams()

func defineLogLevel*(): Level =
  if debug: lvlDebug else: lvlInfo