#Region
#AutoIt3Wrapper_UseX64=y
#EndRegion

#include "Libs\autoit-opencv-com\udf\opencv_udf_utils.au3"
#include "Libs\StoColor.au3"
#include <GDIPlus.au3>
#include <GUIConstantsEx.au3>
#include <FontConstants.au3>
#include <ScreenCapture.au3>
#include <StaticConstants.au3>
#include <WinAPI.au3>
#include <File.au3>


; client size: 1280x720
; window size: 1282x759
; gui size: 1298x767


DllCall("user32.dll", "bool", "SetProcessDPIAware")
Local $arrDPIs = DllCall("user32.dll", "uint", "GetDpiForSystem") ; Windows 10+
Local $iWinScale = $arrDPIs[0] / 96 ; DPI 96 is 100%

_OpenCV_Open("Libs\opencv\build\x64\vc16\bin\opencv_world4120.dll", "Libs\autoit-opencv-com\autoit_opencv_com4120.dll")
_GDIPlus_Startup()
OnAutoItExitRegister("_OnAutoItExit")

Global $sGameWinTitle   = "マブラヴ"
Global $sGameResDir     = @ScriptDir & "\Res\MuvLuv\"
Global $iLoopTimer      = 500

Global $bMazeFarmingOn  = True
Global $bMazeCraftSkip  = True

Global $bRunning        = False
Global $bPausing        = False
Global $iPausingTimer   = 0
Global $iPausingMax     = $iLoopTimer
Global $bSingleRunning  = False

; 自定义点击目录 Res\MuvLuv\sto：图片出现就点一次
Global $aStoImgs = 0
Global $iStoLastIndex = -1
Global $hStoLastClick = 0

; 剧情选项条（半透明粉色横条）检测
Global $hChoiceLastClick = 0

; 让点击不抢前台：给游戏窗口临时加 WS_EX_NOACTIVATE | WS_EX_APPWINDOW
; 需要助手以管理员权限运行，否则 SetWindowLongPtr 会被拒绝（Access Denied）
Global $bUseNoActivate = True
Global $bNoActivateApplied = False
Global $iGameExStyleOrig = 0

Global $cv = _OpenCV_get()
If Not IsObj($cv) Then
    MsgBox(16, "错误", "OpenCV COM 对象获取失败。")
    Exit
EndIf


; The theme
Global $bIsDark = False
Global $c_Dark_BG       = 0x1F1F1F, $c_Dark_Text      = 0xF0F0F0
Global $c_Light_BG      = 0xF3F3F3, $c_Light_Text     = 0x000000
Global $c_Status_BG     = 0x000000, $c_Status_Text    = 0xFFFFFF
Global $aThemeControls[20], $iCtrlCount = 0

Func _RegisterThemeCtrl($iCtrlID)
    $aThemeControls[$iCtrlCount] = $iCtrlID
    $iCtrlCount += 1
EndFunc

; The font and size.
Local $sFont = "Segoe UI"
Local $iFontSize = 10
Local $iGUIWidth = Int(255 * $iWinScale), $iGUIHeight = Int(255 * $iWinScale)

Global $hGUI = GUICreate("MuvLuv 助手", $iGUIWidth, $iGUIHeight)
GUISetFont($iFontSize, $FW_NORMAL, 0, $sFont)

; [ Normal, Hover, Clicked ] Colors
Global $aBtnColor_Dark[3]  = [0x333333, 0x444444, 0x222222]
Global $aBtnColor_Light[3] = [0xE1E1E1, 0xD0D0D0, 0xB8B8B8]
Global $bBtnHovered = False
Local $iBtnW = Int(100 * $iWinScale), $iBtnH = Int(40 * $iWinScale)
;Local $btnStart = GUICtrlCreateButton("Start", Int(($iGUIWidth - $iBtnW) / 2), Int(10 * $iWinScale), $iBtnW, $iBtnH)
Global $btnStart = GUICtrlCreateLabel("开始", Int(($iGUIWidth - $iBtnW) / 2), Int(10 * $iWinScale), $iBtnW, $iBtnH, BitOR($SS_CENTER, $SS_CENTERIMAGE))
GUICtrlSetFont($btnStart, 11, $FW_BOLD, 0, $sFont)

Local $iPadTop = 3
Local $iStatusW = Int(150 * $iWinScale), $iStatusH = Int(25 * $iWinScale) - $iPadTop
Local $iStatusX = Int(($iGUIWidth - $iStatusW) / 2)
Local $iStatusY = Int(10 * $iWinScale) + $iBtnH + Int(10 * $iWinScale) ; 合并 Gap 运算

Local $lblStatusPad = GUICtrlCreateLabel("", $iStatusX, $iStatusY, $iStatusW, $iPadTop)
GUICtrlSetBkColor($lblStatusPad, 0x000000)
; Initial string length needs attention.
Global $lblStatus = GUICtrlCreateLabel("状态：空闲", $iStatusX, $iStatusY + $iPadTop, $iStatusW, $iStatusH, $SS_CENTER)
GUICtrlSetBkColor($lblStatus, 0x000000)
GUICtrlSetColor($lblStatus, 0xFFFFFF)

Local $iTipsW = Int(235 * $iWinScale), $iTipsH = Int(20 * $iWinScale)
Local $iTipsX = Int(($iGUIWidth - $iTipsW) / 2)
Local $iTipsY = $iStatusY + $iStatusH + Int(10 * $iWinScale)
Local $iTipsGap = $iTipsH + Int(5 * $iWinScale)

Local $aTipsText[3] = [ _
    "★ 启/停 快捷键 F9", _
    "★ 游戏窗口 1280*720", _
    "★ 自动点击各种战斗、剧情等" _
]
For $i = 0 To 2
    Local $hIdTip = GUICtrlCreateLabel($aTipsText[$i], $iTipsX, $iTipsY + ($i * $iTipsGap), $iTipsW, $iTipsH)
    _RegisterThemeCtrl($hIdTip)
