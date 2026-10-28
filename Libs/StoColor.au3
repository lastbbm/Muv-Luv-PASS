#include-once

; 彩色版 ImageSearch / ClickImage
; 原来的 ImageSearch 会先把图和模板都转成灰度，所以「蓝色按钮」和「红色按钮」
; 只要形状一样就会互相误判（比如 sto\open.png 的蓝底白箭头会把红色「メインクエスト」按钮点掉）。
; 这两个函数不做灰度转换，直接用 BGR 三通道做 CCOEFF_NORMED 匹配，色相不同就匹配不上。

Func ImageSearchColor($sImageFile, $fThreshold = 0.85, $arrSubArea = Default, $iBaseClientHeight = 720)
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
        Local $iAdjWidth = int($imgTempl.width * $fProportion)
        Local $iAdjHeight = int($imgTempl.height * $fProportion)
        If $iAdjWidth > 0 And $iAdjHeight > 0 Then
            $imgTempl = $cv.resize($imgTempl, _OpenCV_Size($iAdjWidth, $iAdjHeight))
        EndIf
    EndIf

    Local $matchResults = _OpenCV_FindTemplate($imgScreen, $imgTempl, $fThreshold)
    If IsArray($matchResults) And UBound($matchResults) > 0 Then
        Local $arrRect = [$matchResults[0][0], $matchResults[0][1], $imgTempl.width, $imgTempl.height]
        Return SetError(0, 0, $arrRect)
    Else
        Return SetError(0, 0, False)
    EndIf
EndFunc

Func ClickImageColor($sImageFile, $fThreshold = 0.85, $iShiftX = 0, $iShiftY = 0, $arrSubArea = Default, $iBaseClientHeight = 720)
    Local $arrRect = ImageSearchColor($sImageFile, $fThreshold, $arrSubArea, $iBaseClientHeight)
    If Not IsArray($arrRect) Then
        Return SetError(1, 0, False)
    EndIf

    Local $arrArea = _WinAPI_GetClientPos($sGameWinTitle)
    Local $iActualHeight = $arrArea[3]
    If $arrSubArea <> Default Then
        $arrRect[0] += $arrSubArea[0]
        $arrRect[1] += $arrSubArea[1]
    EndIf

    If $iActualHeight <> $iBaseClientHeight Then
        Local $fProportion = $iActualHeight / $iBaseClientHeight
        $iShiftX = int($iShiftX * $fProportion)
        $iShiftY = int($iShiftY * $fProportion)
    EndIf

    ClickRelateWindow($arrArea, $arrRect, $iShiftX, $iShiftY)
    Return SetError(0, 0, True)
EndFunc
