_ = require 'underscore-plus'
{ipcRenderer, remote, shell} = require 'electron'
ipcHelpers = require './ipc-helpers'
{Disposable} = require 'event-kit'
getWindowLoadSettings = require './get-window-load-settings'

module.exports =
class ApplicationDelegate
  getWindowLoadSettings: -> getWindowLoadSettings()

  open: (params) ->
    ipcRenderer.send('open', params)

  pickFolder: (callback) ->
    responseChannel = "atom-pick-folder-response"
    ipcRenderer.on responseChannel, (event, path) ->
      ipcRenderer.removeAllListeners(responseChannel)
      callback(path)
    ipcRenderer.send("pick-folder", responseChannel)

  getCurrentWindow: ->
    remote.getCurrentWindow()

  closeWindow: ->
    ipcHelpers.call('window-method', 'close')

  getTemporaryWindowState: ->
    ipcHelpers.call('get-temporary-window-state').then (stateJSON) -> JSON.parse(stateJSON)

  setTemporaryWindowState: (state) ->
    ipcHelpers.call('set-temporary-window-state', JSON.stringify(state))

  getWindowSize: ->
    [width, height] = remote.getCurrentWindow().getSize()
    {width, height}

  setWindowSize: (width, height) ->
    ipcHelpers.call('set-window-size', width, height)

  getWindowPosition: ->
    [x, y] = remote.getCurrentWindow().getPosition()
    {x, y}

  setWindowPosition: (x, y) ->
    ipcHelpers.call('set-window-position', x, y)

  centerWindow: ->
    ipcHelpers.call('center-window')

  focusWindow: ->
    ipcHelpers.call('focus-window')

  showWindow: ->
    ipcHelpers.call('show-window')

  hideWindow: ->
    ipcHelpers.call('hide-window')

  reloadWindow: ->
    ipcHelpers.call('window-method', 'reload')

  restartApplication: ->
    ipcRenderer.send("restart-application")

  minimizeWindow: ->
    ipcHelpers.call('window-method', 'minimize')

  isWindowMaximized: ->
    remote.getCurrentWindow().isMaximized()

  maximizeWindow: ->
    ipcHelpers.call('window-method', 'maximize')

  unmaximizeWindow: ->
    ipcHelpers.call('window-method', 'unmaximize')

  isWindowFullScreen: ->
    remote.getCurrentWindow().isFullScreen()

  setWindowFullScreen: (fullScreen=false) ->
    ipcHelpers.call('window-method', 'setFullScreen', fullScreen)

  onDidEnterFullScreen: (callback) ->
    ipcHelpers.on(ipcRenderer, 'did-enter-full-screen', callback)

  onDidLeaveFullScreen: (callback) ->
    ipcHelpers.on(ipcRenderer, 'did-leave-full-screen', callback)

  openWindowDevTools: ->
    # Defer DevTools interaction to the next tick, because using them during
    # event handling causes some wrong input events to be triggered on
    # `TextEditorComponent` (Ref.: https://github.com/atom/atom/issues/9697).
    new Promise(process.nextTick).then(-> ipcHelpers.call('window-method', 'openDevTools'))

  closeWindowDevTools: ->
    # Defer DevTools interaction to the next tick, because using them during
    # event handling causes some wrong input events to be triggered on
    # `TextEditorComponent` (Ref.: https://github.com/atom/atom/issues/9697).
    new Promise(process.nextTick).then(-> ipcHelpers.call('window-method', 'closeDevTools'))

  toggleWindowDevTools: ->
    # Defer DevTools interaction to the next tick, because using them during
    # event handling causes some wrong input events to be triggered on
    # `TextEditorComponent` (Ref.: https://github.com/atom/atom/issues/9697).
    new Promise(process.nextTick).then(-> ipcHelpers.call('window-method', 'toggleDevTools'))

  executeJavaScriptInWindowDevTools: (code) ->
    ipcRenderer.send("execute-javascript-in-dev-tools", code)

  setWindowDocumentEdited: (edited) ->
    ipcHelpers.call('window-method', 'setDocumentEdited', edited)

  setRepresentedFilename: (filename) ->
    ipcHelpers.call('window-method', 'setRepresentedFilename', filename)

  addRecentDocument: (filename) ->
    ipcRenderer.send("add-recent-document", filename)

  setRepresentedDirectoryPaths: (paths) ->
    ipcHelpers.call('window-method', 'setRepresentedDirectoryPaths', paths)

  setAutoHideWindowMenuBar: (autoHide) ->
    ipcHelpers.call('window-method', 'setAutoHideMenuBar', autoHide)

  setWindowMenuBarVisibility: (visible) ->
    remote.getCurrentWindow().setMenuBarVisibility(visible)

  getPrimaryDisplayWorkAreaSize: ->
    remote.screen.getPrimaryDisplay().workAreaSize

  getUserDefault: (key, type) ->
    remote.systemPreferences.getUserDefault(key, type)

  confirm: ({message, detailedMessage, buttons}) ->
    buttons ?= {}
    if _.isArray(buttons)
      buttonLabels = buttons
    else
      buttonLabels = Object.keys(buttons)

    chosen = remote.dialog.showMessageBox(remote.getCurrentWindow(), {
      type: 'info'
      message: message
      detail: detailedMessage
      buttons: buttonLabels
      normalizeAccessKeys: true
    })

    if _.isArray(buttons)
      chosen
    else
      callback = buttons[buttonLabels[chosen]]
      callback?()

  showMessageDialog: (params) ->

  showSaveDialog: (params) ->
    if typeof params is 'string'
      params = {defaultPath: params}
    @getCurrentWindow().showSaveDialog(params)

  playBeepSound: ->
    shell.beep()

  onDidOpenLocations: (callback) ->
    outerCallback = (event, message, detail) ->
      callback(detail) if message is 'open-locations'

    ipcRenderer.on('message', outerCallback)
    new Disposable ->
      ipcRenderer.removeListener('message', outerCallback)

  onUpdateAvailable: (callback) ->
    outerCallback = (event, message, detail) ->
      # TODO: Yes, this is strange that `onUpdateAvailable` is listening for
      # `did-begin-downloading-update`. We currently have no mechanism to know
      # if there is an update, so begin of downloading is a good proxy.
      callback(detail) if message is 'did-begin-downloading-update'

    ipcRenderer.on('message', outerCallback)
    new Disposable ->
      ipcRenderer.removeListener('message', outerCallback)

  onDidBeginDownloadingUpdate: (callback) ->
    @onUpdateAvailable(callback)

  onDidBeginCheckingForUpdate: (callback) ->
    outerCallback = (event, message, detail) ->
      callback(detail) if message is 'checking-for-update'

    ipcRenderer.on('message', outerCallback)
    new Disposable ->
      ipcRenderer.removeListener('message', outerCallback)

  onDidCompleteDownloadingUpdate: (callback) ->
    outerCallback = (event, message, detail) ->
      # TODO: We could rename this event to `did-complete-downloading-update`
      callback(detail) if message is 'update-available'

    ipcRenderer.on('message', outerCallback)
    new Disposable ->
      ipcRenderer.removeListener('message', outerCallback)

  onUpdateNotAvailable: (callback) ->
    outerCallback = (event, message, detail) ->
      callback(detail) if message is 'update-not-available'

    ipcRenderer.on('message', outerCallback)
    new Disposable ->
      ipcRenderer.removeListener('message', outerCallback)

  onUpdateError: (callback) ->
    outerCallback = (event, message, detail) ->
      callback(detail) if message is 'update-error'

    ipcRenderer.on('message', outerCallback)
    new Disposable ->
      ipcRenderer.removeListener('message', outerCallback)

  onApplicationMenuCommand: (callback) ->
    outerCallback = (event, args...) ->
      callback(args...)

    ipcRenderer.on('command', outerCallback)
    new Disposable ->
      ipcRenderer.removeListener('command', outerCallback)

  onContextMenuCommand: (callback) ->
    outerCallback = (event, args...) ->
      callback(args...)

    ipcRenderer.on('context-command', outerCallback)
    new Disposable ->
      ipcRenderer.removeListener('context-command', outerCallback)

  onDidRequestUnload: (callback) ->
    outerCallback = (event, message) ->
      callback(event).then (shouldUnload) ->
        ipcRenderer.send('did-prepare-to-unload', shouldUnload)

    ipcRenderer.on('prepare-to-unload', outerCallback)
    new Disposable ->
      ipcRenderer.removeListener('prepare-to-unload', outerCallback)

  onDidChangeHistoryManager: (callback) ->
    outerCallback = (event, message) ->
      callback(event)

    ipcRenderer.on('did-change-history-manager', outerCallback)
    new Disposable ->
      ipcRenderer.removeListener('did-change-history-manager', outerCallback)

  didChangeHistoryManager: ->
    ipcRenderer.send('did-change-history-manager')

  openExternal: (url) ->
    shell.openExternal(url)

  checkForUpdate: ->
    ipcRenderer.send('command', 'application:check-for-update')

  restartAndInstallUpdate: ->
    ipcRenderer.send('command', 'application:install-update')

  getAutoUpdateManagerState: ->
    ipcRenderer.sendSync('get-auto-update-manager-state')

  getAutoUpdateManagerErrorMessage: ->
    ipcRenderer.sendSync('get-auto-update-manager-error')

  emitWillSavePath: (path) ->
    ipcRenderer.sendSync('will-save-path', path)

  emitDidSavePath: (path) ->
    ipcRenderer.sendSync('did-save-path', path)

  resolveProxy: (requestId, url) ->
    ipcRenderer.send('resolve-proxy', requestId, url)

  onDidResolveProxy: (callback) ->
    outerCallback = (event, requestId, proxy) ->
      callback(requestId, proxy)

    ipcRenderer.on('did-resolve-proxy', outerCallback)
    new Disposable ->
      ipcRenderer.removeListener('did-resolve-proxy', outerCallback)