Next

Local $iChkBoxW = Int(18 * $iWinScale)
Local $iChkBoxP = Int(1 * $iWinScale)

Local $iChkMazeW = Int(150 * $iWinScale), $iChkMazeH = Int(20 * $iWinScale)
Local $iChkMazeY = $iGUIHeight - Int(25 * $iWinScale)
Local $iChkMazeX = Int(($iGUIWidth - $iChkMazeW) / 2)
Local $chkMazeFarming = GUICtrlCreateCheckbox("", $iChkMazeX, $iChkMazeY, $iChkBoxW, $iChkMazeH)
Local $chkMazeFarmingText = GUICtrlCreateLabel("刷迷宫", $iChkMazeX + $iChkBoxW, $iChkMazeY + $iChkBoxP, $iChkMazeW - $iChkBoxW, $iChkMazeH)
GUICtrlSetState($chkMazeFarming, $GUI_CHECKED)
_RegisterThemeCtrl($chkMazeFarmingText)

Local $iChkCraftW = Int(150 * $iWinScale), $iChkCraftH = Int(20 * $iWinScale)
Local $iChkCraftY = $iChkMazeY - Int(25 * $iWinScale)
Local $iChkCraftX = Int(($iGUIWidth - $iChkCraftW) / 2)
Local $chkCraftSkip = GUICtrlCreateCheckbox("", $iChkCraftX, $iChkCraftY, $iChkBoxW, $iChkCraftH)
Local $chkCraftSkipText = GUICtrlCreateLabel("迷宫跳过", $iChkCraftX + $iChkBoxW, $iChkCraftY + $iChkBoxP, $iChkCraftW - $iChkBoxW, $iChkCraftH)
GUICtrlSetState($chkCraftSkip, $GUI_CHECKED)
_RegisterThemeCtrl($chkCraftSkipText)

; Listen to the theme change
GUIRegisterMsg(0x001A, "WM_SETTINGCHANGE")
_ApplySystemTheme($hGUI)

Func WM_SETTINGCHANGE($hWnd, $iMsg, $wParam, $lParam)
    _ApplySystemTheme($hGUI)
    Return $GUI_RUNDEFMSG
EndFunc

Func _ApplySystemTheme($hWnd)
    Local $iReg = RegRead("HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize", "AppsUseLightTheme")

    If @error Then Return

    Local $bCurrentIsDark = ($iReg == 0)
    $bIsDark = $bCurrentIsDark

    Local $cBkColor = $bIsDark ? $c_Dark_BG : $c_Light_BG
    Local $cTextColor = $bIsDark ? $c_Dark_Text : $c_Light_Text

    GUISetBkColor($cBkColor, $hWnd)

    ; Button theme
    Local $aCurrentBtnSrc = $bIsDark ? $aBtnColor_Dark : $aBtnColor_Light
    GUICtrlSetBkColor($btnStart, $aCurrentBtnSrc[0])
    GUICtrlSetColor($btnStart, $bIsDark ? 0xFFFFFF : 0x000000)

    ; Ctrl theme
    For $i = 0 To $iCtrlCount - 1
        Local $hIdCtrl = $aThemeControls[$i]
        GUICtrlSetColor($hIdCtrl, $cTextColor)
        GUICtrlSetBkColor($hIdCtrl, $cBkColor)
    Next

    Local $pDark = DllStructCreate("int")
    DllStructSetData($pDark, 1, $bIsDark ? 1 : 0)
    DllCall("dwmapi.dll", "long", "DwmSetWindowAttribute", "hwnd", $hWnd, "dword", 20, "ptr", DllStructGetPtr($pDark), "dword", 4)
EndFunc

$iBtnLeft   = -1
$iBtnTop    = -1
$iBtnRight  = -1
$iBtnBottom = -1

; GUI Start
GUISetState(@SW_SHOW)
HotKeySet("{F9}", "ActionToggle")
While True
    Local $aMousePos = GUIGetCursorInfo($hGUI)
    If Not @error Then
        Local $iMX = $aMousePos[0]
        Local $iMY = $aMousePos[1]
        Local $aColors = $bIsDark ? $aBtnColor_Dark : $aBtnColor_Light

        If $iBtnLeft = -1 Then
            Local $aBtnPos = ControlGetPos($hGUI, "", $btnStart)
            $iBtnLeft   = $aBtnPos[0]
            $iBtnTop    = $aBtnPos[1]
            $iBtnRight  = $aBtnPos[0] + $aBtnPos[2]
            $iBtnBottom = $aBtnPos[1] + $aBtnPos[3]
        EndIf

        If ($iMX >= $iBtnLeft And $iMX <= $iBtnRight) And ($iMY >= $iBtnTop And $iMY <= $iBtnBottom) Then
            If Not $bBtnHovered Then
                $bBtnHovered = True
                GUICtrlSetBkColor($btnStart, $aColors[1])
            EndIf
        Else
            If $bBtnHovered Then
                $bBtnHovered = False
                GUICtrlSetBkColor($btnStart, $aColors[0])
            EndIf
        EndIf
    EndIf

    Switch GUIGetMsg()
        ; When click close button
        Case $GUI_EVENT_CLOSE
            Exit
        Case $btnStart
            Local $aColors = $bIsDark ? $aBtnColor_Dark : $aBtnColor_Light
            GUICtrlSetBkColor($btnStart, $aColors[2])
            Sleep(80)
            GUICtrlSetBkColor($btnStart, $aColors[1])
            If $bRunning Then
                ActionStop()
            Else
                ActionStart()
            EndIf

        ; The check boxes
        Case $chkMazeFarming
            $bMazeFarmingOn = (GUICtrlRead($chkMazeFarming) = $GUI_CHECKED)

        Case $chkCraftSkip
            $bMazeCraftSkip = (GUICtrlRead($chkCraftSkip) = $GUI_CHECKED)
    EndSwitch
WEnd

