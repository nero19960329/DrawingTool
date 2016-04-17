; Author: Wang Zhao
; Create Time: 2016-03-20 20:31

TITLE DrawingTool Application

.386 
.model flat,stdcall 
option casemap:none

WinMain proto :DWORD, :DWORD, :DWORD, :DWORD

INCLUDE windows.inc
INCLUDE user32.inc
INCLUDE kernel32.inc
INCLUDE gdi32.inc
INCLUDE comdlg32.inc

INCLUDELIB user32.lib
INCLUDELIB kernel32.lib
INCLUDELIB gdi32.lib
INCLUDELIB comdlg32.lib



;======================== DATA ========================
.data

; 长宽
screenLength dw 541
screenWidth dw 784

; 各种编号
IDM_OPT1  dw 301
IDM_OPT2  dw 302
IDM_OPT3  dw 303
IDM_OPT4  dw 304

IDM_DRAW  dw 401
IDM_ERASE dw 402

IDB_ONE   dw 3301
IDB_TWO   dw 3302
IDB_THREE dw 3303

; 菜单字符串
fileMenuStr db "文件", 0
; newMenuStr db "新建", 0
loadMenuStr db "打开", 0
saveMenuStr db "保存", 0
; saveAsMenuStr db "另存为", 0

fileMenuStr1 db "绘图", 0
drawMenuStr db "画图", 0
eraseMenuStr db "擦除", 0

; 按钮字符串
lineButtonStr db "直线", 0

; 类名以及程序名
className db "DrawingWinClass", 0
appName db "画图", 0

; 句柄等变量
hInstance HINSTANCE ?
hMenu HMENU ?
commandLine LPSTR ?

; 杂项
buttonStr db "Button", 0
beginX dd 0
beginY dd 0
endX dd 0
endY dd 0

curX dd 0
curY dd 0

pointX dd 0
pointY dd 0
drawingFlag db 0
erasingFlag db 0
; 画图/擦除模式
mode db 0

; 工作区域
workRegion RECT <0, 0, 800, 600>

; 结构体定义
PAINTDATA STRUCT
	ptBeginX dd ?
	ptBeginY dd ?
	ptEndX   dd ?
	ptEndY   dd ?
	penStyle dd ?
PAINTDATA ENDS

; 保存有关
filetype1 byte "BMP(*.bmp)", 0 ,"*.bmp", 0, 0
filetype2 byte "BMP(*.bmp)", 0, 0
finalname byte "bmp", 0
fileHandle DWORD ?
; szFileName BYTE "painting.bmp", 0
szFileName	db	MAX_PATH DUP (?)
szTitleName	db	MAX_PATH DUP (?)
ofn OPENFILENAME <>
;======================== CODE ========================
.code

start:
	INVOKE GetModuleHandle, NULL
	mov hInstance, eax
	INVOKE GetCommandLine
	mov commandLine, eax
	INVOKE WinMain, hInstance, NULL, commandLine, SW_SHOWDEFAULT
	INVOKE ExitProcess, eax

; 创建菜单
createMenu PROC
	LOCAL popFile: HMENU
	LOCAL popFile1: HMENU

	INVOKE CreateMenu
	.IF eax == 0
		ret
	.ENDIF
	mov hMenu, eax

	INVOKE CreatePopupMenu
	mov popFile, eax

	INVOKE CreatePopupMenu
	mov popFile1, eax
	
	INVOKE AppendMenu, hMenu, MF_POPUP, popFile, ADDR fileMenuStr

	; INVOKE AppendMenu, popFile, MF_STRING, IDM_OPT1, ADDR newMenuStr
	INVOKE AppendMenu, popFile, MF_STRING, IDM_OPT2, ADDR loadMenuStr
	INVOKE AppendMenu, popFile, MF_STRING, IDM_OPT3, ADDR saveMenuStr
	; INVOKE AppendMenu, popFile, MF_STRING, IDM_OPT4, ADDR saveAsMenuStr

	INVOKE AppendMenu, hMenu, MF_POPUP, popFile1, ADDR fileMenuStr1
	
	INVOKE AppendMenu, popFile1, MF_STRING, IDM_DRAW, ADDR drawMenuStr
	INVOKE AppendMenu, popFile1, MF_STRING, IDM_ERASE, ADDR eraseMenuStr

	ret

createMenu ENDP

