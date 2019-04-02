import packages/docutils/highlite, strutils, terminal, os, strformat
import gapbuffer, editorview, ui, cursor, unicodeext, highlight

type Mode* = enum
  normal, insert, visual, replace, ex, filer, search, quit

type Registers* = object
  yankedLines*: seq[seq[Rune]]
  yankedStr*: seq[Rune]

type StatusBarSettings* = object
  useBar*: bool
  mode*: bool
  filename*: bool
  chanedMark*: bool
  line*: bool
  column*: bool
  characterEncoding*: bool
  language*: bool
  directory*: bool

type TabBarSettings* = object
  useTab*: bool
  color*: Colorpair
  currentTabColor*: Colorpair

type EditorSettings* = object
  statusBar*: StatusBarSettings
  tabLine*: TabBarSettings
  lineNumber*: bool
  syntax*: bool
  autoCloseParen*: bool
  autoIndent*: bool 
  tabStop*: int
  characterEncoding*: CharacterEncoding # TODO: move to EditorStatus ...?
  defaultCursor*: CursorType
  normalModeCursor*: CursorType
  insertModeCursor*: CursorType

type BufferStatus* = object
  buffer*: GapBuffer[seq[Rune]]
  highlight*: Highlight
  language*: SourceLanguage
  view*: EditorView
  cursor*: CursorPosition
  isHighlight*: bool
  filename*: seq[Rune]
  openDir: seq[Rune]
  currentLine*: int
  currentColumn*: int
  expandedColumn*: int
  cmdLoop*: int
  countChange*: int
  prevMode* : Mode
  mode* : Mode

type EditorStatus* = object
  bufStatus*: seq[BufferStatus]
  currentBuffer*: int
  buffer*: GapBuffer[seq[Rune]]
  highlight*: Highlight
  language*: SourceLanguage
  searchHistory*: seq[seq[Rune]]
  view*: EditorView
  cursor*: CursorPosition
  isHighlight*: bool
  registers*: Registers
  settings*: EditorSettings
  filename*: seq[Rune]
  openDir: seq[Rune]
  currentDir: seq[Rune]
  currentLine*: int
  currentColumn*: int
  expandedColumn*: int
  prevMode* : Mode
  mode* : Mode
  cmdLoop*: int
  countChange*: int
  debugMode: int
  mainWindow*: Window
  statusWindow*: Window
  commandWindow*: Window
  tabWindow*: Window

proc initRegisters(): Registers =
  result.yankedLines = @[]
  result.yankedStr = @[]

proc initTabBarSettings*(): TabBarSettings =
  result.useTab = true
  result.color = brightWhiteDefault
  result.currentTabColor = blackPink

proc initStatusBarSettings*(): StatusBarSettings =
  result.useBar = true
  result.mode = true
  result.filename = true
  result.chanedMark = true
  result.line = true
  result.column = true
  result.characterEncoding = true
  result.language = true
  result.directory = true

proc initEditorSettings*(): EditorSettings =
  result.statusBar = initStatusBarSettings()
  result.tabLine = initTabBarSettings()
  result.lineNumber = true
  result.syntax = true
  result.autoCloseParen = true
  result.autoIndent = true
  result.tabStop = 2
  result.defaultCursor = CursorType.blockMode   # Terminal default curosr shape
  result.normalModeCursor = CursorType.blockMode
  result.insertModeCursor = CursorType.ibeamMode

import tab

proc initEditorStatus*(): EditorStatus =
  result.currentDir = getCurrentDir().toRunes
  result.language = SourceLanguage.langNone
  result.registers = initRegisters()
  result.settings = initEditorSettings()
  result.mode = Mode.normal
  result.prevMode = Mode.normal
  result.isHighlight = true

  let useStatusBar = if result.settings.statusBar.useBar: 1 else: 0
  let useTab = if result.settings.tabLine.useTab: 1 else: 0

  if result.settings.tabLine.useTab: result.tabWindow = initWindow(1, terminalWidth(), 0, 0)
  result.mainWindow = initWindow(terminalHeight() - useTab - 1, terminalWidth(), useTab, 0)
  if result.settings.statusBar.useBar: result.statusWindow = initWindow(1, terminalWidth(), terminalHeight() - useStatusBar - 1, 0, ui.ColorPair.blackPink)
  result.commandWindow = initWindow(1, terminalWidth(), terminalHeight() - 1, 0)