; Functions
Func ResetPausingState()
    $bPausing = False
    $iPausingTimer = 0
    $iPausingMax = 0
EndFunc

Func ActionStart()
    GUICtrlSetData($btnStart, "停止")
    GUICtrlSetData($lblStatus, "状态：运行中")
    GUICtrlSetColor($lblStatus, 0x00FF00)
    $bRunning = True
    _GuiSetNoActivate(True)
    _GameApplyNoActivate()
    AdlibRegister("AutoClick", $iLoopTimer)
EndFunc

Func ActionStop()
    GUICtrlSetData($btnStart, "开始")
    GUICtrlSetData($lblStatus, "状态：空闲")
    GUICtrlSetColor($lblStatus, 0xFFFFFF)
    $bRunning = False
    ResetPausingState()
    AdlibUnRegister("AutoClick")
    _GameRestoreNoActivate()
    _GuiSetNoActivate(False)
EndFunc

Func ActionToggle()
    If $bRunning Then
        ActionStop()
    Else
        ActionStart()
    EndIf
EndFunc

Func ActionContinue()
    If Not $bRunning Then Return
    GUICtrlSetData($lblStatus, "状态：运行中")
    GUICtrlSetColor($lblStatus, 0x00FF00)
    ResetPausingState()
EndFunc

Func ActionPause($iMilliSeconds)
    GUICtrlSetData($lblStatus, "状态：等待中")
    GUICtrlSetColor($lblStatus, 0xFFD966)
    $iPausingTimer = 0
    $iPausingMax = $iMilliSeconds
    $bPausing = True
EndFunc

Func _WinAPI_GetClientPos($hWnd)
    If Not IsHWnd($hWnd) Then $hWnd = WinGetHandle($hWnd)
    If Not $hWnd Then Return False

    Local $tRect = _WinAPI_GetClientRect($hWnd)
    If @error Then Return False

    Local $tPoint = DllStructCreate("long X;long Y")
    DllStructSetData($tPoint, "X", 0)
    DllStructSetData($tPoint, "Y", 0)
    _WinAPI_ClientToScreen($hWnd, DllStructGetPtr($tPoint))
    If @error Then Return False

    Local $aPos[4]
    $aPos[0] = DllStructGetData($tPoint, "X") ; Left
    $aPos[1] = DllStructGetData($tPoint, "Y") ; Top
    $aPos[2] = DllStructGetData($tRect, "Right") ; Width
    $aPos[3] = DllStructGetData($tRect, "Bottom") ; Height
    Return $aPos
EndFunc

; Image Search Functions.
; #FUNCTION# ==========================================================================================================
; Name ..........: ImageSearch
; Description ...: Find image in the game client or subarea relative to the game client.
; Syntax ........: ImageSearch($sImageFile[, $fThreshold = 0.8[, $arrSubArea = Default[, $iBaseClientHeight = 720]]])
; Parameters ....: $sImageFile      - Image path.
;                  $fThreshold      - [optional] The threshold. Default is 0.8
;                  $arrSubArea      - [optional] The sub area [x, y, w, h] relative to the game client. Default is the
;                                                whole game client.
;                  $iBaseClientHeight - [optional] The base game client height where you capture the template images. So
;                                                the captured images should be capture in the same client size. If the
;                                                running game client size is different, the template image will be
;                                                resized proportionally to match the client size. Though it's better
;                                                to keep your game client size consistent.
; Return values .: Array of area relative to the game client if find or subarea if provided. Otherwise just silent.
; =====================================================================================================================
Func ImageSearch($sImageFile, $fThreshold = 0.8, $arrSubArea = Default, $iBaseClientHeight = 720)
    Local $imgTempl = _OpenCV_imread_and_check($sImageFile)

    Local $arrArea = _WinAPI_GetClientPos($sGameWinTitle)
    Local $iActualHeight = $arrArea[3]
    If $arrSubArea <> Default Then
        $arrArea[0] += $arrSubArea[0]
        $arrArea[1] += $arrSubArea[1]
        $arrArea[2] = $arrSubArea[2]
        $arrArea[3] = $arrSubArea[3]
    EndIf
    Local $imgScreen = _OpenCV_GetDesktopScreenMat($arrArea)

    If $imgTempl.empty() Or $imgScreen.empty() Then
        Return False
    EndIf

    If $iActualHeight <> $iBaseClientHeight Then
        Local $fProportion = $iActualHeight / $iBaseClientHeight
        If $arrSubArea <> Default Then
            $arrArea[0] += int($arrSubArea[0] * ($fProportion - 1))
            $arrArea[1] += int($arrSubArea[1] * ($fProportion - 1))
        EndIf
        $arrArea[2] = int($arrArea[2] * $fProportion)
        $arrArea[3] = int($arrArea[3] * $fProportion)
        Local $iAdjWidth = int($imgTempl.width * $fProportion)
        Local $iAdjHeight = int($imgTempl.height * $fProportion)
        $imgTempl = $cv.resize($imgTempl, _OpenCV_Size($iAdjWidth, $iAdjHeight))
    EndIf

    Local $iN = 1

    Local $imgTemplOpt = $cv.cvtColor($imgTempl, $CV_COLOR_BGR2GRAY)
    Local $imgScreenOpt = $cv.cvtColor($imgScreen, $CV_COLOR_BGR2GRAY)
    Local $iTotalCosts = $imgScreen.width * $imgScreen.height * $imgTempl.width * $imgTempl.height
    If $iTotalCosts > 147456000000 Then
        $iN = 2
        $imgTemplOpt = $cv.resize($imgTemplOpt, _OpenCV_Size($imgTempl.width / $iN, $imgTempl.height / $iN))
        $imgScreenOpt = $cv.resize($imgScreenOpt, _OpenCV_Size($imgScreen.width / $iN, $imgScreen.height / $iN))
    EndIf
    Local $matchResults = _OpenCV_FindTemplate($imgScreenOpt, $imgTemplOpt, $fThreshold)  ; Covariant Matrix Normal
    If IsArray($matchResults) And UBound($matchResults) > 0 Then
        Local $arrRect = [$matchResults[0][0] * $iN, $matchResults[0][1] * $iN, $imgTempl.width, $imgTempl.height]
        Return SetError(0, 0, $arrRect)
    Else
        Return SetError(0, 0, False)
    EndIf
