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
  Mattermost Webhook Handler
]##

import
  mattermostwebhookhandler/[
    meta,
    configurator
  ],
  std/[
    logging,
    options,
    json,
    strformat,
    strutils,
    sequtils,
    tables
  ],
  pkg/[
    zero_functional,
    puppy, # Web Client
    mike   # Web Server
  ]

type
  WebhookFromMattermost = object
    token: string
    teamID: string
    channelID: string
    userID: string
    text: string

  WebhookFromMattermostResponse = object
    ## https://developers.mattermost.com/integrate/slash-commands/custom/#response-parameters
    text: string
    username: string ## https://docs.mattermost.com/configure/integrations-configuration-settings.html#enable-integrations-to-override-usernames
    channel_id: string
    icon_url: string
    `type`: Option[string]
    response_type: string
    skip_slack_parsing: bool
    extra_responses: Option[JsonNode]
    props: Option[JsonNode]

newConsoleLogger(defineLogLevel(), logMsgPrefix & logMsgInter & "master" & logMsgSuffix).addHandler

func first(s: openArray[MattermostInstanceContext], pred: proc(x: MattermostInstanceContext): bool {.closure.}): MattermostInstanceContext {.inline, effectsOf: pred.} =
  for i in 0..<s.len:
    if s[i].pred:
      return s[i]

func constructWebhookFromMattermost(form: StringTableRef): WebhookFromMattermost {.gcsafe.} =
  WebhookFromMattermost(
    token: form["token"],
    teamID: form["team_id"],
    channelID: form["channel_id"],
    userID: form["user_id"],
    text: form["text"].replace('+', ' '),
  )

func constructWebhookFromMattermostResponse(respUserName, text, channelID, iconURL: string): WebhookFromMattermostResponse {.gcsafe.} =
  WebhookFromMattermostResponse(
    text: text,
    username: respUserName,
    channel_id: channelID,
    icon_url: iconURL,
    `type`: string.none,
    response_type: "ephemeral",
    skip_slack_parsing: true,
    extra_responses: JsonNode.none,
    props: JsonNode.none
  )

func constructUrlUserSidebarCategory(urlBase, user_id, team_id, category_id: string): string {.gcsafe.} =
  &"{urlBase}users/{user_id}/teams/{team_id}/channels/categories/{category_id}"

func constructUrlUserSidebarCategories(urlBase, user_id, team_id: string): string {.gcsafe.} =
  &"{urlBase}users/{user_id}/teams/{team_id}/channels/categories"

func constructUrlUserChannels(urlBase, user_id, team_id: string): string {.gcsafe.} =
  &"{urlBase}users/{user_id}/teams/{team_id}/channels"

func constructUrlAddUserToChannel(urlBase, user_id, channelID: string): string {.gcsafe.} =
  &"{urlBase}channels/{channelID}/members"

func findCategoryChannels(jCategories: JsonNode): JsonNode {.gcsafe.} =
  if jCategories.isNil: raise NilAccessDefect.newException """[findCategoryChannels] jCategories is nil!"""
  let keyword = "channels"
  for jCategory in jCategories{"categories"}.getElems:
    let
      channelID = jCategory{"id"}.getStr
      channelType = jCategory{"type"}.getStr
    if channelID.startsWith(keyword) and channelType == keyword:
      return jCategory

func findCategoryByDisplayName(jCategories: JsonNode, displayName: string): JsonNode {.gcsafe.} =
  if jCategories.isNil: raise NilAccessDefect.newException """[findCategoryByDisplayName] jCategories is nil!"""
  for jCategory in jCategories{"categories"}.getElems:
    let
      channelType = jCategory{"type"}.getStr
      channelDisplayName = jCategory{"display_name"}.getStr
    if channelType == "custom" and channelDisplayName == displayName:
      jCategory["sorting"] = "manual".newJString
      return jCategory

