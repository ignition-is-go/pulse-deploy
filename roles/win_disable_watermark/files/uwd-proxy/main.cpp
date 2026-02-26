// Watermark Disabler Proxy — patched for Windows Server 2025
// Based on: https://github.com/pr701/universal-watermark-disabler
// Added shell32.dll string IDs 33090-33094, 33110, 33112-33116

#include "main.h"
#define Length(a) (sizeof(a)/sizeof(a[0]))
// CLSID {ab0b37ec-56f6-4a0e-a8fd-7a8bf7c2da96} = explorerframe
#pragma comment(linker,"/export:DllGetClassObject=explorerframe.DllGetClassObject")
#pragma comment(linker,"/export:DllCanUnloadNow=explorerframe.DllCanUnloadNow")

// 1 branding + 17 shell32 strings = 18 total
static LPTSTR lpchNames[18];

int indexOf(LPCTSTR source, int sourceOffset, int sourceCount,
	LPCTSTR target, int targetOffset, int targetCount,
	int fromIndex)
{
	if (fromIndex >= sourceCount) {
		return (targetCount == 0 ? sourceCount : -1);
	}
	if (fromIndex < 0) {
		fromIndex = 0;
	}
	if (targetCount == 0) {
		return fromIndex;
	}

	TCHAR first = target[targetOffset];
	int max = sourceOffset + (sourceCount - targetCount);

	for (int i = sourceOffset + fromIndex; i <= max; i++) {
		if (source[i] != first) {
			while (++i <= max && source[i] != first);
		}
		if (i <= max) {
			int j = i + 1;
			int end = j + targetCount - 1;
			for (int k = targetOffset + 1; j < end && source[j] ==
				target[k]; j++, k++);
				if (j == end) {
					return i - sourceOffset;
				}
		}
	}
	return -1;
}

bool IsWatermarkText(LPCTSTR lptApiText)
{
	const TCHAR lptWs = '%';

	if (lptApiText == NULL)
		return false;
	if (lptApiText[0] == 0)
		return false;

	int lenApiText = lstrlen(lptApiText);
	for (int i = 0; i < Length(lpchNames); i++)
	{
		if (lpchNames[i] != NULL && lpchNames[i][0] != 0)
		{
			int stPoint = 0;
			int lenWaterText = lstrlen(lpchNames[i]);
			// fix format strings like "%ws Build %ws"
			if (lpchNames[i][0] == lptWs && lenWaterText > 4)
			{
				stPoint = 4;
				while ((++stPoint < lenWaterText) && (lpchNames[i][stPoint] != lptWs));
				if (stPoint < lenWaterText)
				{
					lenWaterText = stPoint - 4;
					stPoint = 4;
				}
				else
				{
					stPoint = 0;
					lenWaterText = lstrlen(lpchNames[i]);
				}
			}
			if (indexOf(lptApiText, 0, lenApiText, lpchNames[i], stPoint, lenWaterText, 0) >= 0)
				return true;
		}
	}
	return false;
}

// Proxy

INT WINAPI Proxy_LoadString(
	_In_opt_ HINSTANCE hInstance,
	_In_ UINT uID,
	_Out_ LPTSTR lpBuffer,
	_In_ int nBufferMax)
{
	if ((uID == 62000) || (uID == 62001))
		return 0;
	else
		return LoadString(hInstance, uID, lpBuffer, nBufferMax);
}

BOOL WINAPI Proxy_ExtTextOut(
	_In_ HDC hdc,
	_In_ int X,
	_In_ int Y,
	_In_ UINT fuOptions,
	_In_ const RECT *lprc,
	_In_ LPCTSTR lpString,
	_In_ UINT cbCount,
	_In_ const INT *lpDx)
{
	if (IsWatermarkText(lpString))
		return 1;
	else
		return ExtTextOutW(hdc, X, Y, fuOptions, lprc, lpString, cbCount, lpDx);
}