EndFunc

; ---- 点击不抢前台 ----
; 运行期间主循环被 AutoClick 占着，「停止」按钮的点击会排在消息队列里，
; 这里在每轮 AutoClick 开头把队列里的按钮点击处理掉（F9 热键仍然有效）
; 运行期间 AutoClick 会不断点击游戏（游戏成为前台），点助手面板的第一次点击
; 只会把面板激活、点不到按钮。给面板加 WS_EX_NOACTIVATE 后，点击不再需要激活，
; 「停止」按钮和勾选框在游戏占着前台时也能直接点。
Func _GuiSetNoActivate($bOn)
    Local $aEx = DllCall("user32.dll", "long_ptr", "GetWindowLongPtrW", "hwnd", $hGUI, "int", -20)
    If @error Then Return
    Local $iEx = $aEx[0]
    Local $iNew = $bOn ? BitOR($iEx, 0x08000000) : BitAND($iEx, BitNOT(0x08000000))
    If $iNew = $iEx Then Return
    DllCall("kernel32.dll", "none", "SetLastError", "dword", 0)
    DllCall("user32.dll", "long_ptr", "SetWindowLongPtrW", "hwnd", $hGUI, "int", -20, "long_ptr", $iNew)
    DllCall("user32.dll", "bool", "SetWindowPos", "hwnd", $hGUI, "hwnd", 0, "int", 0, "int", 0, "int", 0, "int", 0, "uint", 0x27)
EndFunc

Func _PollGuiButtons()
    While True
        Local $iMsg = GUIGetMsg()
        Switch $iMsg
            Case 0
                ExitLoop
            Case $GUI_EVENT_CLOSE
                Exit
            Case $btnStart
                If $bRunning Then
                    ActionStop()
                Else
                    ActionStart()
                EndIf
        EndSwitch
    WEnd
EndFunc

; ---- 剧情选项条检测 ----
; 选项条是半透明粉色圆角横条（底图不固定），用「粉色像素 + 两条横带」来判断：
; 单靠颜色会被别的粉色 UI 误判，所以要求上下两条一样宽的横带同时存在。
Func _IsPinkAtDC($hDC, $iX, $iY)
    Local $iColor = _WinAPI_GetPixel($hDC, $iX, $iY)
    If @error Or $iColor = -1 Then Return False
    Local $iR = BitShift(BitAND($iColor, 0xFF0000), 16)
    Local $iG = BitShift(BitAND($iColor, 0xFF00), 8)
    Local $iB = BitAND($iColor, 0xFF)
    Return ($iR >= 150 And ($iR - $iG) >= 40 And ($iB - $iG) >= 5 And ($iR - $iB) >= 20)
EndFunc

Func _FindChoiceBands()
    Local $aArea = _WinAPI_GetClientPos($sGameWinTitle)
    If Not IsArray($aArea) Then Return False
    Local $hBmp = _ScreenCapture_Capture("", $aArea[0], $aArea[1], $aArea[0] + $aArea[2] - 1, $aArea[1] + $aArea[3] - 1)
    If Not $hBmp Then Return False
    Local $hDC = _WinAPI_CreateCompatibleDC(0)
    Local $hOld = _WinAPI_SelectObject($hDC, $hBmp)

    Local $aXSamples[7] = [640, 700, 800, 900, 1000, 1100, 1230]
    Local $aBands[2][2], $iFound = 0, $iStart = -1, $iLastPink = -1
    For $iY = 200 To 560 Step 8
        Local $iCnt = 0
        For $i = 0 To 6
            If _IsPinkAtDC($hDC, $aXSamples[$i], $iY) Then $iCnt += 1
        Next
        If $iCnt >= 5 Then
            If $iStart < 0 Then $iStart = $iY
            $iLastPink = $iY
        Else
            If $iStart >= 0 Then
                Local $iH = $iLastPink - $iStart
                If $iH >= 30 And $iH <= 80 And $iFound < 2 Then
                    $aBands[$iFound][0] = $iStart
                    $aBands[$iFound][1] = $iLastPink
                    $iFound += 1
                EndIf
                $iStart = -1
            EndIf
        EndIf
    Next

    _WinAPI_SelectObject($hDC, $hOld)
    _WinAPI_DeleteDC($hDC)
    _WinAPI_DeleteObject($hBmp)

    If $iFound >= 2 Then Return $aBands
    Return False
EndFunc

Func _TryClickChoice()
    If $hChoiceLastClick <> 0 And TimerDiff($hChoiceLastClick) < 3000 Then Return False
    Local $hWnd = WinGetHandle($sGameWinTitle)
    If Not IsHWnd($hWnd) Then Return False
    Local $aBands = _FindChoiceBands()
    If Not IsArray($aBands) Then Return False
    Local $aArea = _WinAPI_GetClientPos($sGameWinTitle)
    If Not IsArray($aArea) Then Return False
    Local $iX = $aArea[0] + 940
    Local $iY = $aArea[1] + Int(($aBands[0][0] + $aBands[0][1]) / 2)
    If Not _IsGameWindowAt($iX, $iY) Then Return False
    Local $aOldPos = MouseGetPos()
    MouseClick("left", $iX, $iY, 1, 0)
    If IsArray($aOldPos) Then MouseMove($aOldPos[0], $aOldPos[1], 0)
    $hChoiceLastClick = TimerInit()
    Return True
EndFunc