; 创建按钮
createButtons PROC,
	hWnd: HWND
	
	;INVOKE CreateWindowEx, NULL, ADDR buttonStr, ADDR lineButtonStr, WS_VISIBLE or WS_CHILD or BS_PUSHBUTTON, 35, 10, 80, 30, hWnd, IDB_ONE, hInstance, NULL

	ret

createButtons ENDP



WinMain PROC,
	hInst: HINSTANCE, hPrevInst: HINSTANCE, CmdLine: LPSTR, CmdShow: DWORD
	LOCAL wc: WNDCLASSEX
	LOCAL msg: MSG
	LOCAL hwnd: HWND

	INVOKE createMenu
	mov wc.cbSize, SIZEOF WNDCLASSEX
	mov wc.style, CS_HREDRAW or CS_VREDRAW
	mov wc.lpfnWndProc, OFFSET WndProc
	mov wc.cbClsExtra, NULL
	mov wc.cbWndExtra, NULL
	push hInst
	pop wc.hInstance
	mov wc.hbrBackground, COLOR_WINDOW+1
	mov wc.lpszMenuName, NULL
	mov wc.lpszClassName, OFFSET className
	INVOKE LoadIcon, NULL, IDI_APPLICATION
	mov wc.hIcon, eax
	mov wc.hIconSm, eax
	INVOKE LoadCursor, NULL, IDC_ARROW
	mov wc.hCursor, eax
	INVOKE RegisterClassEx, ADDR wc
	INVOKE CreateWindowEx, NULL, ADDR className, ADDR appName, \
		WS_OVERLAPPEDWINDOW AND (NOT WS_SIZEBOX) AND (NOT WS_MAXIMIZEBOX) AND (NOT WS_MINIMIZEBOX), CW_USEDEFAULT, \
		CW_USEDEFAULT, 800, 600, NULL, hMenu, \
		hInst, NULL
	mov hwnd, eax
	INVOKE ShowWindow, hwnd, SW_SHOWNORMAL
	INVOKE UpdateWindow, hwnd
	.WHILE TRUE
		INVOKE GetMessage, ADDR msg, NULL, 0, 0
		.BREAK .IF (!eax)
			INVOKE TranslateMessage, ADDR msg
		INVOKE DispatchMessage, ADDR msg
	.ENDW
	mov eax, msg.wParam
	ret
WinMain ENDP



