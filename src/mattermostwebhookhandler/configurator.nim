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
  File Configuration Manager
]##

import
  meta,
  std/[
    logging,
    os,
    json
  ]

from strutils import isEmptyOrWhitespace

type
  MattermostAuthentication* = object
    token*: string ## https://docs.mattermost.com/developer/personal-access-tokens.html#creating-a-personal-access-token
  MattermostIdentity* = object
    authentication*: MattermostAuthentication
    username*: string
    iconURL*: string
  MattermostInstanceContext* = object
    token*: string ## https://developers.mattermost.com/integrate/webhooks/outgoing/#use-an-outgoing-webhook
    teamID*: string
    categoryDisplayName*: string ## The Category with this name, which shall be created by this handler.
    channelIDs*: seq[string]
  MattermostInstance* = object
    url*: string
    contexts*: seq[MattermostInstanceContext]
  Mattermost* = object
    identity*: MattermostIdentity
    instance*: MattermostInstance
  Server* = object
    port*: int
  MasterConfig* = object
    version*: string
    server*: Server
    mattermost*: Mattermost

let
  logger = newConsoleLogger(defineLogLevel(), logMsgPrefix & logMsgInter & "configurator" & logMsgSuffix)

var
  configMattermostAuthentication = MattermostAuthentication(
    token: ""
  )
  configMattermostIdentity = MattermostIdentity(
    authentication: configMattermostAuthentication,
    username: "",
    iconURL: ""
  )
  configMattermostInstanceContext = MattermostInstanceContext(
    token: "",
    teamID: "",
    categoryDisplayName: "",
    channelIDs: @[]
  )
  configMattermostInstance = MattermostInstance(
    url: "",
    contexts: @[configMattermostInstanceContext]
  )
  configMattermost = Mattermost(
    identity: configMattermostIdentity,
    instance: configMattermostInstance
  )
  configServer = Server(
    port: 3000
  )
  config*: MasterConfig

func pretty(node: JsonNode): string = node.pretty(configIndentation)

func genPathFull(path, name: string): string =
  if path != "": path.normalizePathEnd() & '/' & name else: name

func validateOrExcept*(conf: MasterConfig): bool {.discardable.} =
  if conf.server.port <= 0: raise FieldDefect.newException """Please, provide a valid port in the configuration file!"""
  if conf.mattermost.identity.authentication.token.isEmptyOrWhitespace: raise FieldDefect.newException """Please, provide a valid Personal Access Token in the configuration file!"""
  if conf.mattermost.identity.username.isEmptyOrWhitespace: raise FieldDefect.newException """Please, provide a valid Username to respond with in the configuration file!"""
  if conf.mattermost.instance.url.isEmptyOrWhitespace: raise FieldDefect.newException """Please, provide a valid Mattermost instance URL in the configuration file!"""
  if conf.mattermost.instance.contexts[0].token.isEmptyOrWhitespace: raise FieldDefect.newException """Please, provide at least one Mattermost Context with a valid Webhook Token in the configuration file!"""
  if conf.mattermost.instance.contexts[0].teamID.isEmptyOrWhitespace: raise FieldDefect.newException """Please, provide at least one Mattermost Context with a valid Team ID in the configuration file!"""
  if conf.mattermost.instance.contexts[0].categoryDisplayName.isEmptyOrWhitespace: raise FieldDefect.newException """Please, provide at least one Mattermost Context with a custom Category name in the configuration file!"""
  if conf.mattermost.instance.contexts[0].channelIDs[0].isEmptyOrWhitespace: raise FieldDefect.newException """Please, provide at least one Mattermost Context with at least one valid Channel ID in the configuration file!"""
  true

proc getConfig*(): MasterConfig = config

proc genDefaultConfig(path = configPath, name = configName): JsonNode {.discardable.} =
  let
    pathFull = path.genPathFull(name)
    conf = %* MasterConfig(
      version: appVersion,
      server: configServer,
      mattermost: configMattermost
    )
  pathFull.writeFile(conf.pretty())
  conf

proc initConf*(path = configPath, name = configName): bool =
  let
    pathFull = path.genPathFull(name)
    configAlreadyExists = pathFull.fileExists
  if configAlreadyExists:
    logger.log(lvlDebug, "Config already exists! Not generating new one.")
    config = try: pathFull.parseFile().to(MasterConfig) except CatchableError: return false
    return true
  try:
    genDefaultConfig(path, name)
    logger.log(lvlInfo, "New config file generated, as there was none! Please restart the application, after editing the configuration file to your needs.")
    quit 0
  except CatchableError:
    return false
  true