Func _GameApplyNoActivate()
    If Not $bUseNoActivate Then Return False
    Local $hWnd = WinGetHandle($sGameWinTitle)
    If Not IsHWnd($hWnd) Then Return False
    Local $aEx = DllCall("user32.dll", "long_ptr", "GetWindowLongPtrW", "hwnd", $hWnd, "int", -20)
    If @error Then Return False
    Local $iEx = $aEx[0]
    $iGameExStyleOrig = $iEx
    If BitAND($iEx, 0x08000000) Then
        $bNoActivateApplied = True
        Return True
    EndIf
    Local $iNew = BitOR($iEx, 0x08000000, 0x00040000)
    DllCall("kernel32.dll", "none", "SetLastError", "dword", 0)
    DllCall("user32.dll", "long_ptr", "SetWindowLongPtrW", "hwnd", $hWnd, "int", -20, "long_ptr", $iNew)
    If @error Then Return False
    Local $aErr = DllCall("kernel32.dll", "dword", "GetLastError")
    If $aErr[0] <> 0 Then Return False
    DllCall("user32.dll", "bool", "SetWindowPos", "hwnd", $hWnd, "hwnd", 0, "int", 0, "int", 0, "int", 0, "int", 0, "uint", 0x27)
    $bNoActivateApplied = True
    Return True
EndFunc

Func _GameRestoreNoActivate()
    If Not $bNoActivateApplied Then Return
    Local $hWnd = WinGetHandle($sGameWinTitle)
    If IsHWnd($hWnd) Then
        DllCall("kernel32.dll", "none", "SetLastError", "dword", 0)
        DllCall("user32.dll", "long_ptr", "SetWindowLongPtrW", "hwnd", $hWnd, "int", -20, "long_ptr", $iGameExStyleOrig)
        DllCall("user32.dll", "bool", "SetWindowPos", "hwnd", $hWnd, "hwnd", 0, "int", 0, "int", 0, "int", 0, "int", 0, "uint", 0x27)
    EndIf
    $bNoActivateApplied = False
EndFunc

; 目标点上是不是真的站着游戏窗口（没有被别的窗口挡住）
Func _IsGameWindowAt($iX, $iY)
    Local $hWnd = WinGetHandle($sGameWinTitle)
    If Not IsHWnd($hWnd) Then Return False
    Local $tPoint = DllStructCreate("long X;long Y")
    DllStructSetData($tPoint, 1, $iX)
    DllStructSetData($tPoint, 2, $iY)
    Local $hHit = _WinAPI_WindowFromPoint($tPoint)
    If Not IsHWnd($hHit) Then Return False
    Local $hRoot = _WinAPI_GetAncestor($hHit, 2)
    If Not IsHWnd($hRoot) Then $hRoot = $hHit
    Return $hRoot = $hWnd
EndFunc

; $arrArea is the window area. $arrRect is the subarea relative to the window area.
; When no shifts, default to click the center of the image($subRect). The shifts are relative to the center.
Func ClickRelateWindow($arrArea, $arrRect, $iShiftX = 0, $iShiftY = 0, $bBgClick = False)
    Local $iCenterX = $arrRect[0] + Int($arrRect[2] / 2) + $iShiftX
    Local $iCenterY = $arrRect[1] + Int($arrRect[3] / 2) + $iShiftY
    If $bBgClick Then
        ; Only when this message is accepted, but mostly can't because it's cheat apparently.
        ControlClick($sGameWinTitle, "", "", "left", 1, $iCenterX, $iCenterY)
    Else
        Local $iScreenX = $arrArea[0] + $iCenterX
        Local $iScreenY = $arrArea[1] + $iCenterY
        ; 目标点必须真的落在游戏窗口上，否则会点到遮挡它的窗口（比如你正在用的窗口）
        If Not _IsGameWindowAt($iScreenX, $iScreenY) Then Return SetError(2, 0, False)
        ; 点完把光标还给用户
        Local $aOldPos = MouseGetPos()
        MouseClick("left", $iScreenX, $iScreenY, 1, 0)
        If IsArray($aOldPos) Then MouseMove($aOldPos[0], $aOldPos[1], 0)
    EndIf
    Return SetError(0, 0, True)
EndFunc

; CD: If the image would still be presented for a while after being clicked,
; then if in the next loop the same image is the
; "next" detected, skip it for 1 as the CD unit.
Func ClickImage($sImageFile, $fThreshold = 0.85, $iShiftX = 0, $iShiftY = 0, $bCDOn = False, $iCDMax = 2, $arrSubArea = Default, $iBaseClientHeight = 720)
    Static $sCDImageFile = ""
    Static $iCD = 0

    Local $arrRect = ImageSearch($sImageFile, $fThreshold, $arrSubArea, $iBaseClientHeight)
    If Not IsArray($arrRect) Then
        Return SetError(1, 0, False)
    EndIf

    If $bCDOn And $sCDImageFile = $sImageFile Then
        $iCD += 1
        If $iCD < $iCDMax Then
            Return SetError(0, 0, True)
        Endif
        $iCD = 0
    Else
        $iCD = 0
        $sCDImageFile = $sImageFile
    EndIf

    Local $arrArea = _WinAPI_GetClientPos($sGameWinTitle)
    Local $iActualHeight = $arrArea[3]
    If $arrSubArea <> Default Then
        $arrRect[0] += $arrSubArea[0]
        $arrRect[1] += $arrSubArea[1]
    EndIf

    If $iActualHeight <> $iBaseClientHeight Then
        Local $fProportion = $iActualHeight / $iBaseClientHeight
        If $arrSubArea <> Default Then
            $arrRect[0] += int($arrSubArea[0] * ($fProportion - 1))
            $arrRect[1] += int($arrSubArea[1] * ($fProportion - 1))
        EndIf
        $iShiftX = int($iShiftX * $fProportion)
        $iShiftY = int($iShiftY * $fProportion)
    EndIf

    ClickRelateWindow($arrArea, $arrRect, $iShiftX, $iShiftY)
    Return SetError(0, 0, True)
EndFunc