func moveChannelsBetweenCategories(jCategoryFrom: JsonNode, jCategoryTo: JsonNode, channelIDs: openArray[string]): JsonNode {.gcsafe, used.} =
  if jCategoryFrom.isNil: raise NilAccessDefect.newException """[moveChannelsBetweenCategories] jCategoryFrom is nil!"""
  if jCategoryTo.isNil: raise NilAccessDefect.newException """[moveChannelsBetweenCategories] jCategoryTo is nil!"""
  let keyword = "channel_ids"
  jCategoryFrom[keyword] = block:
    let
      fromChannelIDs = jCategoryFrom[keyword].getElems.mapIt(it.getStr)
      fromChannelIDsClean = fromChannelIDs.filterIt(it notin channelIDs)
    %fromChannelIDsClean
  jCategoryTo[keyword] = %(jCategoryTo[keyword].getElems.mapIt(it.getStr) & @channelIDs)
  % [
    jCategoryTo,
    jCategoryFrom
  ]

func moveChannelsBetweenCategoriesWithReplace(jCategoryFrom: JsonNode, jCategoryTo: JsonNode, channelIDs: openArray[string]): JsonNode {.gcsafe.} =
  if jCategoryFrom.isNil: raise NilAccessDefect.newException """[moveChannelsBetweenCategoriesWithReplace] jCategoryFrom is nil!"""
  if jCategoryTo.isNil: raise NilAccessDefect.newException """[moveChannelsBetweenCategoriesWithReplace] jCategoryTo is nil!"""
  let keyword = "channel_ids"
  jCategoryFrom[keyword] = block:
    let
      fromChannelIDs = jCategoryFrom[keyword].getElems.mapIt(it.getStr)
      fromChannelIDsClean = fromChannelIDs.filterIt(it notin channelIDs)
    %fromChannelIDsClean
  jCategoryTo[keyword] = % channelIDs
  % [
    jCategoryTo,
    jCategoryFrom
  ]

proc constructRequest(bearerToken, url, verb, body: string = ""): puppy.Request {.gcsafe.} =
  puppy.Request(
    url: parseUrl(url),
    headers: @[
      Header(key: headerKeyAuth, value: bearerToken),
      Header(key: headerKeyContentType, value: headerValueContentType),
      Header(key: headerKeyAccept, value: headerValueContentType)
    ],
    verb: verb,
    body: body
  )

proc retrieveResponse(req: puppy.Request): JsonNode {.gcsafe.} =
  let
    resp = req.fetch()
    jResp = try: resp.body.parseJson except CatchableError: raise Exception.newException(resp.body)
  try: jResp except CatchableError: raise Exception.newException(resp.body)

proc getUserChannels(urlBase, bearerToken, userID, teamID: string): JsonNode {.gcsafe.} =
  ## https://api.mattermost.com/#tag/channels/operation/GetChannelsForTeamForUser
  constructRequest(bearerToken, constructUrlUserChannels(urlBase, userID, teamID), "GET").retrieveResponse()

proc addUserToChannel(urlBase, bearerToken, userID, channelID: string): JsonNode {.gcsafe.} =
  ## https://api.mattermost.com/#tag/channels/operation/AddChannelMember
  constructRequest(bearerToken, constructUrlAddUserToChannel(urlBase, userID, channelID), "POST", $ % { "user_id": userID }.toTable).retrieveResponse()

proc getUsersSidebarCategories(urlBase, bearerToken, userID, teamID: string): JsonNode {.gcsafe.} =
  ## https://api.mattermost.com/#tag/channels/operation/GetSidebarCategoriesForTeamForUser
  constructRequest(bearerToken, constructUrlUserSidebarCategories(urlBase, userID, teamID), "GET").retrieveResponse()

proc createUsersSidebarCategory(urlBase, bearerToken, userID, teamID: string, jBody: JsonNode): JsonNode {.gcsafe.} =
  ## https://api.mattermost.com/#tag/channels/operation/CreateSidebarCategoryForTeamForUser
  constructRequest(bearerToken, constructUrlUserSidebarCategories(urlBase, userID, teamID), "POST", $jBody).retrieveResponse()

proc updateUsersSidebarCategories(urlBase, bearerToken, userID, teamID: string, jBody: JsonNode): JsonNode {.gcsafe.} =
  ## https://api.mattermost.com/#tag/channels/operation/UpdateSidebarCategoriesForTeamForUser
  constructRequest(bearerToken, constructUrlUserSidebarCategories(urlBase, userID, teamID), "PUT", $jBody).retrieveResponse()

