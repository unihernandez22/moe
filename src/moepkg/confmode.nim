import terminal, sequtils
import gapbuffer, editorstatus, editorview, ui, unicodeext, normalmode, highlight

type SettingItems = enum
  editorColorTheme

proc cursorTypeToRune(cursorType: CursorType): seq[Rune] =
  case cursorType
  of CursorType.blockMode: return ru"block"
  of CursorType.ibeamMode: return ru"ibeam"

proc currentThemeRune(theme: ColorTheme): seq[Rune] =
  case theme
  of ColorTheme.dark: return ru"dark"
  of ColorTheme.light: return ru"light"
  of ColorTheme.vivid: return ru"vivid"
  of ColorTheme.config: return ru"config"

proc boolToRune(boolean: bool): seq[Rune] =
  if boolean: return ru"on" else: return ru"off"

proc intToRune(num: int): seq[Rune] = return ($num).toRunes

proc setConfigBuffer(bufStatus: var BufferStatus, settings: EditorSettings) =
  bufStatus.buffer[0] = ru"-- Basic settings --"
  bufStatus.buffer.add(ru"editorColorTheme ")
  bufStatus.buffer[bufStatus.buffer.high].insert(settings.editorColorTheme.currentThemeRune, bufStatus.buffer[bufStatus.buffer.high].len)
  bufStatus.buffer.add(ru"lineNumber ")
  bufStatus.buffer[bufStatus.buffer.high].insert(settings.lineNumber.boolToRune, bufStatus.buffer[bufStatus.buffer.high].len)
  bufStatus.buffer.add(ru"currentLineNumber ")
  bufStatus.buffer[bufStatus.buffer.high].insert(settings.currentLineNumber.boolToRune, bufStatus.buffer[bufStatus.buffer.high].len)
  bufStatus.buffer.add(ru"cursorLine ")
  bufStatus.buffer[bufStatus.buffer.high].insert(settings.cursorLine.boolToRune, bufStatus.buffer[bufStatus.buffer.high].len)
  bufStatus.buffer.add(ru"syntax ")
  bufStatus.buffer[bufStatus.buffer.high].insert(settings.syntax.boolToRune, bufStatus.buffer[bufStatus.buffer.high].len)
  bufStatus.buffer.add(ru"autoCloseParen ")
  bufStatus.buffer[bufStatus.buffer.high].insert(settings.autoCloseParen.boolToRune, bufStatus.buffer[bufStatus.buffer.high].len)
  bufStatus.buffer.add(ru"autoIndent ")
  bufStatus.buffer[bufStatus.buffer.high].insert(settings.autoIndent.boolToRune, bufStatus.buffer[bufStatus.buffer.high].len)
  bufStatus.buffer.add(ru"tabStop ")
  bufStatus.buffer[bufStatus.buffer.high].insert(settings.tabStop.intToRune, bufStatus.buffer[bufStatus.buffer.high].len)
  bufStatus.buffer.add(ru"defaultCursor ")
  bufStatus.buffer[bufStatus.buffer.high].insert(settings.defaultCursor.cursorTypeToRune, bufStatus.buffer[bufStatus.buffer.high].len)
  bufStatus.buffer.add(ru"normalModeCursor ")
  bufStatus.buffer[bufStatus.buffer.high].insert(settings.normalModeCursor.cursorTypeToRune, bufStatus.buffer[bufStatus.buffer.high].len)
  bufStatus.buffer.add(ru"insertModeCursor ")
  bufStatus.buffer[bufStatus.buffer.high].insert(settings.insertModeCursor.cursorTypeToRune, bufStatus.buffer[bufStatus.buffer.high].len)
  bufStatus.buffer.add(ru"")

  bufStatus.buffer.add(ru"-- Tab line settings --")
  bufStatus.buffer.add(ru"Use Tab bar ")
  bufStatus.buffer[bufStatus.buffer.high].insert(settings.tabLine.useTab.boolToRune, bufStatus.buffer[bufStatus.buffer.high].len)
  bufStatus.buffer.add(ru"")

  bufStatus.buffer.add(ru"-- Status bar settings --")
  bufStatus.buffer.add(ru"useBar ")
  bufStatus.buffer[bufStatus.buffer.high].insert(settings.statusBar.useBar.boolToRune, bufStatus.buffer[bufStatus.buffer.high].len)
  bufStatus.buffer.add(ru"mode ")
  bufStatus.buffer[bufStatus.buffer.high].insert(settings.statusBar.mode.boolToRune, bufStatus.buffer[bufStatus.buffer.high].len)
  bufStatus.buffer.add(ru"filename ")
  bufStatus.buffer[bufStatus.buffer.high].insert(settings.statusBar.filename.boolToRune, bufStatus.buffer[bufStatus.buffer.high].len)
  bufStatus.buffer.add(ru"chanedMark ")
  bufStatus.buffer[bufStatus.buffer.high].insert(settings.statusBar.chanedMark.boolToRune, bufStatus.buffer[bufStatus.buffer.high].len)
  bufStatus.buffer.add(ru"line ")
  bufStatus.buffer[bufStatus.buffer.high].insert(settings.statusBar.line.boolToRune, bufStatus.buffer[bufStatus.buffer.high].len)
  bufStatus.buffer.add(ru"column ")
  bufStatus.buffer[bufStatus.buffer.high].insert(settings.statusBar.column.boolToRune, bufStatus.buffer[bufStatus.buffer.high].len)
  bufStatus.buffer.add(ru"language ")
  bufStatus.buffer[bufStatus.buffer.high].insert(settings.statusBar.language.boolToRune, bufStatus.buffer[bufStatus.buffer.high].len)
  bufStatus.buffer.add(ru"directory ")
  bufStatus.buffer[bufStatus.buffer.high].insert(settings.statusBar.directory.boolToRune, bufStatus.buffer[bufStatus.buffer.high].len)