; Maze Shop Functions
Func MazeShopBuying()
    Local $fDefaultThreshold = 0.80, $fHigherThreshold = 0.90
    Local $bDefaultCDOn = False, $iDefaultCDFactor = 2
    Local $iDelayAnimate = 1500, $iDelayReaction = 150

    Sleep($iDelayReaction)
    If Not $bRunning Then Return True

    While _ScanAndClickBuy("BuyUpgrade.png", $fDefaultThreshold, $bDefaultCDOn, $iDefaultCDFactor)
        Sleep($iDelayAnimate)
        If Not $bRunning Then Return True
    WEnd

    _MazeShopScroll("down")
    Sleep($iDelayReaction)

    While _ScanAndClickBuy("BuyUpgrade.png", $fDefaultThreshold, $bDefaultCDOn, $iDefaultCDFactor)
        Sleep($iDelayAnimate)
        If Not $bRunning Then Return True
    WEnd

    _MazeShopScroll("up")
    Sleep($iDelayReaction)

    Local $bBoughtB = False
    If _ScanAndClickBuy("BuyInvest.png", $fDefaultThreshold, $bDefaultCDOn, $iDefaultCDFactor) Then
        $bBoughtB = True
        Sleep($iDelayReaction)
    EndIf

    _MazeShopScroll("down")
    Sleep($iDelayReaction)

    If _ScanAndClickBuy("BuyInvest.png", $fDefaultThreshold, $bDefaultCDOn, $iDefaultCDFactor) Then
        $bBoughtB = True
        Sleep($iDelayReaction)
    EndIf

    _MazeShopScroll("up")
    Sleep($iDelayReaction)

    If Not $bRunning Then Return True

    Local $areaCurrency = [1060, 70, 161, 41]
    If ClickImage($sGameResDir & "MazeRouge\Txt_ShopMon0.png", $fHigherThreshold, -50, 610, $bDefaultCDOn, $iDefaultCDFactor, $areaCurrency) Then
        Return True
    EndIf
    Return $bBoughtB
EndFunc

Func _ScanAndClickBuy($sImageName, $fThreshold, $bCDOn, $iCDFactor)
    Local $arrMegaShopViewport = [490, 155, 735, 450]
    Local $sFullImagePath = $sGameResDir & "MazeShop\" & $sImageName

    If ClickImage($sFullImagePath, $fThreshold, 0, 0, $bCDOn, $iCDFactor, $arrMegaShopViewport) Then
        Return True
    EndIf

    Return False
EndFunc

Func _MazeShopScroll($sDirection = "down")
    If Not $bRunning Then Return

    Local $arrArea = _WinAPI_GetClientPos($sGameWinTitle)
    If @error Then Return

    Local $iTargetX = $arrArea[0] + Int($arrArea[2] * 0.577)
    Local $iTargetY = $arrArea[1] + Int($arrArea[3] * 0.477)

    If Not _IsGameWindowAt($iTargetX, $iTargetY) Then Return
    Local $aOldPos = MouseGetPos()
    MouseMove($iTargetX, $iTargetY, 0)

    If $sDirection = "down" Then
        MouseWheel("down", 5)
    Else
        MouseWheel("up", 5)
    EndIf

    If IsArray($aOldPos) Then MouseMove($aOldPos[0], $aOldPos[1], 0)
EndFunc

Func MazeShopBuyingTypes()
    Local $fDefaultThreshold = 0.85, $bCD = False, $iCDFactor = 2
    Local $aTypes[3][5] = [ _
        ["Type_EN.png",       336, 110, 126, 26], _
        ["Type_Agile.png",    490, 110, 126, 26], _
        ["Type_Phys.png",     184, 110, 126, 26]  _
    ]

    If MazeShopBuying() Then Return True

    For $i = 0 To 2
        Local $arrSubArea = [$aTypes[$i][1], $aTypes[$i][2], $aTypes[$i][3], $aTypes[$i][4]]
        Local $sFullImagePath = $sGameResDir & "MazeShop\" & $aTypes[$i][0]
        ClickImage($sFullImagePath, $fDefaultThreshold, 0, 0, $bCD, $iCDFactor, $arrSubArea)
        If MazeShopBuying() Then Return True
    Next

    Return False
EndFunc

Func MazeShopFarming()
    Local $fDefault = 0.85, $fLow = 0.80, $bCD = False, $iCDFactor = 2, $iDelayReaction = 250

    Local $arrDailyBatchArea = [1095, 110, 126, 26]
    ClickImage($sGameResDir & "MazeShop\Daily_Batch.png", $fDefault, 0, 0, $bCD, $iCDFactor, $arrDailyBatchArea)
    Sleep($iDelayReaction)

    Local $aCates[3][5] = [ _
        ["Cate_TypeEquip.png", 19, 302, 126, 26], _
        ["Cate_Excavate.png",  19, 389, 126, 26], _
        ["Cate_Artifact.png",  19, 459, 126, 26]  _
    ]

    For $i = 0 To 2
        Local $arrSubArea = [$aCates[$i][1], $aCates[$i][2], $aCates[$i][3], $aCates[$i][4]]
        Local $sFullImagePath = $sGameResDir & "MazeShop\" & $aCates[$i][0]
        ClickImage($sFullImagePath, $fDefault, 0, 0, $bCD, $iCDFactor, $arrSubArea)
        Local $bStatus = ($i = 1) ? MazeShopBuying() : MazeShopBuyingTypes()
        If $bStatus Then Return
    Next

    _MazeShopAbort($fLow, $bCD, $iCDFactor)
EndFunc

Func _MazeShopAbort($fThreshold, $bCD, $iCDFactor)
    Local $areaShopDoneBtn = [1076, 644, 166, 36]
    ClickImage($sGameResDir & "MazeShop\WB_ShopDone.png", $fThreshold, 0, 0, $bCD, $iCDFactor, $areaShopDoneBtn)
    Local $areaAbortOK = [669, 529, 166, 36]
    Local $iCounter = 0
    While $bRunning And Not ClickImage($sGameResDir & "MazeRouge\RB_OK.png", $fThreshold, 0, 0, $bCD, $iCDFactor, $areaAbortOK)
        Sleep(500)
        If ++$iCounter > 10 Then
            Break
        EndIf
    WEnd
