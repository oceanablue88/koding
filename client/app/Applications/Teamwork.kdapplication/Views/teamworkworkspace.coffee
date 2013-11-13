class TeamworkWorkspace extends CollaborativeWorkspace

  constructor: (options = {}, data) ->

    super options, data

    {environment, environmentManifest} = @getOptions()
    @avatars = {}

    @on "PanelCreated", (panel) =>
      @createRunButton panel  if environment

    @on "WorkspaceSyncedWithRemote", =>
      if environment and @amIHost()
        @workspaceRef.child("environment").set environment

        if environmentManifest
          @workspaceRef.child("environmentManifest").set environmentManifest

      @hidePlaygroundsButton()  unless @amIHost()

      @workspaceRef.child("users").on "child_added", (snapshot) =>
        joinedUser = snapshot.name()
        return if not joinedUser or joinedUser is KD.nick()
        @hidePlaygroundsButton()

      if @amIHost()
        # currently only for host.
        # bc of clients need to know host's vmName and active pane's file data etc.
        activePanel    = @getActivePanel()
        {previewPane}  = activePanel.paneLauncher
        {viewerHeader} = previewPane.previewer
        viewerHeader.addSubView new KDButtonView
          cssClass : "clean-gray tw-previewer-button"
          title    : "View active file"
          callback : =>
            @previewFile()

        viewerHeader.addSubView @autoRefreshSwitch = new KDOnOffSwitch
          defaultValue : off
          cssClass     : "tw-live-update"
          title        : "Auto Refresh: "
          size         : "tiny"
          tooltip      :
            title      : "If it's on, preview will be refreshed when you save a file."
            placement  : "bottom"

        activePanel.getPaneByName("editor").on "EditorDidSave", =>
          @refreshPreviewPane previewPane  if @autoRefreshSwitch.getValue()

      @getActivePanel().header.addSubView @avatarsView = new KDCustomHTMLView
        cssClass : "tw-user-avatars"

    @on "WorkspaceUsersFetched", =>
      @workspaceRef.child("users").once "value", (snapshot) =>
        userStatus = snapshot.val()
        return unless userStatus
        @manageUserAvatars userStatus

  displayBroadcastMessage: (options) ->
    super options

    if options.origin is "users"
      KD.utils.wait 500, => # prevent double triggered firebase event.
        @fetchUsers()

  createLoader: ->
    @container.addSubView @loader = new KDCustomHTMLView
      cssClass   : "teamwork-loader"
      tagName    : "img"
      attributes :
        src      : "#{KD.apiUri}/images/teamwork/loading.gif"

  startNewSession: (options) ->
    KD.mixpanel "User Started Teamwork session"

    @destroySubViews()
    unless options
      options = @getOptions()
      delete options.sessionKey

    workspaceClass          = @getEnvironmentClass options.environment
    teamwork                = new workspaceClass options
    @getDelegate().teamwork = teamwork
    @addSubView teamwork

  joinSession: (newOptions) ->
    sessionKey              = newOptions.sessionKey.trim()
    options                 = @getOptions()
    options.sessionKey      = sessionKey
    options.joinedASession  = yes
    @destroySubViews()

    @forceDisconnect()
    @firepadRef.child(sessionKey).once "value", (snapshot) =>
      value = snapshot.val()
      {environment, environmentManifest} = value  if value

      teamworkClass     = TeamworkWorkspace
      teamworkOptions   = options

      if environment
        teamworkClass   = @getEnvironmentClass environment

      if environmentManifest
        teamworkOptions = @getDelegate().mergeEnvironmentOptions environmentManifest

      teamworkOptions.sessionKey = newOptions.sessionKey

      teamwork                   = new teamworkClass teamworkOptions
      @getDelegate().teamwork    = teamwork
      @addSubView teamwork

  refreshPreviewPane: (previewPane) ->
    # emitting ViewerRefreshed event will trigger refreshing the preview via Firebase.
    previewPane.previewer.emit "ViewerRefreshed"

  createRunButton: (panel) ->
    # panel.headerButtons.Environments.hide()
    panel.header.addSubView new KDButtonView
      title      : "Run"
      callback   : => @handleRun panel

  getEnvironmentClass: (environment) ->
    switch environment
      when "Facebook" then FacebookTeamwork
      when "GoLang"   then GoLangTeamwork
      else TeamworkWorkspace

  handleRun: (panel) ->
    console.warn "You should override this method."

  hidePlaygroundsButton: ->
    @getActivePanel().headerButtons.Playgrounds?.hide()

  showHintModal: ->
    if @markdownContent
      @getDelegate().showMarkdownModal()
    else
      Panel::showHintModal.call @getActivePanel()

  previewFile: ->
    activePanel     = @getActivePanel()
    editor          = activePanel.getPaneByName "editor"
    file            = editor.getActivePaneFileData()
    path            = FSHelper.plainPath file.path
    error           = "File must be under Web folder"
    isLocal         = path.indexOf("localfile") is 0
    isNotPublic     = not FSHelper.isPublicPath path
    {previewPane}   = activePanel.paneLauncher
    {defaultVmName} = KD.getSingleton "vmController"

    return if isLocal or isNotPublic
      error         = "This file cannot be previewed" if isLocal
      new KDNotificationView
        title       : error
        cssClass    : "error"
        type        : "mini"
        duration    : 2500
        container   : previewPane

    url = path.replace "/home/#{@getHost()}/Web", defaultVmName
    previewPane.openUrl url

  manageUserAvatars: (userStatus) ->
    for own nickname, status of userStatus
      if status is "online"
        unless @avatars[nickname]
          @createUserAvatar @users[nickname]
      else
        if @avatars[nickname]
          @removeUserAvatar nickname

  createUserAvatar: (jAccount) ->
    return unless jAccount

    userNickname = jAccount.profile.nickname
    return if userNickname is KD.nick()

    tooltipTitle = userNickname
    avatarView   = new AvatarStaticView
      size       :
        width    : 25
        height   : 25
      tooltip    :
        title    : tooltipTitle
    , jAccount

    @avatars[userNickname] = avatarView
    @avatarsView.addSubView avatarView
    avatarView.bindTransitionEnd()

  removeUserAvatar: (nickname) ->
    avatarView = @avatars[nickname]
    avatarView.setClass "fade-out"
    avatarView.once "transitionend", =>
      avatarView.destroy()
      delete @avatars[nickname]