proc changeCurrentBuffer*(status: var EditorStatus, bufferIndex: int) =
  if status.bufStatus.len > 1 and bufferIndex < status.bufStatus.high:
    status.bufStatus[status.currentBuffer].buffer = status.buffer
    status.bufStatus[status.currentBuffer].highlight = status.highlight
    status.bufStatus[status.currentBuffer].language = status.language
    status.bufStatus[status.currentBuffer].view = status. view
    status.bufStatus[status.currentBuffer].cursor = status.cursor
    status.bufStatus[status.currentBuffer].filename = status.filename
    status.bufStatus[status.currentBuffer].openDir = status.openDir
    status.bufStatus[status.currentBuffer].currentLine = status.currentLine
    status.bufStatus[status.currentBuffer].currentColumn = status.currentColumn
    status.bufStatus[status.currentBuffer].expandedColumn = status.expandedColumn
    status.bufStatus[status.currentBuffer].cmdLoop = status.cmdLoop
    status.bufStatus[status.currentBuffer].countChange = status.countChange
    status.bufStatus[status.currentBuffer].mode = status.mode
    status.bufStatus[status.currentBuffer].prevMode = status.mode

  status.buffer = status.bufStatus[bufferIndex].buffer
  status.highlight = status.bufStatus[bufferIndex].highlight
  status.language = status.bufStatus[bufferIndex].language
  status.view = status.bufStatus[bufferIndex].view
  status.cursor = status.bufStatus[bufferIndex].cursor
  status.filename = status.bufStatus[bufferIndex].filename
  status.openDir = status.bufStatus[bufferIndex].openDir
  status.currentLine = status.bufStatus[bufferIndex].currentLine
  status.currentColumn = status.bufStatus[bufferIndex].currentColumn
  status.expandedColumn = status.bufStatus[bufferIndex].expandedColumn
  status.cmdLoop = status.bufStatus[bufferIndex].cmdLoop
  status.countChange = status.bufStatus[bufferIndex].countChange
  status.mode = status.bufStatus[bufferIndex].mode
  status.prevMode = status.bufStatus[bufferIndex].prevMode
  status.currentBuffer = bufferIndex

proc changeMode*(status: var EditorStatus, mode: Mode) =
  status.prevMode = status.mode
  status.mode = mode

proc executeOnExit*(settings: EditorSettings) =
  changeCursorType(settings.defaultCursor)

proc writeStatusBarNormalModeInfo(status: var EditorStatus) =
  status.statusWindow.append(ru" ", ui.ColorPair.blackPink)
  if status.settings.statusBar.filename: status.statusWindow.append(if status.filename.len > 0: status.filename else: ru"No name", ui.ColorPair.blackPink)
  if status.countChange > 0 and status.settings.statusBar.chanedMark: status.statusWindow.append(ru" [+]", ui.ColorPair.blackPink)

  let
    line = if status.settings.statusBar.line: fmt"{status.currentLine+1}/{status.buffer.len}" else: ""
    column = if status.settings.statusBar.column: fmt"{status.currentColumn + 1}/{status.buffer[status.currentLine].len}" else: ""
    encoding = if status.settings.statusBar.characterEncoding: $status.settings.characterEncoding else: ""
    language = if status.language == SourceLanguage.langNone: "Plain" else: sourceLanguageToStr[status.language]
    info = fmt"{line} {column} {encoding} {language} "
  status.statusWindow.write(0, terminalWidth()-info.len, info, ui.Colorpair.blackPink)

proc writeStatusBarFilerModeInfo(status: var EditorStatus) =
  if status.settings.statusBar.directory: status.statusWindow.append(ru" ", ui.ColorPair.blackPink)
  status.statusWindow.append(getCurrentDir().toRunes, ui.ColorPair.blackPink)