BOOL APIENTRY DllMain(HMODULE hModule,
	DWORD ul_reason_for_call,
	LPVOID lpReserved)
{
	if (ul_reason_for_call == DLL_PROCESS_ATTACH)
	{
		OutputDebugStringA("Loaded");
		HMODULE g_hShell32 = GetModuleHandle(_T("shell32.dll"));

		if (g_hShell32 != NULL)
		{
			BOOL bImportChanged;
			FARPROC pLoadString;

			pLoadString = GetProcAddress(GetModuleHandle(_T("api-ms-win-core-libraryloader-l1-2-0.dll")), "LoadStringW");
			if (pLoadString != NULL)
			{
				bImportChanged = ImportPatch::ChangeImportedAddress(g_hShell32, "api-ms-win-core-libraryloader-l1-2-0.dll", pLoadString, (FARPROC)Proxy_LoadString);
			}
			else
			{
				pLoadString = GetProcAddress(GetModuleHandle(_T("api-ms-win-core-libraryloader-l1-1-1.dll")), "LoadStringW");
				if (pLoadString != NULL)
				{
					bImportChanged = ImportPatch::ChangeImportedAddress(g_hShell32, "api-ms-win-core-libraryloader-l1-1-1.dll", pLoadString, (FARPROC)Proxy_LoadString);
				}
			}
			FARPROC pExtTextOut = GetProcAddress(GetModuleHandle(_T("gdi32.dll")), "ExtTextOutW");
			if (pExtTextOut != NULL)
			{
				bImportChanged = ImportPatch::ChangeImportedAddress(g_hShell32, "gdi32.dll", pExtTextOut, (FARPROC)Proxy_ExtTextOut);
			}

			if (bImportChanged)
			{
				const LPTSTR lptBrand = _T("Windows ");
				const LPTSTR lptPr = _T("Build ");

				// All shell32 string IDs that produce watermark text
				UINT uiID[] = {
					33088,  // Test Mode
					33089,  // Safe Mode
					33090,  // %wsMicrosoft (R) Windows (R) (Build %ws%0.0ws) %ws
					33091,  // %wsMicrosoft (R) Windows (R) (Build %ws: %ws) %ws
					33092,  // %wsMicrosoft (R) Windows (R) (Build %ws%0.0ws)
					33093,  // %wsMicrosoft (R) Windows (R) (Build %ws: %ws)
					33094,  // Device Under Test
					33108,  // %ws Build %ws
					33109,  // Evaluation copy.
					33110,  // For testing purposes only.
					33111,  // This copy of Windows is licensed for
					33112,  // Windows License is expired
					33113,  // days
					33114,  // hours
					33115,  // Windows License valid for %d %ws
					33116,  // Windows Grace expires in %d %ws
					33117,  // SecureBoot isn't configured correctly
				};

				int bufSize = 256;
				for (BYTE i = 0; i < Length(lpchNames); i++)
					lpchNames[i] = (TCHAR*)malloc(bufSize * sizeof(TCHAR));

				// Slot 0: branding string from winbrand.dll
				HMODULE h_Module = LoadLibrary(_T("winbrand.dll"));
				if (h_Module != NULL)
				{
					typedef BOOL(WINAPI *BrandLoadStr_t)(LPTSTR, INT, LPTSTR, INT);
					BrandLoadStr_t BrandLoadStr = (BrandLoadStr_t)GetProcAddress(h_Module, "BrandingLoadString");
					int Result = BrandLoadStr(_T("Basebrd"), 12, lpchNames[0], bufSize);
					if (Result == 0)
						lpchNames[0] = lptBrand;
					FreeLibrary(h_Module);
				}
				else lpchNames[0] = lptBrand;

				// Slots 1-17: shell32 strings
				h_Module = GetModuleHandle(_T("shell32.dll"));
				if (h_Module != NULL)
				{
					for (int i = 0; i < Length(uiID); i++)
					{
						int Result = LoadString(h_Module, uiID[i], lpchNames[i + 1], bufSize);
						if (Result == 0)
							lpchNames[i + 1] = lptPr;
					}
				}
				else
					for (BYTE i = 1; i < Length(lpchNames); i++)
						lpchNames[i] = lptPr;
			}
		}
		DisableThreadLibraryCalls(hModule);
	}
	return 1;
}
