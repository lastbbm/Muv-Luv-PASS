# Muv-Luv-PASS

Muv-Luv 少女花园/少女庭院（マブラヴ ガールズガーデン）PC 端自动化助手，V1.0。

基于 [LaunchLee/Assist_MuvLuv](https://github.com/LaunchLee/Assist_MuvLuv)（GPL-3.0）修改：AutoIt + OpenCV，
直接对 PC 客户端窗口截图识别并点击。

## 功能

- 自动战斗与剧情推进（跳过、继续、结算）
- 剧情选项自动点击（识别半透明粉色选项条，不依赖文字）
- 迷宫刷取、迷宫内跳过制造
- 自定义点击目录：`Res\MuvLuv\sto\*.png` 里的图片出现即点击
- **F9 一键启停**

## 使用

1. 打开游戏 PC 客户端（客户区 1280x720）
2. 双击 `启动MuvLuv助手.bat`
3. 按 **F9**（或点「开始」）开始，再按 **F9** 停止

## 注意

- 只截屏识别并模拟点击，不修改游戏文件；游戏窗口不要最小化、不要被其它窗口遮挡
- 需要 Windows 10/11 x64；已内置 AutoIt 与 OpenCV，无需另外安装
- 仅供学习交流，使用风险自负

## 致谢

- [LaunchLee/Assist_MuvLuv](https://github.com/LaunchLee/Assist_MuvLuv)
- [smbape/node-autoit-opencv-com](https://github.com/smbape/node-autoit-opencv-com)、[OpenCV](https://opencv.org/)、[AutoIt](https://www.autoitscript.com/)

## License

GPL-3.0