proc writeStatusBar*(status: var EditorStatus) =
  status.statusWindow.erase

  if status.mode == Mode.ex:
    if status.settings.statusBar.mode: status.statusWindow.write(0, 0, ru" EX ", ui.ColorPair.blackWhite)
    if status.prevMode == Mode.filer:
      writeStatusBarFilerModeInfo(status)
    else:
      writeStatusBarNormalModeInfo(status)
  elif status.mode == Mode.visual:
    if status.settings.statusBar.mode: status.statusWindow.write(0, 0, ru" VISUAL ", ui.ColorPair.blackWhite)
    writeStatusBarNormalModeInfo(status)
  elif status.mode == Mode.replace:
    if status.settings.statusBar.mode: status.statusWindow.write(0, 0, ru" REPLACE ", ui.ColorPair.blackWhite)
    writeStatusBarNormalModeInfo(status)
  elif status.mode == Mode.filer:
    if status.settings.statusBar.mode: status.statusWindow.write(0, 0, ru" FILER ", ui.ColorPair.blackWhite)
    writeStatusBarFilerModeInfo(status)
  else:
    if status.settings.statusBar.mode:
      status.statusWindow.write(0, 0,  if status.mode == Mode.normal: ru" NORMAL " else: ru" INSERT ", ui.ColorPair.blackWhite)
    writeStatusBarNormalModeInfo(status)

  status.statusWindow.refresh

proc resize*(status: var EditorStatus, height, width: int) =
  let
    adjustedHeight = max(height, 4)
    adjustedWidth = max(width, status.view.widthOfLineNum+4)
    useStatusBar = if status.settings.statusBar.useBar: 1 else: 0
    useTab = if status.settings.tabLine.useTab: 1 else: 0

  resize(status.mainWindow, adjustedHeight - useStatusBar - useTab - 1, adjustedWidth, useTab, 0)
  if status.settings.statusBar.useBar: resize(status.statusWindow, 1, adjustedWidth, adjustedHeight - 2, 0)
  if status.settings.tabLine.useTab: resize(status.tabWindow, 1, adjustedWidth, 0, 0)
  resize(status.commandWindow, 1, adjustedWidth, adjustedHeight - 1, 0)
  
  if status.mode != Mode.filer:
    status.view.resize(status.buffer, adjustedHeight - useStatusBar - 1, adjustedWidth-status.view.widthOfLineNum-1, status.view.widthOfLineNum)
    status.view.seekCursor(status.buffer, status.currentLine, status.currentColumn)

  if status.settings.statusBar.useBar: writeStatusBar(status)

  if status.settings.tabLine.useTab: writeTabLine(status)

proc erase*(status: var EditorStatus) =
  erase(status.mainWindow)
  erase(status.statusWindow)
  erase(status.commandWindow)

proc update*(status: var EditorStatus) =
  setCursor(false)
  if status.settings.statusBar.useBar: writeStatusBar(status)
  status.view.seekCursor(status.buffer, status.currentLine, status.currentColumn)
  status.view.update(status.mainWindow, status.settings.lineNumber, status.buffer, status.highlight, status.currentLine)
  status.cursor.update(status.view, status.currentLine, status.currentColumn)
  status.mainWindow.write(status.cursor.y, status.view.widthOfLineNum+status.cursor.x, "")
  status.mainWindow.refresh
  setCursor(true)

proc updateHighlight*(status: var EditorStatus)

from searchmode import searchAllOccurrence

proc updateHighlight*(status: var EditorStatus) =

  status.highlight = initHighlight($status.buffer, status.language)

  # highlight search results
  if status.isHighlight and status.searchHistory.len > 0:
    let keyword = status.searchHistory[^1]
    let allOccurrence = searchAllOccurrence(status.buffer, keyword)
    for pos in allOccurrence:
      let colorSegment = ColorSegment(firstRow: pos.line, firstColumn: pos.column, lastRow: pos.line, lastColumn: pos.column+keyword.high, color: defaultMagenta)
      status.highlight = status.highlight.overwrite(colorSegment)