WndProc PROC USES ebx ecx edx,
	hWnd: HWND, uMsg: UINT, wParam: WPARAM, lParam: LPARAM
	LOCAL hdc: HDC
	LOCAL hbuf: HDC
	LOCAL hdcMem: HDC
	LOCAL hBitmap: HBITMAP
	LOCAL ps: PAINTSTRUCT
	LOCAL rect: RECT
	LOCAL lowordWParam: WORD
	LOCAL p: POINT
	LOCAL bmfh: BITMAPFILEHEADER
	LOCAL bmih: BITMAPINFOHEADER
	LOCAL nColorLen: DWORD
    LOCAL dwRgbQuadSize: DWORD
    LOCAL dwBmSize: DWORD
    LOCAL hMem: HGLOBAL
    LOCAL lpbi: DWORD   
    LOCAL bm: BITMAP
    LOCAL hFile: HANDLE
    LOCAL dwWritten: DWORD

	.IF uMsg == WM_DESTROY
		INVOKE PostQuitMessage, NULL
	.ELSEIF uMsg == WM_CREATE
		INVOKE createButtons, hWnd
	.ELSEIF uMsg == WM_COMMAND	; 响应事件
		mov ebx, wParam
		.IF bx == IDB_ONE
			;INVOKE ShowWindow, hWnd, SW_HIDE
		.ELSEIF bx == IDM_OPT2 ; 打开图片
			push edx
			mov ofn.hwndOwner, NULL
			mov ofn.nFilterIndex, 1
			mov ofn.lpstrFileTitle, NULL
			mov ofn.nMaxFileTitle, 0
			mov ofn.lpstrInitialDir, NULL ;
			mov ofn.Flags,  OFN_PATHMUSTEXIST AND OFN_FILEMUSTEXIST

			mov edx, sizeof ofn
			mov ofn.lStructSize, edx
			mov ofn.lpstrFile, OFFSET szFileName;			
			mov edx, sizeof szFileName
			mov ofn.nMaxFile, edx
			mov ofn.lpstrFilter, OFFSET filetype1
			pop edx
			INVOKE GetOpenFileName, ADDR ofn
			INVOKE GetDC, hWnd
			mov hdc, eax
			invoke CreateCompatibleDC, hdc
			mov hbuf, eax
			invoke LoadImage, NULL, ADDR szFileName, IMAGE_BITMAP, screenWidth, screenLength, LR_LOADFROMFILE
			mov hBitmap, eax
			invoke SelectObject, hbuf, eax
			invoke BitBlt, hdc, 0, 0,  screenWidth, screenLength, hbuf, 0, 0, SRCCOPY
			invoke DeleteObject, hBitmap
			invoke DeleteDC, hbuf
		.ELSEIF bx == IDM_OPT3 ; 保存图片
			; ZeroMemory(&ofn, sizeof(ofn));
			push edx
			mov edx, sizeof ofn
			mov ofn.lStructSize, edx
			mov ofn.lpstrFile, OFFSET szFileName;			
			mov ofn.lpstrFileTitle, OFFSET szTitleName
			mov edx, sizeof szFileName
			mov ofn.Flags, OFN_OVERWRITEPROMPT
			mov ofn.lpstrFilter, OFFSET filetype2
			mov ofn.lpstrDefExt, OFFSET finalname
			mov ofn.nMaxFile, edx
			pop edx
			INVOKE GetSaveFileName, ADDR ofn
			; invoke DibFileSaveDlg, hWnd, ADDR szFileName, ADDR szTitleName
			; INVOKE GetDlgItemText, hWnd, 2, ADDR szFileName, (sizeof szFileName)
            ; INVOKE ShowWindow, hWnd, SW_HIDE
			; INVOKE Sleep, 500
			INVOKE GetDC, hWnd
			mov hdc, eax
			INVOKE CreateCompatibleBitmap, hdc, screenWidth, screenLength
			mov hBitmap, eax
			INVOKE CreateCompatibleDC, hdc
			mov hdcMem, eax
			INVOKE SelectObject, hdcMem, hBitmap
			INVOKE BitBlt, hdcMem, 0, 0, screenWidth, screenLength, hdc, 0, 0, SRCCOPY
			INVOKE CreateFile,
				ADDR szFileName,
				GENERIC_WRITE,
				0,
				NULL,
				CREATE_ALWAYS,
				FILE_ATTRIBUTE_NORMAL,
				NULL
			mov fileHandle, eax
			INVOKE GetObject, hBitmap, (sizeof BITMAP), ADDR bm

			push edx
			mov bmih.biSize, (sizeof bmih)
			mov edx, bm.bmWidth
			mov bmih.biWidth, edx
			mov edx, bm.bmHeight
			mov bmih.biHeight, edx
			mov bmih.biPlanes, 1
			mov dx, bm.bmBitsPixel
			mov bmih.biBitCount, dx
			mov bmih.biCompression, BI_RGB
			mov bmih.biSizeImage, 0
			mov bmih.biXPelsPerMeter, 0
			mov bmih.biYPelsPerMeter, 0
			mov bmih.biClrUsed, 0
			mov bmih.biClrImportant, 0
			pop edx

			push eax
			push edx
			push ebx
			mov eax, bm.bmWidth
			mov edx, 0
			mov dx, bmih.biBitCount
			imul eax, edx
			add eax, 31
			mov edx, 0
			mov ebx, 32
			idiv ebx
			imul eax, bm.bmHeight
			imul eax, 4
			mov dwBmSize, eax
			pop eax
			pop edx
			pop ebx
			cmp bmih.biBitCount, 8
			jng L1
			jmp L2
L1:
			push edx
			mov edx, 1
			push ecx
			mov cx, bm.bmBitsPixel
			shl edx, cl
			pop ecx
			mov nColorLen, edx
			pop edx
			jmp L3
L2:
			mov nColorLen, 0
L3:
			push eax
			mov eax, nColorLen
			imul eax, (sizeof RGBQUAD)
			mov dwRgbQuadSize, eax
			pop eax

			push ecx
			push edx
			mov edx, dwBmSize
			add edx, dwRgbQuadSize
			add edx, (sizeof bmih)
			INVOKE GlobalAlloc, GHND, edx
			mov hMem, eax
			INVOKE GlobalLock, hMem
			mov lpbi, eax
			mov ecx, (sizeof bmih) 
			lea edx, bmih
			mov ebx, lpbi