proc updateUsersSidebarCategory(urlBase, bearerToken, userID, teamID, categoryID: string, jBody: JsonNode): JsonNode {.gcsafe, used.} =
  ## https://api.mattermost.com/#tag/channels/operation/UpdateSidebarCategoryForTeamForUser
  constructRequest(bearerToken, constructUrlUserSidebarCategory(urlBase, userID, teamID, categoryID), "PUT", $jBody).retrieveResponse()

proc setupChannels(urlBase, bearerToken, userID, teamID, categoryDisplayName: string, channelIDs: openArray[string]) {.gcsafe.} =
  debug "addUserToChannel: " & pretty %channelIDs
    .filterIt(it notin getUserChannels(urlBase, bearerToken, userID, teamID).getElems.mapIt(it.getStr))
    .mapIt(addUserToChannel(urlBase, bearerToken, userID, it))
  let
    sidebarCategoriesOriginal = getUsersSidebarCategories(urlBase, bearerToken, userID, teamID)
    sidebarCategories = block:
      if findCategoryByDisplayName(sidebarCategoriesOriginal, categoryDisplayName) == nil:
        discard createUsersSidebarCategory(urlBase, bearerToken, userID, teamID, 
          % {
            "user_id": userID,
            "team_id": teamID,
            "display_name": categoryDisplayName,
            "type": "custom",
            "sorting": "manual"
          }.toTable
        )
        getUsersSidebarCategories(urlBase, bearerToken, userID, teamID)
      else: sidebarCategoriesOriginal
    categoryChannels = findCategoryChannels(sidebarCategories)
    categorySelected = findCategoryByDisplayName(sidebarCategories, categoryDisplayName)
    categoriesUpdated = moveChannelsBetweenCategoriesWithReplace(categoryChannels, categorySelected, channelIDs)
  debug "updateUsersSidebarCategories: " & pretty updateUsersSidebarCategories(urlBase, bearerToken, userID, teamID, categoriesUpdated)

when isMainModule:
  if not initConf():
    fatal """Unable to parse configuration file! Please delete & regenerate it by restarting this application."""
    quit 1
  config.validateOrExcept()

  "/joincat/add" -> post:
    {.cast(gcsafe).}:
      try:
        let
          data = ctx.parseForm.constructWebhookFromMattermost
          mContexts = config.mattermost.instance.contexts
          mBearerToken = "Bearer " & config.mattermost.identity.authentication.token
          mUsername = config.mattermost.identity.username
          mIconURL = config.mattermost.identity.iconURL
          context = mContexts.first do (x: MattermostInstanceContext) -> bool:
            x.categoryDisplayName.toLowerAscii == data.text.toLowerAscii
        if not mContexts.anyIt(it.token == data.token): ctx.send("Unauthorised", Http401)
        elif context.categoryDisplayName.toLowerAscii == data.text.toLowerAscii:
          let resp = constructWebhookFromMattermostResponse(
            mUsername,
            &"""Added to Category "{data.text}"!""",
            data.channelID,
            mIconURL
          )
          setupChannels(config.mattermost.instance.url, mBearerToken, data.userID, context.teamID, context.categoryDisplayName, context.channelIDs)
          ctx.send(%resp, Http200)
        else:
          case data.text.toLowerAscii
            of "help":
              let resp = constructWebhookFromMattermostResponse(
                mUsername,
                &"""Following Categories are available: """ & lineEnd.repeat(2) & mContexts.mapIt(it.categoryDisplayName).join($lineEnd),
                data.channelID,
                mIconURL
              )
              ctx.send(%resp, Http200)
            of string.default:
              let resp = constructWebhookFromMattermostResponse(
                mUsername,
                &"""Do you want to join a specific Category? If yes, then send the following message: /joincat <Category Name>{lineEnd}To get a list of all available Categories, send the following message: /joincat help""",
                data.channelID,
                mIconURL
              )
              ctx.send(%resp, Http200)
            else:
              let resp = constructWebhookFromMattermostResponse(
                mUsername,
                &"""The Category "{data.text}" is unavailable. To get a list of all available Categories, send the following message: /joincat help""",
                data.channelID,
                mIconURL
              )
              ctx.send(%resp, Http200)
      except CatchableError:
        error """["/joincat/add" -> post] Error occurred: """ & getCurrentExceptionMsg()
        ctx.send("Error occurred: " & getCurrentExceptionMsg(), Http500)

  run(config.server.port)