EndFunc

Func MazeNetworkErrored()
    Local $fDefault = 0.85, $bCD = False, $iCDFactor = 2
    Local $iSleep = 2000
    Sleep($iSleep)

    Local $sHomeQuestPath = $sGameResDir & "Com\Bar_Quest.png"
    Local $areaHomeQuest = [730, 674, 81, 21]
    Local $iCounter = 0
    While $bRunning And Not ClickImage($sHomeQuestPath, $fDefault, 0, 0, $bCD, $iCDFactor, $areaHomeQuest)
        Sleep($iSleep)
        If ++$iCounter > 5 Then
            Break
        EndIf
    WEnd

    Sleep($iSleep)

    Local $sHomeMazePath = $sGameResDir & "HomeQuest\Maze.png"
    Local $areaHomeMaze = [1030, 301, 166, 36]
    $iCounter = 0
    While $bRunning And Not ClickImage($sHomeMazePath, $fDefault, 0, 0, $bCD, $iCDFactor, $areaHomeMaze)
        Sleep($iSleep)
        If ++$iCounter > 5 Then
            Break
        EndIf
    WEnd

    Sleep($iSleep)

    Local $sHomeMazeEntryPath = $sGameResDir & "HomeQuest\MazeEntryA.png"
    Local $areaHomeMazeEntryA = [312, 517, 246, 61]
    ClickImage($sHomeMazeEntryPath, $fDefault, 0, 0, $bCD, $iCDFactor, $areaHomeMazeEntryA)
EndFunc