L4:
			mov eax, [edx]
			mov [ebx], eax
			add ebx, (TYPE DWORD)
			add edx, (TYPE DWORD)
			loop L4
			pop ebx
			pop ecx
			; INVOKE  memcpy, lpbi, ADDR bmih, (sizeof bmih) 
			mov edx, lpbi
			add edx, (sizeof bmih)
			add edx, dwRgbQuadSize
			INVOKE GetDIBits, hdc, hBitmap, 0, bmih.biHeight, edx, lpbi, DIB_RGB_COLORS
			pop edx

			push edx
			mov bmfh.bfType, 4D42h
			mov bmfh.bfSize, (sizeof bmfh)
			add bmfh.bfSize, (sizeof bmih)
			mov edx, dwRgbQuadSize
			add bmfh.bfSize, edx
			mov edx, dwBmSize
			add bmfh.bfSize, edx
			mov bmfh.bfReserved1, 0
			mov bmfh.bfReserved2, 0
			mov bmfh.bfOffBits, (sizeof bmfh)
			add bmfh.bfOffBits, (sizeof bmih)
			mov edx, dwRgbQuadSize
			add bmfh.bfOffBits, edx
			pop edx
			INVOKE WriteFile, fileHandle, ADDR bmfh, (sizeof bmfh), ADDR dwWritten, NULL
			push edx
			mov edx, bmfh.bfSize
			sub edx, (sizeof bmfh) 
			INVOKE WriteFile, fileHandle, lpbi, edx, ADDR dwWritten, NULL
			pop edx
			INVOKE GlobalFree, hMem
			INVOKE CloseHandle, fileHandle
		.ELSEIF bx == IDM_DRAW  ; 画图模式
			mov mode,0
		.ELSEIF bx == IDM_ERASE ; 擦除模式
			mov mode,1
		.ENDIF
	.ELSEIF uMsg == WM_MOUSEMOVE
		mov ebx, lParam
		mov edx, 0
		mov dx, bx
		sar ebx, 16

		mov curX, edx
		mov curY, ebx
		.IF mode == 0    ;drawing mode
			.IF drawingFlag == 1
				.IF endX == 0
					mov beginX, edx
				.ELSE
					mov eax, endX
					mov beginX, eax
				.ENDIF

				.IF endY == 0
					mov beginY, ebx
				.ELSE
					mov eax, endY
					mov beginY, eax
				.ENDIF

				mov endX, edx
				mov endY, ebx
				INVOKE InvalidateRect, hWnd, ADDR workRegion, 0
			.ENDIF
		.ENDIF

		.IF mode == 1 ; Erasing mode
			INVOKE InvalidateRect, hWnd, ADDR workRegion, 0

		.ENDIF
		
	.ELSEIF uMsg == WM_LBUTTONDOWN
		mov drawingFlag, 1
		mov erasingFlag, 1
	.ELSEIF uMsg == WM_LBUTTONUP
		mov drawingFlag, 0
		mov erasingFlag, 0
		mov beginX, 0
		mov beginY, 0
		mov endX, 0
		mov endY, 0
	.ELSEIF uMsg == WM_PAINT
		INVOKE BeginPaint, hWnd, ADDR ps
		.IF mode == 0
			; ebx = pen
			;INVOKE CreatePen, PS_SOLID, 1, 0
			;mov ebx, eax
			INVOKE MoveToEx, ps.hdc, beginX, beginY, NULL
			INVOKE LineTo, ps.hdc, endX, endY
			;INVOKE DeleteObject, ebx
		.ENDIF
		.IF mode == 1
			.IF erasingFlag == 1
				;INVOKE RGB,0,0,0
				;INVOKE SetDCBrushColor, ps.hdc, 0
				INVOKE GetStockObject, NULL_PEN
				INVOKE SelectObject, ps.hdc, eax
				sub curX, 10
				sub curY, 10
				mov ebx, curX
				mov edx, curY
				add ebx, 20
				add edx, 20
				
				INVOKE Rectangle, ps.hdc, curX, curY, ebx, edx
			.ENDIF
		.ENDIF

		INVOKE EndPaint, hWnd, ADDR ps
	.ELSE
		INVOKE DefWindowProc, hWnd, uMsg, wParam, lParam
		ret
	.ENDIF

	xor eax, eax
	ret
WndProc ENDP



end start