proc initHighlight(bufStatus: var BufferStatus): Highlight =
  for i in 0 ..< bufStatus.buffer.len:
    let color = if i == bufStatus.currentLine: EditorColorPair.visualMode else: EditorColorPair.defaultChar
    result.colorSegments.add(ColorSegment(firstRow: i, firstColumn: 0, lastRow: i, lastColumn: bufStatus.buffer[i].len, color: color))

proc exitConfigMode(status: var Editorstatus) =
  setCursor(true)

proc configurationMode*(status: var EditorStatus) =
  status.resize(terminalHeight(), terminalWidth())
  let
    useStatusBar = if status.settings.statusBar.useBar: 1 else: 0
    useTab = if status.settings.tabLine.useTab: 1 else: 0
    currentBuf = status.currentBuffer

  status.bufStatus[currentBuf].setConfigBuffer(status.settings)
  status.bufStatus[currentBuf].view = initEditorView(status.bufStatus[currentBuf].buffer, terminalHeight() - useStatusBar - useTab - 1, terminalWidth())

  while status.bufStatus[currentBuf].mode == Mode.conf:
    status.bufStatus[currentBuf].highlight = status.bufStatus[currentBuf].initHighlight
    status.update
    setCursor(false)
    let key = getKey(status.mainWindowInfo[status.currentMainWindow].window)

    if isResizekey(key):
      status.resize(terminalHeight(), terminalWidth())
    elif key == ord(':'):
      status.changeMode(Mode.ex)

    elif isControlK(key):
      moveNextWindow(status)
    elif isControlJ(key):
      movePrevWindow(status)

    elif isControlV(key):
      status.changeMode(Mode.visualBlock)
    elif key == ord('k') or isUpKey(key):
      keyUp(status.bufStatus[currentBuf])
    elif key == ord('j') or isDownKey(key) or isEnterKey(key):
      keyDown(status.bufStatus[currentBuf])
    else:
      discard

  status.exitConfigMode