; Looped Function
Func AutoClick()
    _PollGuiButtons()
    If Not $bRunning Or $bSingleRunning Then Return

    If $bPausing Then
        $iPausingTimer += $iLoopTimer
        If $iPausingTimer >= $iPausingMax Then
            ActionContinue()
        EndIf
        Return
    EndIf

    If Not WinExists($sGameWinTitle) Then
        MsgBox(16, "错误", "未找到游戏窗口（标题含「マブラヴ」）。")
        ActionStop()
        Return
    EndIf

    Local $aClientSize = WinGetClientSize($sGameWinTitle)
    Local $iWinWDiff = 1280 - $aClientSize[0]
    Local $iWinHDiff = 720 - $aClientSize[1]
    if $iWinWDiff Or $iWinHDiff Then
        Local $aWinSize = WinGetPos($sGameWinTitle)
        WinMove( _
            $sGameWinTitle, "", Default, Default, _
            $aWinSize[2] + $iWinWDiff, _
            $aWinSize[3] + $iWinHDiff _
        )
        GUICtrlSetData($lblStatus, "状态：已调整窗口")
    EndIf

    ; 不再每轮 WinActivate：点击时用 NOACTIVATE 保持不抢前台；被遮挡时 ClickRelateWindow 会拒绝点击

    Local $fLow = 0.80, $fDefault = 0.85, $fHigh = 0.90
    Local $bCD = False, $iCDFactor = 2
    Local $iPopupDelay = 500

    Local $arrLoadingArea = [595, 325, 91, 66]
    If IsArray(ImageSearch($sGameResDir & "Com\Sys_Loading.png", $fDefault, $arrLoadingArea)) Then
        ActionPause(1500)
        Return
    EndIf

    ; 剧情选项：出现两条粉色选项条时点第一条（要放在 sto 之前：
    ; sto\fast.png 会匹配 ADV 右上角的快进按钮，先跑 sto 的话每轮都被快进截走）
    If _TryClickChoice() Then Return

    ; 自定义：Res\MuvLuv\sto 里的图片，画面中出现就点它一次（用彩色匹配，蓝底/红底不会互相误判）
    ; 同一张图 3 秒内不重复点（点击后游戏没反应时不至于每 500ms 狂点）
    If Not IsArray($aStoImgs) Then
        $aStoImgs = _FileListToArray($sGameResDir & "sto", "*.png", $FLTA_FILES, False)
        If @error Then
            Local $aStoEmpty[1] = [0]
            $aStoImgs = $aStoEmpty
        EndIf
    EndIf
    For $i = 1 To $aStoImgs[0]
        If $i = $iStoLastIndex And TimerDiff($hStoLastClick) < 3000 Then ContinueLoop
        If ClickImageColor($sGameResDir & "sto\" & $aStoImgs[$i], $fDefault) Then
            $iStoLastIndex = $i
            $hStoLastClick = TimerInit()
            Return
        EndIf
    Next

    Local $arrRaidHard = [856, 511, 161, 51]
    ClickImage($sGameResDir & "Com\Raid_Hard.png", $fDefault, 0, 0, $bCD, $iCDFactor, $arrRaidHard)

    Local $arrRB = [960, 510, 320, 210]
    If ClickImage($sGameResDir & "MazeRouge\RB_Start.png", $fDefault, 0, 0, $bCD, $iCDFactor, $arrRB) Or _
       ClickImage($sGameResDir & "MazeRouge\RB_Route.png", $fLow - 0.05, 0, 0, $bCD, $iCDFactor, $arrRB) Or _
       ClickImage($sGameResDir & "Quest\RB_Enter.png", $fDefault, 0, 0, $bCD, $iCDFactor, $arrRB) Then
        ActionPause(2500)
        Return
    EndIf

    Local $aSingleClicks[8] = [ _
        "MazeRouge\RB_Enter.png", "MazeRouge\WB_Leave.png", "MazeRouge\RB_Decide.png", _
        "Quest\RB_Scene.png", "Com\RB_Ready.png", "Com\RB_Raid.png", _
        "Com\RB_Sally.png", "Com\RB_Next.png" _
    ]
    For $img In $aSingleClicks
        ClickImage($sGameResDir & $img, $fDefault, 0, 0, $bCD, $iCDFactor, $arrRB)
    Next

    Local $arrRU = [960, 0, 320, 210]
    If ClickImage($sGameResDir & "Com\Sys_Menu.png", $fDefault, -560, 370, $bCD, $iCDFactor, $arrRU) Then
        If $bMazeFarmingOn Then
            $bSingleRunning = True
            MazeNetworkErrored()
            $bSingleRunning = False
        EndIf
        Return
    EndIf
    ClickImage($sGameResDir & "Com\BB_SkipA.png", $fLow, 0, 0, $bCD, $iCDFactor, $arrRU)
    ClickImage($sGameResDir & "Com\BB_SkipB.png", $fLow, 0, 0, $bCD, $iCDFactor, $arrRU)
    ClickImage($sGameResDir & "Com\BB_SkipC.png", $fLow, 0, 0, $bCD, $iCDFactor, $arrRU)
    ClickImage($sGameResDir & "MazeRouge\Txt_ShopMon0.png", $fHigh, -50, 610, $bCD, $iCDFactor, $arrRU)

    Local $arrGachaTitleArea = [104, 21, 86, 26]
    ClickImage($sGameResDir & "Com\Txt_Gacha.png", $fDefault, -90, 0, $bCD, $iCDFactor, $arrGachaTitleArea)

    Local $arrXDw = [300, 380, 680, 210]  ; Down
    ClickImage($sGameResDir & "Com\WB_Close.png", $fLow, 0, 0, $bCD, $iCDFactor, $arrXDw)
    ClickImage($sGameResDir & "Com\RB_Title.png", $fLow, 0, 0, $bCD, $iCDFactor, $arrXDw)
    ClickImage($sGameResDir & "MazeRouge\RB_OK.png", $fDefault, 0, 0, $bCD, $iCDFactor, $arrXDw)

    Local $arrM1 = [576, 141, 126, 26]
    ClickImage($sGameResDir & "MazeRouge\Txt_SelRelic.png", $fDefault, 0, 150, $bCD, $iCDFactor, $arrM1)

    Local $arrEvOptArea = [1144, 324, 115, 375]
    Local $arrCraftDoneArea = [905, 636, 126, 26]
    ClickImage($sGameResDir & "MazeRouge\Txt_EvOpt.png", $fDefault, -50, -25, $bCD, $iCDFactor, $arrEvOptArea)

    If $bMazeCraftSkip Then
        If ClickImage($sGameResDir & "MazeRouge\WB_CraftDone.png", $fDefault, 0, 0, $bCD, $iCDFactor, $arrCraftDoneArea) Then
            Sleep($iPopupDelay)
            ClickImage($sGameResDir & "MazeRouge\RB_OK.png", $fDefault, 0, 0, $bCD, $iCDFactor, $arrXDw)
        EndIf
    EndIf

    If IsArray(ImageSearch($sGameResDir & "Com\WB_TryAgain.png", $fDefault, $arrRB)) Then
        ActionStop()
        GUICtrlSetData($lblStatus, "状态：战斗失败")
        Return
    EndIf
    ; Txt_Limited.png 实际是「本日あと0回」。整串匹配在「あと6回/8回/9回」时也能到 ~0.95，
    ; 只靠这一个阈值没法区分 0 和其它数字，所以再单独比对一次数字「0」：
    ; 数字像 0 才停止，否则当作还有次数继续跑。
    Local $arrLimitedTxt = ImageSearch($sGameResDir & "Com\Txt_Limited.png", 0.95, $arrRB)
    If IsArray($arrLimitedTxt) Then
        Local $arrLimitedDigit = [$arrLimitedTxt[0] + $arrRB[0] + 41, $arrLimitedTxt[1] + $arrRB[1] + 1, 19, 24]
        If IsArray(ImageSearch($sGameResDir & "Com\Txt_Limited0.png", 0.90, $arrLimitedDigit)) Then
            ActionStop()
            GUICtrlSetData($lblStatus, "状态：次数用完")
            Return
        EndIf
    EndIf
    If IsArray(ImageSearch($sGameResDir & "Quest\RB_Clear.png", $fDefault, $arrRB)) Then
        ActionStop()
        GUICtrlSetData($lblStatus, "状态：关卡通关")
        Return
    EndIf
    If IsArray(ImageSearch($sGameResDir & "Com\BB_Menu.png", $fDefault, $arrRU)) Then
        ; 剧情中不算停止：只是等待，选项出现时上面的 _TryClickChoice 会点
        GUICtrlSetData($lblStatus, "状态：剧情中")
        Return
    EndIf

    Local $arrShopDoneCancelArea = [444, 529, 166, 36]
    If $bMazeFarmingOn Then
        ClickImage($sGameResDir & "MazeShop\WB_Cancel.png", $fDefault, 0, 0, $bCD, $iCDFactor, $arrShopDoneCancelArea)
    EndIf
    Local $iTimerReaction = 500
    Local $arrDailyUnitArea = [644, 110, 126, 26]
    If ClickImage($sGameResDir & "MazeShop\Daily_Unit.png", $fDefault, 0, 0, $bCD, $iCDFactor, $arrDailyUnitArea) Then
        $bSingleRunning = True
        Sleep($iTimerReaction)
        If Not $bRunning Then
            $bSingleRunning = False
            Return
        EndIf

        Local $arrDailyClearArea = [263, 586, 126, 26]
        If IsArray(ImageSearch($sGameResDir & "MazeShop\Daily_Clear.png", $fLow, $arrDailyClearArea)) Then
            If $bMazeFarmingOn Then
                MazeShopFarming()
            Else
                _MazeShopAbort($fLow, $bCD, $iCDFactor)
            EndIf
        EndIf
        $bSingleRunning = False
    EndIf
EndFunc

; Internal Handling
Func _OnAutoItExit()
    _GameRestoreNoActivate()
    _GDIPlus_Shutdown()
    _OpenCV_Close()
EndFunc
