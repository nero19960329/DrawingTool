; Author: Wang Zhao
; Create Time: 2016-03-20 20:31

TITLE DrawingTool Application

INCLUDE Irvine32.inc
INCLUDE GraphWin.inc

INCLUDELIB Irvine32.lib

;======================== DATA ========================
.data

ErrorTitle BYTE "Error", 0
WindowName BYTE "DrawingTool Application", 0
className BYTE "ASMWin", 0

; 定义程序窗口类结构
MainWin WNDCLASS <NULL, WinProc, NULL, NULL, NULL, NULL, NULL, \
    COLOR_WINDOW, NULL, className>
msg MSGStruct <>
hMainWnd DWORD ?
hInstance DWORD ?

;======================== CODE ========================
.code

WinMain PROC
; 获取当前进程的句柄
    INVOKE GetModuleHandle, NULL
    mov hInstance, eax
    mov MainWin.hInstance, eax

; 加载程序的光标以及图标
    INVOKE LoadIcon, NULL, IDI_APPLICATION
    mov MainWin.hIcon, eax
    INVOKE LoadCursor, NULL, IDC_ARROW
    mov MainWin.hCursor, eax

; 注册窗口类
    INVOKE RegisterClass, ADDR MainWin
    .IF eax == 0
        call ErrorHandler
        jmp Exit_Program
    .ENDIF

; 创建应用程序的主窗口
    INVOKE CreateWindowEx, 0, ADDR className,
        ADDR WindowName, MAIN_WINDOW_STYLE,
        CW_USEDEFAULT, CW_USEDEFAULT, CW_USEDEFAULT,
        CW_USEDEFAULT, NULL, NULL, hInstance, NULL

; 如果CreateWindowEx失败，显示一条消息并退出
    .IF eax == 0
        call ErrorHandler
        jmp Exit_Program
    .ENDIF

; 保存窗口句柄，显示并绘制窗口
    mov hMainWnd, eax
    INVOKE ShowWindow, hMainWnd, SW_SHOW
    INVOKE UpdateWindow, hMainWnd

; 开始程序的持续消息处理循环
Message_Loop:
    ; 从队列中获得下一条消息
    INVOKE GetMessage, ADDR msg, NULL, NULL, NULL

    ; 若无消息则退出
    .IF eax == 0
        jmp Exit_Program
    .ENDIF

    ; 把消息转发给程序的WinProc过程
    INVOKE DispatchMessage, ADDR msg
    jmp Message_Loop

Exit_Program:
    INVOKE ExitProcess, 0
WinMain ENDP

WinProc PROC,
    hWnd: DWORD, localMsg: DWORD, wParam: DWORD, lParam: DWORD

    mov eax, localMsg

    .IF eax == WM_CREATE        ; 创建窗口消息？
        jmp WinProcExit
    .ELSEIF eax == WM_CLOSE     ; 关闭窗口消息？
        INVOKE PostQuitMessage, 0
        jmp WinProcExit
    .ELSE
        INVOKE DefWindowProc, hWnd, localMsg, wParam, lParam
        jmp WinProcExit
    .ENDIF

WinProcExit:
    ret
WinProc ENDP

ErrorHandler PROC

.data
pErrorMsg DWORD ?
messageID DWORD ?

.code
    INVOKE GetLastError
    mov messageID, eax

    ; 获取对应的消息字符串
    INVOKE FormatMessage, FORMAT_MESSAGE_ALLOCATE_BUFFER + \
        FORMAT_MESSAGE_FROM_SYSTEM, NULL, messageID, NULL,
        ADDR pErrorMsg, NULL, NULL

    ; 显示错误消息
    INVOKE MessageBox, NULL, pErrorMsg, ADDR ErrorTitle,
        MB_ICONERROR+MB_OK

    ; 释放消息字符串
    INVOKE LocalFree, pErrorMsg
    ret
ErrorHandler ENDP
END WinMain
